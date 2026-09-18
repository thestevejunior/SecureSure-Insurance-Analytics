-- Dashboard-ready claims operations view.
-- Customer personal information is intentionally excluded.

CREATE OR REPLACE VIEW analytics.claims_operations AS

SELECT
    c.claim_id,
    c.claim_number,
    c.policy_id,
    p.policy_number,

    b.branch_id,
    b.branch_code,
    b.branch_name,
    b.city AS branch_city,
    b.state_code,
    b.region,

    pr.product_code,
    pr.product_name,
    pr.product_category,

    cu.customer_number,
    cu.risk_segment,

    DATE_PART(
        'year',
        AGE(c.incident_date, cu.date_of_birth)
    )::INTEGER AS customer_age_at_incident,

    c.incident_date,
    c.reported_date,
    DATE_TRUNC(
        'month',
        c.reported_date
    )::DATE AS reported_month,

    c.claim_type,
    c.claim_status,
    c.claimed_amount,
    c.approved_amount,
    c.settlement_date,
    c.fraud_score,

    c.reported_date - c.incident_date
        AS days_to_report,

    CASE
        WHEN c.settlement_date IS NOT NULL
            THEN c.settlement_date - c.reported_date
        ELSE NULL
    END AS settlement_days,

    CASE
        WHEN c.claim_status IN (
            'Submitted',
            'Under Review',
            'Approved'
        )
            THEN DATE '2026-08-31' - c.reported_date
        ELSE NULL
    END AS open_claim_age_days,

    CASE
        WHEN c.claim_status IN (
            'Submitted',
            'Under Review',
            'Approved'
        )
            THEN 'Open'
        ELSE 'Closed'
    END AS operational_status,

    CASE
        WHEN c.settlement_date IS NOT NULL
             AND c.settlement_date - c.reported_date <= 30
            THEN 'Within SLA'

        WHEN c.settlement_date IS NOT NULL
             AND c.settlement_date - c.reported_date > 30
            THEN 'SLA Breached'

        WHEN c.claim_status IN (
            'Submitted',
            'Under Review',
            'Approved'
        )
             AND DATE '2026-08-31' - c.reported_date <= 30
            THEN 'Within SLA'

        WHEN c.claim_status IN (
            'Submitted',
            'Under Review',
            'Approved'
        )
             AND DATE '2026-08-31' - c.reported_date > 30
            THEN 'SLA Breached'

        ELSE 'Not Measurable'
    END AS sla_status,

    CASE
        WHEN c.fraud_score >= 65
            THEN 'High Review Priority'
        WHEN c.fraud_score >= 35
            THEN 'Medium Review Priority'
        ELSE 'Low Review Priority'
    END AS fraud_review_priority,

    ROUND(
        100.0
        * c.claimed_amount
        / NULLIF(p.coverage_amount, 0),
        2
    ) AS claim_severity_pct,

    ROUND(
        100.0
        * c.approved_amount
        / NULLIF(c.claimed_amount, 0),
        2
    ) AS approved_claim_pct,

    CASE
        WHEN c.fraud_score >= 65
            THEN TRUE
        ELSE FALSE
    END AS requires_fraud_review

FROM core.claims AS c

INNER JOIN core.policies AS p
    ON c.policy_id = p.policy_id

INNER JOIN core.products AS pr
    ON p.product_id = pr.product_id

INNER JOIN core.branches AS b
    ON p.branch_id = b.branch_id

INNER JOIN core.customers AS cu
    ON p.customer_id = cu.customer_id;