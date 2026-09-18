"""Generate quarterly SecureSure payment records."""

import random
from datetime import date, timedelta
from decimal import Decimal

from db_connection import get_connection


RANDOM_SEED = 44
DATA_END_DATE = date(2026, 8, 31)
INSTALLMENTS_PER_POLICY = 4
BATCH_SIZE = 5_000

PAYMENT_METHODS = [
    "Credit Card",
    "Debit Card",
    "Bank Transfer",
    "Direct Debit",
    "Check",
]

random.seed(RANDOM_SEED)


def ensure_payment_table_is_empty(cursor):
    """Prevent the generator from creating duplicate payments."""

    cursor.execute("SELECT COUNT(*) FROM core.payments;")
    payment_count = cursor.fetchone()[0]

    if payment_count > 0:
        raise RuntimeError(
            "Payments already exist. Generation stopped "
            "to prevent duplicate data."
        )


def load_policies(cursor):
    """Load the policy information required for payments."""

    cursor.execute(
        """
        SELECT
            policy_id,
            start_date,
            annual_premium
        FROM core.policies
        ORDER BY policy_id;
        """
    )

    return cursor.fetchall()


def determine_payment(due_date, amount_due):
    """Determine payment status, date, amount and method."""

    if due_date > DATA_END_DATE:
        return None, Decimal("0.00"), None, "Pending"

    outcome = random.random()

    if outcome < 0.82:
        payment_status = "Paid"
        amount_paid = amount_due
        payment_method = random.choice(PAYMENT_METHODS)

        payment_date = due_date + timedelta(
            days=random.randint(-10, 20)
        )
        payment_date = min(payment_date, DATA_END_DATE)

    elif outcome < 0.88:
        payment_status = "Partial"
        percentage_paid = Decimal(
            str(round(random.uniform(0.40, 0.90), 4))
        )
        amount_paid = (
            amount_due * percentage_paid
        ).quantize(Decimal("0.01"))

        payment_method = random.choice(PAYMENT_METHODS)
        payment_date = due_date + timedelta(
            days=random.randint(0, 20)
        )
        payment_date = min(payment_date, DATA_END_DATE)

    elif outcome < 0.97:
        payment_status = "Overdue"
        amount_paid = Decimal("0.00")
        payment_method = None
        payment_date = None

    else:
        payment_status = "Failed"
        amount_paid = Decimal("0.00")
        payment_method = random.choice(PAYMENT_METHODS)
        payment_date = None

    return (
        payment_date,
        amount_paid,
        payment_method,
        payment_status,
    )


def build_payment(
    policy_id,
    policy_start,
    annual_premium,
    installment_number,
):
    """Build one quarterly payment record."""

    due_date = policy_start + timedelta(
        days=(installment_number - 1) * 91
    )

    amount_due = (
        annual_premium / Decimal(INSTALLMENTS_PER_POLICY)
    ).quantize(Decimal("0.01"))

    (
        payment_date,
        amount_paid,
        payment_method,
        payment_status,
    ) = determine_payment(due_date, amount_due)

    payment_reference = (
        f"PAY-{policy_id:09d}-{installment_number}"
    )

    return (
        payment_reference,
        policy_id,
        payment_date,
        due_date,
        amount_due,
        amount_paid,
        payment_method,
        payment_status,
    )


def insert_batch(cursor, payment_batch):
    """Insert one batch of payment records."""

    cursor.executemany(
        """
        INSERT INTO core.payments (
            payment_reference,
            policy_id,
            payment_date,
            due_date,
            amount_due,
            amount_paid,
            payment_method,
            payment_status
        )
        VALUES (
            %s, %s, %s, %s,
            %s, %s, %s, %s
        );
        """,
        payment_batch,
    )


def run_pipeline():
    """Generate and load quarterly payments."""

    connection = None
    pipeline_run_id = None

    try:
        connection = get_connection()

        with connection.cursor() as cursor:
            ensure_payment_table_is_empty(cursor)

            cursor.execute(
                """
                INSERT INTO audit.pipeline_runs (
                    pipeline_name,
                    run_status
                )
                VALUES ('generate_payments', 'RUNNING')
                RETURNING pipeline_run_id;
                """
            )

            pipeline_run_id = cursor.fetchone()[0]
            connection.commit()

            policies = load_policies(cursor)

            if not policies:
                raise RuntimeError(
                    "No policies were found."
                )

            payment_batch = []
            records_loaded = 0

            for (
                policy_id,
                policy_start,
                annual_premium,
            ) in policies:

                for installment_number in range(
                    1,
                    INSTALLMENTS_PER_POLICY + 1,
                ):
                    payment_batch.append(
                        build_payment(
                            policy_id,
                            policy_start,
                            annual_premium,
                            installment_number,
                        )
                    )

                    if len(payment_batch) >= BATCH_SIZE:
                        insert_batch(cursor, payment_batch)

                        records_loaded += len(payment_batch)
                        payment_batch.clear()

                        if records_loaded % 50_000 == 0:
                            print(
                                f"Loaded {records_loaded:,} payments..."
                            )

            if payment_batch:
                insert_batch(cursor, payment_batch)
                records_loaded += len(payment_batch)

            cursor.execute(
                """
                UPDATE audit.pipeline_runs
                SET
                    completed_at = CURRENT_TIMESTAMP,
                    run_status = 'SUCCESS',
                    records_received = %s,
                    records_loaded = %s
                WHERE pipeline_run_id = %s;
                """,
                (
                    records_loaded,
                    records_loaded,
                    pipeline_run_id,
                ),
            )

            connection.commit()

        print("Payment pipeline completed successfully.")
        print(f"Payments created: {records_loaded:,}")
        print(f"Pipeline run ID: {pipeline_run_id}")

    except Exception as error:
        if connection is not None:
            connection.rollback()

        if pipeline_run_id is not None:
            with get_connection() as error_connection:
                with error_connection.cursor() as cursor:
                    cursor.execute(
                        """
                        UPDATE audit.pipeline_runs
                        SET
                            completed_at = CURRENT_TIMESTAMP,
                            run_status = 'FAILED',
                            error_message = %s
                        WHERE pipeline_run_id = %s;
                        """,
                        (str(error), pipeline_run_id),
                    )

        print(f"Payment pipeline failed: {error}")
        raise SystemExit(1) from error

    finally:
        if connection is not None:
            connection.close()


if __name__ == "__main__":
    run_pipeline()