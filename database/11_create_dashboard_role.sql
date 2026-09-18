-- Create a read-only account for Power BI and Tableau.
-- The password is assigned separately and is never stored in Git.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'dashboard_reader'
    ) THEN
        CREATE ROLE dashboard_reader LOGIN;
    END IF;
END
$$;

GRANT CONNECT
    ON DATABASE securesure
    TO dashboard_reader;

GRANT USAGE
    ON SCHEMA analytics
    TO dashboard_reader;

GRANT SELECT
    ON ALL TABLES IN SCHEMA analytics
    TO dashboard_reader;

-- Automatically grant access to future analytics views.
ALTER DEFAULT PRIVILEGES
    FOR ROLE postgres
    IN SCHEMA analytics
    GRANT SELECT ON TABLES
    TO dashboard_reader;

-- Explicitly prevent access to sensitive operational layers.
REVOKE ALL
    ON SCHEMA raw
    FROM dashboard_reader;

REVOKE ALL
    ON SCHEMA core
    FROM dashboard_reader;

REVOKE ALL
    ON SCHEMA audit
    FROM dashboard_reader;