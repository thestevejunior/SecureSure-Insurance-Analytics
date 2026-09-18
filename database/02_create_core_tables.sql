-- SecureSure Insurance Analytics Platform
-- Core operational tables

BEGIN;

CREATE TABLE IF NOT EXISTS core.branches (
    branch_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    branch_code VARCHAR(10) NOT NULL UNIQUE,
    branch_name VARCHAR(100) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state_code CHAR(2) NOT NULL,
    region VARCHAR(50) NOT NULL,
    opened_date DATE NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS core.agents (
    agent_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employee_number VARCHAR(20) NOT NULL UNIQUE,
    branch_id INTEGER NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    hire_date DATE NOT NULL,
    employment_status VARCHAR(20) NOT NULL DEFAULT 'Active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_agent_branch
        FOREIGN KEY (branch_id)
        REFERENCES core.branches(branch_id),

    CONSTRAINT chk_agent_status
        CHECK (employment_status IN (
            'Active',
            'Inactive',
            'Leave',
            'Terminated'
        ))
);

CREATE TABLE IF NOT EXISTS core.customers (
    customer_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_number VARCHAR(20) NOT NULL UNIQUE,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    date_of_birth DATE NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    phone VARCHAR(30),
    city VARCHAR(100) NOT NULL,
    state_code CHAR(2) NOT NULL,
    postal_code VARCHAR(10),
    customer_since DATE NOT NULL,
    risk_segment VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT customer_age_reasonable
        CHECK (date_of_birth <= CURRENT_DATE - INTERVAL '18 years'),

    CONSTRAINT chk_customer_risk_segment
        CHECK (risk_segment IN ('Low', 'Medium', 'High'))
);

CREATE TABLE IF NOT EXISTS core.products (
    product_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_code VARCHAR(20) NOT NULL UNIQUE,
    product_name VARCHAR(100) NOT NULL,
    product_category VARCHAR(30) NOT NULL,
    base_premium NUMERIC(12,2) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_base_premium
        CHECK (base_premium > 0),

    CONSTRAINT chk_product_category
        CHECK (product_category IN (
            'Auto',
            'Home',
            'Life',
            'Health',
            'Travel'
        ))
);

CREATE TABLE IF NOT EXISTS core.policies (
    policy_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    policy_number VARCHAR(30) NOT NULL UNIQUE,
    customer_id BIGINT NOT NULL,
    product_id INTEGER NOT NULL,
    agent_id BIGINT NOT NULL,
    branch_id INTEGER NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    coverage_amount NUMERIC(14,2) NOT NULL,
    annual_premium NUMERIC(12,2) NOT NULL,
    policy_status VARCHAR(20) NOT NULL,
    auto_renew BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_policy_customer
        FOREIGN KEY (customer_id)
        REFERENCES core.customers(customer_id),

    CONSTRAINT fk_policy_product
        FOREIGN KEY (product_id)
        REFERENCES core.products(product_id),

    CONSTRAINT fk_policy_agent
        FOREIGN KEY (agent_id)
        REFERENCES core.agents(agent_id),

    CONSTRAINT fk_policy_branch
        FOREIGN KEY (branch_id)
        REFERENCES core.branches(branch_id),

    CONSTRAINT chk_policy_dates
        CHECK (end_date > start_date),

    CONSTRAINT chk_coverage_amount
        CHECK (coverage_amount > 0),

    CONSTRAINT chk_annual_premium
        CHECK (annual_premium > 0),

    CONSTRAINT chk_policy_status
        CHECK (policy_status IN (
            'Active',
            'Expired',
            'Cancelled',
            'Pending'
        ))
);

CREATE TABLE IF NOT EXISTS core.payments (
    payment_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    payment_reference VARCHAR(40) NOT NULL UNIQUE,
    policy_id BIGINT NOT NULL,
    payment_date DATE NOT NULL,
    due_date DATE NOT NULL,
    amount_due NUMERIC(12,2) NOT NULL,
    amount_paid NUMERIC(12,2) NOT NULL DEFAULT 0,
    payment_method VARCHAR(30),
    payment_status VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_payment_policy
        FOREIGN KEY (policy_id)
        REFERENCES core.policies(policy_id),

    CONSTRAINT chk_payment_amounts
        CHECK (
            amount_due > 0
            AND amount_paid >= 0
            AND amount_paid <= amount_due
        ),

    CONSTRAINT chk_payment_status
        CHECK (payment_status IN (
            'Paid',
            'Partial',
            'Overdue',
            'Pending',
            'Failed'
        ))
);

CREATE TABLE IF NOT EXISTS core.claims (
    claim_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    claim_number VARCHAR(30) NOT NULL UNIQUE,
    policy_id BIGINT NOT NULL,
    incident_date DATE NOT NULL,
    reported_date DATE NOT NULL,
    claim_type VARCHAR(50) NOT NULL,
    claim_status VARCHAR(30) NOT NULL,
    claimed_amount NUMERIC(14,2) NOT NULL,
    approved_amount NUMERIC(14,2),
    settlement_date DATE,
    fraud_score NUMERIC(5,2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_claim_policy
        FOREIGN KEY (policy_id)
        REFERENCES core.policies(policy_id),

    CONSTRAINT chk_claim_dates
        CHECK (reported_date >= incident_date),

    CONSTRAINT chk_claimed_amount
        CHECK (claimed_amount > 0),

    CONSTRAINT chk_approved_amount
        CHECK (
            approved_amount IS NULL
            OR approved_amount >= 0
        ),

    CONSTRAINT chk_fraud_score
        CHECK (
            fraud_score IS NULL
            OR fraud_score BETWEEN 0 AND 100
        ),

    CONSTRAINT chk_claim_status
        CHECK (claim_status IN (
            'Submitted',
            'Under Review',
            'Approved',
            'Rejected',
            'Settled'
        ))
);

CREATE TABLE IF NOT EXISTS core.branch_targets (
    target_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    branch_id INTEGER NOT NULL,
    target_month DATE NOT NULL,
    premium_target NUMERIC(14,2) NOT NULL,
    policy_target INTEGER NOT NULL,
    renewal_rate_target NUMERIC(5,2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_target_branch
        FOREIGN KEY (branch_id)
        REFERENCES core.branches(branch_id),

    CONSTRAINT uq_branch_target_month
        UNIQUE (branch_id, target_month),

    CONSTRAINT chk_target_values
        CHECK (
            premium_target > 0
            AND policy_target > 0
            AND renewal_rate_target BETWEEN 0 AND 100
        )
);

COMMIT;