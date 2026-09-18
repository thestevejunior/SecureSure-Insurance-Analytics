-- Dashboard-ready monthly branch performance view.

CREATE OR REPLACE VIEW analytics.branch_monthly_performance AS

WITH policy_metrics AS (
    SELECT
        p.branch_id,
        DATE_TRUNC('month', p.start_date)::DATE AS report_month,
        COUNT(*) AS new_policy_count,
        COUNT(DISTINCT p.customer_id) AS new_policy_customers,
        SUM(p.annual_premium) AS written_premium,
        COUNT(*) FILTER (
            WHERE p.auto_renew = TRUE
        ) AS auto_renew_policy_count
    FROM core.policies AS p
    GROUP BY
        p.branch_id,
        DATE_TRUNC('month', p.start_date)::DATE
),

payment_metrics AS (
    SELECT
        p.branch_id,
        DATE_TRUNC('month', pay.due_date)::DATE AS report_month,
        SUM(pay.amount_due) AS premium_due,
        SUM(pay.amount_paid) AS premium_collected,
        COUNT(*) FILTER (
            WHERE pay.payment_status = 'Overdue'
        ) AS overdue_payment_count,
        COUNT(*) FILTER (
            WHERE pay.payment_status = 'Failed'
        ) AS failed_payment_count
    FROM core.payments AS pay
    INNER JOIN core.policies AS p
        ON pay.policy_id = p.policy_id
    GROUP BY
        p.branch_id,
        DATE_TRUNC('month', pay.due_date)::DATE
),

claim_metrics AS (
    SELECT
        p.branch_id,
        DATE_TRUNC('month', c.reported_date)::DATE AS report_month,
        COUNT(*) AS claims_reported,
        SUM(c.claimed_amount) AS total_claimed_amount,
        SUM(
            COALESCE(c.approved_amount, 0)
        ) AS total_approved_amount,
        COUNT(*) FILTER (
            WHERE c.fraud_score >= 65
        ) AS high_risk_claim_count,
        COUNT(*) FILTER (
            WHERE c.claim_status IN (
                'Submitted',
                'Under Review',
                'Approved'
            )
        ) AS open_claim_count,
        AVG(
            c.settlement_date - c.reported_date
        ) FILTER (
            WHERE c.settlement_date IS NOT NULL
        ) AS average_settlement_days
    FROM core.claims AS c
    INNER JOIN core.policies AS p
        ON c.policy_id = p.policy_id
    GROUP BY
        p.branch_id,
        DATE_TRUNC('month', c.reported_date)::DATE
)

SELECT
    bt.target_month AS report_month,
    EXTRACT(YEAR FROM bt.target_month)::INTEGER AS report_year,
    EXTRACT(MONTH FROM bt.target_month)::INTEGER AS report_month_number,

    b.branch_id,
    b.branch_code,
    b.branch_name,
    b.city,
    b.state_code,
    b.region,

    bt.premium_target,
    bt.policy_target,
    bt.renewal_rate_target,

    COALESCE(pm.new_policy_count, 0) AS new_policy_count,
    COALESCE(pm.new_policy_customers, 0) AS new_policy_customers,
    COALESCE(pm.written_premium, 0) AS written_premium,
    COALESCE(
        pm.auto_renew_policy_count,
        0
    ) AS auto_renew_policy_count,

    COALESCE(paym.premium_due, 0) AS premium_due,
    COALESCE(
        paym.premium_collected,
        0
    ) AS premium_collected,
    COALESCE(
        paym.overdue_payment_count,
        0
    ) AS overdue_payment_count,
    COALESCE(
        paym.failed_payment_count,
        0
    ) AS failed_payment_count,

    COALESCE(cm.claims_reported, 0) AS claims_reported,
    COALESCE(
        cm.total_claimed_amount,
        0
    ) AS total_claimed_amount,
    COALESCE(
        cm.total_approved_amount,
        0
    ) AS total_approved_amount,
    COALESCE(
        cm.high_risk_claim_count,
        0
    ) AS high_risk_claim_count,
    COALESCE(
        cm.open_claim_count,
        0
    ) AS open_claim_count,
    ROUND(
        cm.average_settlement_days,
        1
    ) AS average_settlement_days,

    COALESCE(pm.written_premium, 0)
        - bt.premium_target
        AS premium_target_variance,

    COALESCE(pm.new_policy_count, 0)
        - bt.policy_target
        AS policy_target_variance,

    ROUND(
        100.0
        * COALESCE(pm.written_premium, 0)
        / NULLIF(bt.premium_target, 0),
        2
    ) AS premium_target_attainment_pct,

    ROUND(
        100.0
        * COALESCE(pm.new_policy_count, 0)
        / NULLIF(bt.policy_target, 0),
        2
    ) AS policy_target_attainment_pct,

    ROUND(
        100.0
        * COALESCE(paym.premium_collected, 0)
        / NULLIF(paym.premium_due, 0),
        2
    ) AS collection_rate_pct,

    ROUND(
        100.0
        * COALESCE(pm.auto_renew_policy_count, 0)
        / NULLIF(pm.new_policy_count, 0),
        2
    ) AS auto_renew_enrollment_pct,

    ROUND(
        100.0
        * COALESCE(cm.total_approved_amount, 0)
        / NULLIF(paym.premium_collected, 0),
        2
    ) AS approved_claims_to_collections_pct

FROM core.branch_targets AS bt
INNER JOIN core.branches AS b
    ON bt.branch_id = b.branch_id
LEFT JOIN policy_metrics AS pm
    ON bt.branch_id = pm.branch_id
    AND bt.target_month = pm.report_month
LEFT JOIN payment_metrics AS paym
    ON bt.branch_id = paym.branch_id
    AND bt.target_month = paym.report_month
LEFT JOIN claim_metrics AS cm
    ON bt.branch_id = cm.branch_id
    AND bt.target_month = cm.report_month;