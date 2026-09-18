"""PostgreSQL connection utilities for SecureSure."""

import os
from pathlib import Path

import psycopg
from dotenv import load_dotenv


PROJECT_ROOT = Path(__file__).resolve().parents[1]
ENV_FILE = PROJECT_ROOT / ".env"

load_dotenv(ENV_FILE)


def get_connection():
    """Create and return a PostgreSQL database connection."""

    required_variables = [
        "DB_HOST",
        "DB_PORT",
        "DB_NAME",
        "DB_USER",
        "DB_PASSWORD",
    ]

    missing_variables = [
        variable
        for variable in required_variables
        if not os.getenv(variable)
    ]

    if missing_variables:
        missing = ", ".join(missing_variables)
        raise RuntimeError(
            f"Missing required environment variables: {missing}"
        )

    return psycopg.connect(
        host=os.getenv("DB_HOST"),
        port=os.getenv("DB_PORT"),
        dbname=os.getenv("DB_NAME"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),
    )


def test_connection():
    """Test the connection and retrieve basic database information."""

    try:
        with get_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT
                        current_database(),
                        current_user,
                        version();
                    """
                )
                database_name, database_user, database_version = cursor.fetchone()

                cursor.execute(
                    "SELECT COUNT(*) FROM core.branches;"
                )
                branch_count = cursor.fetchone()[0]

                cursor.execute(
                    "SELECT COUNT(*) FROM core.products;"
                )
                product_count = cursor.fetchone()[0]

        print("Database connection successful.")
        print(f"Database: {database_name}")
        print(f"User: {database_user}")
        print(f"PostgreSQL: {database_version}")
        print(f"Branches: {branch_count}")
        print(f"Products: {product_count}")

    except psycopg.Error as error:
        print("Database connection failed.")
        print(f"PostgreSQL error: {error}")
        raise SystemExit(1) from error

    except RuntimeError as error:
        print(f"Configuration error: {error}")
        raise SystemExit(1) from error


if __name__ == "__main__":
    test_connection()