-- SecureSure database performance indexes

BEGIN;

-- Agent lookups
CREATE INDEX IF NOT EXISTS idx_agents_branch
    ON core.agents (branch_id);

-- Customer analysis
CREATE INDEX IF NOT EXISTS idx_customers_state
    ON core.customers (state_code);

CREATE INDEX IF NOT EXISTS idx_customers_risk_segment
    ON core.customers (risk_segment);

CREATE INDEX IF NOT EXISTS idx_customers_since
    ON core.customers (customer_since);

-- Policy relationships and dashboard filters
CREATE INDEX IF NOT EXISTS idx_policies_customer
    ON core.policies (customer_id);

CREATE INDEX IF NOT EXISTS idx_policies_product
    ON core.policies (product_id);

CREATE INDEX IF NOT EXISTS idx_policies_agent
    ON core.policies (agent_id);

CREATE INDEX IF NOT EXISTS idx_policies_branch_start
    ON core.policies (branch_id, start_date);

CREATE INDEX IF NOT EXISTS idx_policies_status
    ON core.policies (policy_status);

CREATE INDEX IF NOT EXISTS idx_policies_end_date
    ON core.policies (end_date);

-- Payment relationships and reporting dates
CREATE INDEX IF NOT EXISTS idx_payments_policy
    ON core.payments (policy_id);

CREATE INDEX IF NOT EXISTS idx_payments_due_status
    ON core.payments (due_date, payment_status);

CREATE INDEX IF NOT EXISTS idx_payments_payment_date
    ON core.payments (payment_date)
    WHERE payment_date IS NOT NULL;

-- Claim relationships and operational filters
CREATE INDEX IF NOT EXISTS idx_claims_policy
    ON core.claims (policy_id);

CREATE INDEX IF NOT EXISTS idx_claims_reported_status
    ON core.claims (reported_date, claim_status);

CREATE INDEX IF NOT EXISTS idx_claims_settlement_date
    ON core.claims (settlement_date)
    WHERE settlement_date IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_claims_high_fraud_score
    ON core.claims (fraud_score DESC)
    WHERE fraud_score >= 65;

-- Branch-target reporting
CREATE INDEX IF NOT EXISTS idx_branch_targets_month
    ON core.branch_targets (target_month);

-- Pipeline monitoring
CREATE INDEX IF NOT EXISTS idx_pipeline_runs_started
    ON audit.pipeline_runs (started_at DESC);

COMMIT;

-- Update PostgreSQL's table statistics for query planning.
ANALYZE core.agents;
ANALYZE core.customers;
ANALYZE core.policies;
ANALYZE core.payments;
ANALYZE core.claims;
ANALYZE core.branch_targets;