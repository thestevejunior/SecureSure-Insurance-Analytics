-- Store the results of automated data-quality checks.

BEGIN;

CREATE TABLE IF NOT EXISTS audit.data_quality_results (
    quality_result_id BIGINT
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    pipeline_run_id BIGINT,

    check_name VARCHAR(150) NOT NULL,
    checked_table VARCHAR(150) NOT NULL,
    check_category VARCHAR(50) NOT NULL,
    check_status VARCHAR(10) NOT NULL,

    actual_value NUMERIC(20,4),
    expected_rule TEXT NOT NULL,
    failure_details TEXT,

    checked_at TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_quality_pipeline_run
        FOREIGN KEY (pipeline_run_id)
        REFERENCES audit.pipeline_runs(pipeline_run_id)
        ON DELETE SET NULL,

    CONSTRAINT chk_quality_status
        CHECK (
            check_status IN ('PASS', 'WARN', 'FAIL')
        ),

    CONSTRAINT chk_quality_category
        CHECK (
            check_category IN (
                'Completeness',
                'Validity',
                'Uniqueness',
                'Consistency',
                'Freshness',
                'Volume',
                'Relationship'
            )
        )
);

CREATE INDEX IF NOT EXISTS idx_quality_results_checked
    ON audit.data_quality_results (checked_at DESC);

CREATE INDEX IF NOT EXISTS idx_quality_results_status
    ON audit.data_quality_results (
        check_status,
        checked_at DESC
    );

CREATE INDEX IF NOT EXISTS idx_quality_results_pipeline
    ON audit.data_quality_results (pipeline_run_id);

CREATE OR REPLACE VIEW audit.latest_data_quality_results AS

SELECT DISTINCT ON (check_name)
    quality_result_id,
    pipeline_run_id,
    check_name,
    checked_table,
    check_category,
    check_status,
    actual_value,
    expected_rule,
    failure_details,
    checked_at

FROM audit.data_quality_results

ORDER BY
    check_name,
    checked_at DESC,
    quality_result_id DESC;

COMMIT;