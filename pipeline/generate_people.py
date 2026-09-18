"""Generate fictional SecureSure agents and customers."""

import random
import re
from datetime import date

from faker import Faker

from db_connection import get_connection


AGENTS_PER_BRANCH = 5
CUSTOMER_COUNT = 50_000
RANDOM_SEED = 42

fake = Faker("en_US")
Faker.seed(RANDOM_SEED)
random.seed(RANDOM_SEED)


def create_email(first_name, last_name, number):
    """Create a unique fictional email address."""

    name = f"{first_name}.{last_name}".lower()
    name = re.sub(r"[^a-z0-9.]", "", name)

    return f"{name}.{number}@example.com"


def get_branches(cursor):
    """Retrieve branches used to distribute agents and customers."""

    cursor.execute(
        """
        SELECT
            branch_id,
            city,
            state_code
        FROM core.branches
        WHERE is_active = TRUE
        ORDER BY branch_id;
        """
    )

    return cursor.fetchall()


def generate_agents(branches):
    """Create five fictional agents for each company branch."""

    agents = []
    employee_sequence = 1

    for branch_id, _, _ in branches:
        for _ in range(AGENTS_PER_BRANCH):
            agents.append(
                (
                    f"EMP-{employee_sequence:05d}",
                    branch_id,
                    fake.first_name(),
                    fake.last_name(),
                    fake.date_between(
                        start_date=date(2008, 1, 1),
                        end_date=date(2025, 12, 31),
                    ),
                    "Active",
                )
            )

            employee_sequence += 1

    return agents


def generate_customers(branches):
    """Create fictional customers located near company branches."""

    customers = []

    for customer_sequence in range(1, CUSTOMER_COUNT + 1):
        _, city, state_code = random.choice(branches)

        first_name = fake.first_name()
        last_name = fake.last_name()

        customers.append(
            (
                f"CUST-{customer_sequence:07d}",
                first_name,
                last_name,
                fake.date_between(
                    start_date=date(1946, 1, 1),
                    end_date=date(2008, 8, 31),
                ),
                create_email(
                    first_name,
                    last_name,
                    customer_sequence,
                ),
                fake.numerify("(###) ###-####"),
                city,
                state_code,
                fake.postcode(),
                fake.date_between(
                    start_date=date(2023, 1, 1),
                    end_date=date(2026, 8, 31),
                ),
                random.choices(
                    population=["Low", "Medium", "High"],
                    weights=[50, 35, 15],
                    k=1,
                )[0],
            )
        )

    return customers


def ensure_tables_are_empty(cursor):
    """Prevent accidental duplicate test-data generation."""

    cursor.execute("SELECT COUNT(*) FROM core.agents;")
    agent_count = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM core.customers;")
    customer_count = cursor.fetchone()[0]

    if agent_count > 0 or customer_count > 0:
        raise RuntimeError(
            "Agents or customers already exist. "
            "The generator was stopped to prevent duplicate data."
        )


def run_pipeline():
    """Generate and load agents and customers."""

    connection = None
    pipeline_run_id = None

    try:
        connection = get_connection()

        with connection.cursor() as cursor:
            ensure_tables_are_empty(cursor)

            cursor.execute(
                """
                INSERT INTO audit.pipeline_runs (
                    pipeline_name,
                    run_status
                )
                VALUES ('generate_people', 'RUNNING')
                RETURNING pipeline_run_id;
                """
            )

            pipeline_run_id = cursor.fetchone()[0]
            connection.commit()

            branches = get_branches(cursor)

            if not branches:
                raise RuntimeError(
                    "No active branches were found."
                )

            agents = generate_agents(branches)
            customers = generate_customers(branches)

            cursor.executemany(
                """
                INSERT INTO core.agents (
                    employee_number,
                    branch_id,
                    first_name,
                    last_name,
                    hire_date,
                    employment_status
                )
                VALUES (%s, %s, %s, %s, %s, %s);
                """,
                agents,
            )

            cursor.executemany(
                """
                INSERT INTO core.customers (
                    customer_number,
                    first_name,
                    last_name,
                    date_of_birth,
                    email,
                    phone,
                    city,
                    state_code,
                    postal_code,
                    customer_since,
                    risk_segment
                )
                VALUES (
                    %s, %s, %s, %s, %s, %s,
                    %s, %s, %s, %s, %s
                );
                """,
                customers,
            )

            total_records = len(agents) + len(customers)

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
                    total_records,
                    total_records,
                    pipeline_run_id,
                ),
            )

            connection.commit()

        print("People pipeline completed successfully.")
        print(f"Agents created: {len(agents):,}")
        print(f"Customers created: {len(customers):,}")
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

        print(f"People pipeline failed: {error}")
        raise SystemExit(1) from error

    finally:
        if connection is not None:
            connection.close()


if __name__ == "__main__":
    run_pipeline()