"""Generate fictional SecureSure insurance policies."""

import random
from collections import defaultdict
from datetime import date, timedelta
from decimal import Decimal

from db_connection import get_connection


POLICY_COUNT = 80_000
RANDOM_SEED = 43
DATA_END_DATE = date(2026, 8, 31)

random.seed(RANDOM_SEED)


COVERAGE_OPTIONS = {
    "Auto": [25_000, 50_000, 100_000],
    "Home": [150_000, 250_000, 400_000, 600_000],
    "Life": [100_000, 250_000, 500_000, 1_000_000],
    "Health": [50_000, 100_000, 250_000],
    "Travel": [10_000, 25_000, 50_000],
}

RISK_MULTIPLIERS = {
    "Low": Decimal("0.90"),
    "Medium": Decimal("1.00"),
    "High": Decimal("1.25"),
}


def random_date(start_date, end_date):
    """Return a random date within the supplied range."""

    number_of_days = (end_date - start_date).days

    if number_of_days <= 0:
        return start_date

    return start_date + timedelta(
        days=random.randint(0, number_of_days)
    )


def load_reference_data(cursor):
    """Load customers, products and agents from PostgreSQL."""

    cursor.execute(
        """
        SELECT
            customer_id,
            customer_since,
            risk_segment,
            state_code
        FROM core.customers
        ORDER BY customer_id;
        """
    )
    customers = cursor.fetchall()

    cursor.execute(
        """
        SELECT
            product_id,
            product_category,
            base_premium
        FROM core.products
        WHERE is_active = TRUE
        ORDER BY product_id;
        """
    )
    products = cursor.fetchall()

    cursor.execute(
        """
        SELECT
            a.agent_id,
            a.branch_id,
            b.state_code
        FROM core.agents AS a
        INNER JOIN core.branches AS b
            ON a.branch_id = b.branch_id
        WHERE
            a.employment_status = 'Active'
            AND b.is_active = TRUE
        ORDER BY a.agent_id;
        """
    )
    agents = cursor.fetchall()

    return customers, products, agents


def group_agents_by_state(agents):
    """Create state-based agent pools."""

    agents_by_state = defaultdict(list)

    for agent_id, branch_id, state_code in agents:
        agents_by_state[state_code].append(
            (agent_id, branch_id)
        )

    return agents_by_state


def calculate_premium(base_premium, risk_segment):
    """Calculate a realistic annual premium."""

    market_adjustment = Decimal(
        str(round(random.uniform(0.85, 1.20), 4))
    )

    premium = (
        base_premium
        * RISK_MULTIPLIERS[risk_segment]
        * market_adjustment
    )

    return premium.quantize(Decimal("0.01"))


def determine_policy_status(start_date, end_date):
    """Determine whether a policy is active, expired or cancelled."""

    cancellation_chance = random.random()

    if cancellation_chance < 0.08:
        return "Cancelled"

    if end_date < DATA_END_DATE:
        return "Expired"

    return "Active"


def generate_policies(customers, products, agents):
    """Build the fictional policy records."""

    policies = []
    agents_by_state = group_agents_by_state(agents)
    all_agents = [
        (agent_id, branch_id)
        for agent_id, branch_id, _ in agents
    ]

    for sequence in range(1, POLICY_COUNT + 1):
        (
            customer_id,
            customer_since,
            risk_segment,
            customer_state,
        ) = random.choice(customers)

        (
            product_id,
            product_category,
            base_premium,
        ) = random.choice(products)

        available_agents = agents_by_state.get(
            customer_state,
            all_agents,
        )

        agent_id, branch_id = random.choice(available_agents)

        policy_start = random_date(
            customer_since,
            DATA_END_DATE,
        )
        policy_end = policy_start + timedelta(days=365)

        coverage_amount = Decimal(
            random.choice(COVERAGE_OPTIONS[product_category])
        )

        annual_premium = calculate_premium(
            base_premium,
            risk_segment,
        )

        policy_status = determine_policy_status(
            policy_start,
            policy_end,
        )

        policies.append(
            (
                f"POL-{sequence:09d}",
                customer_id,
                product_id,
                agent_id,
                branch_id,
                policy_start,
                policy_end,
                coverage_amount,
                annual_premium,
                policy_status,
                random.random() < 0.65,
            )
        )

    return policies


def ensure_policy_table_is_empty(cursor):
    """Prevent accidental duplicate generation."""

    cursor.execute("SELECT COUNT(*) FROM core.policies;")
    policy_count = cursor.fetchone()[0]

    if policy_count > 0:
        raise RuntimeError(
            "Policies already exist. Generation was stopped "
            "to prevent duplicate data."
        )


def run_pipeline():
    """Generate and load policies into PostgreSQL."""

    connection = None
    pipeline_run_id = None

    try:
        connection = get_connection()

        with connection.cursor() as cursor:
            ensure_policy_table_is_empty(cursor)

            cursor.execute(
                """
                INSERT INTO audit.pipeline_runs (
                    pipeline_name,
                    run_status
                )
                VALUES ('generate_policies', 'RUNNING')
                RETURNING pipeline_run_id;
                """
            )

            pipeline_run_id = cursor.fetchone()[0]
            connection.commit()

            customers, products, agents = load_reference_data(
                cursor
            )

            if not customers or not products or not agents:
                raise RuntimeError(
                    "Customers, products or agents are missing."
                )

            policies = generate_policies(
                customers,
                products,
                agents,
            )

            cursor.executemany(
                """
                INSERT INTO core.policies (
                    policy_number,
                    customer_id,
                    product_id,
                    agent_id,
                    branch_id,
                    start_date,
                    end_date,
                    coverage_amount,
                    annual_premium,
                    policy_status,
                    auto_renew
                )
                VALUES (
                    %s, %s, %s, %s, %s, %s,
                    %s, %s, %s, %s, %s
                );
                """,
                policies,
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
                    len(policies),
                    len(policies),
                    pipeline_run_id,
                ),
            )

            connection.commit()

        print("Policy pipeline completed successfully.")
        print(f"Policies created: {len(policies):,}")
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

        print(f"Policy pipeline failed: {error}")
        raise SystemExit(1) from error

    finally:
        if connection is not None:
            connection.close()


if __name__ == "__main__":
    run_pipeline()