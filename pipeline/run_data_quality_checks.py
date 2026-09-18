"""Run and record SecureSure data-quality checks."""

from decimal import Decimal

from db_connection import get_connection


EXPECTED_COUNTS = {
    "core.branches": 31,
    "core.products": 10,
    "core.agents": 155,
    "core.customers": 50_000,
    "core.policies": 80_000,
    "core.payments": 320_000,
    "core.claims": 25_000,
    "core.branch_targets": 1_364,
    "analytics.branch_monthly_performance": 1_364,
    "analytics.claims_operations": 25_000,
    "analytics.product_monthly_performance": 440,
}


INVARIANT_CHECKS = [
    {
        "name": "Duplicate business identifiers",
        "table": "core",
        "category": "Uniqueness",
        "expected": 0,
        "rule": "Business identifiers must be unique.",
        "query": """
            SELECT
                (
                    SELECT COUNT(*)
                         - COUNT(DISTINCT customer_number)
                    FROM core.customers
                )
                +
                (
                    SELECT COUNT(*)
                         - COUNT(DISTINCT policy_number)
                    FROM core.policies
                )
                +
                (
                    SELECT COUNT(*)
                         - COUNT(DISTINCT payment_reference)
                    FROM core.payments
                )
                +
                (
                    SELECT COUNT(*)
                         - COUNT(DISTINCT claim_number)
                    FROM core.claims
                );
        """,
    },
    {
        "name": "Invalid policy dates",
        "table": "core.policies",
        "category": "Validity",
        "expected": 0,
        "rule": "Policy end date must be after start date.",
        "query": """
            SELECT COUNT(*)
            FROM core.policies
            WHERE end_date <= start_date;
        """,
    },
    {
        "name": "Invalid claim dates",
        "table": "core.claims",
        "category": "Validity",
        "expected": 0,
        "rule": "Reported date cannot precede incident date.",
        "query": """
            SELECT COUNT(*)
            FROM core.claims
            WHERE reported_date < incident_date;
        """,
    },
    {
        "name": "Invalid payment status values",
        "table": "core.payments",
        "category": "Consistency",
        "expected": 0,
        "rule": (
            "Paid and partial records require payment dates; "
            "unpaid records require zero amount paid."
        ),
        "query": """
            SELECT COUNT(*)
            FROM core.payments
            WHERE
                (
                    payment_status = 'Paid'
                    AND (
                        amount_paid <> amount_due
                        OR payment_date IS NULL
                    )
                )
                OR
                (
                    payment_status = 'Partial'
                    AND (
                        amount_paid <= 0
                        OR amount_paid >= amount_due
                        OR payment_date IS NULL
                    )
                )
                OR
                (
                    payment_status IN (
                        'Overdue',
                        'Pending',
                        'Failed'
                    )
                    AND (
                        amount_paid <> 0
                        OR payment_date IS NOT NULL
                    )
                );
        """,
    },
    {
        "name": "Broken policy relationships",
        "table": "core.policies",
        "category": "Relationship",
        "expected": 0,
        "rule": (
            "Every policy must have a valid customer, "
            "product, agent and branch."
        ),
        "query": """
            SELECT COUNT(*)
            FROM core.policies AS p
            LEFT JOIN core.customers AS c
                ON p.customer_id = c.customer_id
            LEFT JOIN core.products AS pr
                ON p.product_id = pr.product_id
            LEFT JOIN core.agents AS a
                ON p.agent_id = a.agent_id
            LEFT JOIN core.branches AS b
                ON p.branch_id = b.branch_id
            WHERE
                c.customer_id IS NULL
                OR pr.product_id IS NULL
                OR a.agent_id IS NULL
                OR b.branch_id IS NULL;
        """,
    },
]


def save_result(
    cursor,
    pipeline_run_id,
    check_name,
    checked_table,
    category,
    actual_value,
    expected_value,
    expected_rule,
):
    """Evaluate and save one quality-check result."""

    actual_decimal = Decimal(str(actual_value))
    expected_decimal = Decimal(str(expected_value))

    if actual_decimal == expected_decimal:
        status = "PASS"
        details = None
    else:
        status = "FAIL"
        details = (
            f"Expected {expected_value}, "
            f"but found {actual_value}."
        )

    cursor.execute(
        """
        INSERT INTO audit.data_quality_results (
            pipeline_run_id,
            check_name,
            checked_table,
            check_category,
            check_status,
            actual_value,
            expected_rule,
            failure_details
        )
        VALUES (
            %s, %s, %s, %s,
            %s, %s, %s, %s
        );
        """,
        (
            pipeline_run_id,
            check_name,
            checked_table,
            category,
            status,
            actual_decimal,
            expected_rule,
            details,
        ),
    )

    symbol = "PASS" if status == "PASS" else "FAIL"
    print(
        f"[{symbol}] {check_name}: "
        f"actual={actual_value}, expected={expected_value}"
    )

    return status


def run_checks():
    """Execute all data-quality checks."""

    connection = None
    pipeline_run_id = None

    try:
        connection = get_connection()

        with connection.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO audit.pipeline_runs (
                    pipeline_name,
                    run_status
                )
                VALUES (
                    'run_data_quality_checks',
                    'RUNNING'
                )
                RETURNING pipeline_run_id;
                """
            )

            pipeline_run_id = cursor.fetchone()[0]
            connection.commit()

            results = []

            for table_name, expected_count in EXPECTED_COUNTS.items():
                cursor.execute(
                    f"SELECT COUNT(*) FROM {table_name};"
                )
                actual_count = cursor.fetchone()[0]

                results.append(
                    save_result(
                        cursor=cursor,
                        pipeline_run_id=pipeline_run_id,
                        check_name=f"{table_name} row count",
                        checked_table=table_name,
                        category="Volume",
                        actual_value=actual_count,
                        expected_value=expected_count,
                        expected_rule=(
                            f"Table must contain exactly "
                            f"{expected_count:,} rows."
                        ),
                    )
                )

            for check in INVARIANT_CHECKS:
                cursor.execute(check["query"])
                actual_value = cursor.fetchone()[0]

                results.append(
                    save_result(
                        cursor=cursor,
                        pipeline_run_id=pipeline_run_id,
                        check_name=check["name"],
                        checked_table=check["table"],
                        category=check["category"],
                        actual_value=actual_value,
                        expected_value=check["expected"],
                        expected_rule=check["rule"],
                    )
                )

            passed = results.count("PASS")
            failed = results.count("FAIL")
            total = len(results)

            cursor.execute(
                """
                UPDATE audit.pipeline_runs
                SET
                    completed_at = CURRENT_TIMESTAMP,
                    run_status = 'SUCCESS',
                    records_received = %s,
                    records_loaded = %s,
                    records_rejected = %s
                WHERE pipeline_run_id = %s;
                """,
                (
                    total,
                    passed,
                    failed,
                    pipeline_run_id,
                ),
            )

            connection.commit()

        print()
        print("Data-quality checks completed.")
        print(f"Passed: {passed}/{total}")
        print(f"Failed: {failed}/{total}")

        if failed > 0:
            raise SystemExit(1)

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

        print(f"Quality-check process failed: {error}")
        raise SystemExit(1) from error

    finally:
        if connection is not None:
            connection.close()


if __name__ == "__main__":
    run_checks()