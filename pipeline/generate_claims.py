"""Generate fictional SecureSure insurance claims."""

import random
from datetime import date, timedelta
from decimal import Decimal

from db_connection import get_connection


CLAIM_COUNT = 25_000
RANDOM_SEED = 45
DATA_END_DATE = date(2026, 8, 31)

random.seed(RANDOM_SEED)


CLAIM_TYPES = {
    "Auto": [
        "Collision",
        "Theft",
        "Glass Damage",
        "Liability",
        "Weather Damage",
    ],
    "Home": [
        "Water Damage",
        "Fire Damage",
        "Theft",
        "Storm Damage",
        "Liability",
    ],
    "Life": [
        "Death Benefit",
        "Terminal Illness",
    ],
    "Health": [
        "Hospitalization",
        "Surgery",
        "Emergency Care",
        "Prescription",
        "Specialist Care",
    ],
    "Travel": [
        "Trip Cancellation",
        "Medical Emergency",
        "Lost Baggage",
        "Travel Delay",
    ],
}


CLAIM_RATIOS = {
    "Auto": (0.03, 0.35),
    "Home": (0.01, 0.20),
    "Life": (0.40, 1.00),
    "Health": (0.01, 0.25),
    "Travel": (0.02, 0.50),
}


def random_date(start_date, end_date):
    """Return a random date inside the supplied range."""

    available_days = (end_date - start_date).days

    if available_days <= 0:
        return start_date

    return start_date + timedelta(
        days=random.randint(0, available_days)
    )


def ensure_claim_table_is_empty(cursor):
    """Prevent accidental duplicate claim generation."""

    cursor.execute("SELECT COUNT(*) FROM core.claims;")
    claim_count = cursor.fetchone()[0]

    if claim_count > 0:
        raise RuntimeError(
            "Claims already exist. Generation stopped "
            "to prevent duplicate data."
        )


def load_policies(cursor):
    """Load policies and their product categories."""

    cursor.execute(
        """
        SELECT
            p.policy_id,
            p.start_date,
            p.end_date,
            p.coverage_amount,
            pr.product_category
        FROM core.policies AS p
        INNER JOIN core.products AS pr
            ON p.product_id = pr.product_id
        WHERE p.start_date <= %s
        ORDER BY p.policy_id;
        """,
        (DATA_END_DATE,),
    )

    return cursor.fetchall()


def generate_fraud_score():
    """Generate a mostly low score with some high-risk claims."""

    if random.random() < 0.05:
        score = random.uniform(65, 99)
    else:
        score = random.betavariate(2, 8) * 65

    return Decimal(str(round(score, 2)))


def determine_claim_outcome(reported_date, claimed_amount):
    """Determine claim status and settlement information."""

    claim_status = random.choices(
        population=[
            "Settled",
            "Approved",
            "Rejected",
            "Under Review",
            "Submitted",
        ],
        weights=[55, 10, 10, 15, 10],
        k=1,
    )[0]

    approved_amount = None
    settlement_date = None

    if claim_status == "Settled":
        approved_percentage = Decimal(
            str(round(random.uniform(0.60, 0.98), 4))
        )

        proposed_settlement_date = (
            reported_date
            + timedelta(days=random.randint(5, 90))
        )

        if proposed_settlement_date <= DATA_END_DATE:
            approved_amount = (
                claimed_amount * approved_percentage
            ).quantize(Decimal("0.01"))

            settlement_date = proposed_settlement_date
        else:
            claim_status = "Under Review"

    elif claim_status == "Approved":
        approved_percentage = Decimal(
            str(round(random.uniform(0.60, 0.98), 4))
        )

        approved_amount = (
            claimed_amount * approved_percentage
        ).quantize(Decimal("0.01"))

    elif claim_status == "Rejected":
        approved_amount = Decimal("0.00")

    return claim_status, approved_amount, settlement_date


def build_claim(sequence, policy):
    """Create one claim connected to a valid policy."""

    (
        policy_id,
        policy_start,
        policy_end,
        coverage_amount,
        product_category,
    ) = policy

    incident_end = min(policy_end, DATA_END_DATE)

    incident_date = random_date(
        policy_start,
        incident_end,
    )

    reported_date = min(
        incident_date + timedelta(days=random.randint(0, 14)),
        DATA_END_DATE,
    )

    minimum_ratio, maximum_ratio = CLAIM_RATIOS[
        product_category
    ]

    claim_ratio = Decimal(
        str(round(
            random.uniform(minimum_ratio, maximum_ratio),
            4,
        ))
    )

    claimed_amount = (
        coverage_amount * claim_ratio
    ).quantize(Decimal("0.01"))

    claimed_amount = max(
        claimed_amount,
        Decimal("100.00"),
    )

    (
        claim_status,
        approved_amount,
        settlement_date,
    ) = determine_claim_outcome(
        reported_date,
        claimed_amount,
    )

    return (
        f"CLM-{sequence:09d}",
        policy_id,
        incident_date,
        reported_date,
        random.choice(CLAIM_TYPES[product_category]),
        claim_status,
        claimed_amount,
        approved_amount,
        settlement_date,
        generate_fraud_score(),
    )


def run_pipeline():
    """Generate and load the claims."""

    connection = None
    pipeline_run_id = None

    try:
        connection = get_connection()

        with connection.cursor() as cursor:
            ensure_claim_table_is_empty(cursor)

            cursor.execute(
                """
                INSERT INTO audit.pipeline_runs (
                    pipeline_name,
                    run_status
                )
                VALUES ('generate_claims', 'RUNNING')
                RETURNING pipeline_run_id;
                """
            )

            pipeline_run_id = cursor.fetchone()[0]
            connection.commit()

            policies = load_policies(cursor)

            if len(policies) < CLAIM_COUNT:
                raise RuntimeError(
                    "There are not enough policies "
                    "to generate the claims."
                )

            selected_policies = random.sample(
                policies,
                CLAIM_COUNT,
            )

            claims = [
                build_claim(sequence, policy)
                for sequence, policy in enumerate(
                    selected_policies,
                    start=1,
                )
            ]

            cursor.executemany(
                """
                INSERT INTO core.claims (
                    claim_number,
                    policy_id,
                    incident_date,
                    reported_date,
                    claim_type,
                    claim_status,
                    claimed_amount,
                    approved_amount,
                    settlement_date,
                    fraud_score
                )
                VALUES (
                    %s, %s, %s, %s, %s,
                    %s, %s, %s, %s, %s
                );
                """,
                claims,
            )

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
                    len(claims),
                    len(claims),
                    pipeline_run_id,
                ),
            )

            connection.commit()

        print("Claims pipeline completed successfully.")
        print(f"Claims created: {len(claims):,}")
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

        print(f"Claims pipeline failed: {error}")
        raise SystemExit(1) from error

    finally:
        if connection is not None:
            connection.close()


if __name__ == "__main__":
    run_pipeline()