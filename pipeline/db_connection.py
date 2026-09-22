import os

import psycopg
from dotenv import load_dotenv


load_dotenv()


def get_database_config():
    """
    Return connection settings for either the local or cloud database.

    Set DATABASE_ENV to:
    - local: use DB_* environment variables
    - cloud: use CLOUD_DB_* environment variables
    """

    database_environment = os.getenv("DATABASE_ENV", "local").lower()

    if database_environment == "cloud":
        prefix = "CLOUD_DB_"
    elif database_environment == "local":
        prefix = "DB_"
    else:
        raise ValueError(
            "DATABASE_ENV must be either 'local' or 'cloud'."
        )

    config = {
        "host": os.getenv(f"{prefix}HOST"),
        "port": os.getenv(f"{prefix}PORT", "5432"),
        "dbname": os.getenv(f"{prefix}NAME"),
        "user": os.getenv(f"{prefix}USER"),
        "password": os.getenv(f"{prefix}PASSWORD"),
    }

    sslmode = os.getenv(f"{prefix}SSLMODE")

    if sslmode:
        config["sslmode"] = sslmode

    missing_values = [
        setting
        for setting, value in config.items()
        if value is None or value == ""
    ]

    if missing_values:
        missing_text = ", ".join(missing_values)
        raise ValueError(
            f"Missing database configuration values: {missing_text}"
        )

    return config


def get_connection():
    """Open and return a PostgreSQL database connection."""

    return psycopg.connect(**get_database_config())


def get_database_environment():
    """Return the active database environment name."""

    return os.getenv("DATABASE_ENV", "local").lower()