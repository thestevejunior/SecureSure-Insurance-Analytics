-- SecureSure Insurance Analytics Platform
-- Creates the main database schemas and pipeline audit table.

BEGIN;

-- Data received directly from source systems.
CREATE SCHEMA IF NOT EXISTS raw;

-- Cleaned and validated company data.
CREATE SCHEMA IF NOT EXISTS core;

-- Reporting views and dashboard-ready data.
CREATE SCHEMA IF NOT EXISTS analytics;

-- Pipeline runs, errors and data-quality results.
CREATE SCHEMA IF NOT EXISTS audit;

COMMENT ON SCHEMA raw IS
    'Unprocessed data received from operational source systems.';

COMMENT ON SCHEMA core IS
    'Cleaned and validated operational insurance data.';

COMMENT ON SCHEMA analytics IS
    'Dashboard-ready views and aggregated reporting data.';

COMMENT ON SCHEMA audit IS
    'Pipeline execution records and data-quality monitoring results.';

CREATE TABLE IF NOT EXISTS audit.pipeline_runs (
    pipeline_run_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pipeline_name VARCHAR(100) NOT NULL,
    started_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMPTZ,
    run_status VARCHAR(20) NOT NULL DEFAULT 'RUNNING',
    records_received INTEGER NOT NULL DEFAULT 0,
    records_loaded INTEGER NOT NULL DEFAULT 0,
    records_rejected INTEGER NOT NULL DEFAULT 0,
    error_message TEXT,

    CONSTRAINT chk_pipeline_status
        CHECK (run_status IN ('RUNNING', 'SUCCESS', 'FAILED', 'PARTIAL')),

    CONSTRAINT chk_pipeline_counts
        CHECK (
            records_received >= 0
            AND records_loaded >= 0
            AND records_rejected >= 0
        )
);

COMMENT ON TABLE audit.pipeline_runs IS
    'Records the status and row counts of every automated data pipeline run.';

COMMIT;