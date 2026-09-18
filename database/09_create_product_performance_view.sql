-- Monthly product performance for Power BI and Tableau.

CREATE OR REPLACE VIEW analytics.product_monthly_performance AS

WITH calendar AS (
    SELECT
        generate_series(
            DATE '2023-01-01',
            DATE '2026-08-01',
            INTERVAL '1 month'
        )::DATE AS report_month
),

product_calendar AS (
    SELECT
        pr.product_id,
        pr.product_code,
        pr.product_name,
        pr.product_category,
        pr.base_premium,
        calendar.report_month
    FROM core.products AS pr
    CROSS JOIN calendar
    WHERE pr.is_active = TRUE
),

policy_metrics AS (
    SELECT
        p.product_id,
        DATE_TRUNC('month', p.start_date)::DATE
            AS report_month,
        COUNT(*) AS new_policy_count,
        COUNT(DISTINCT p.customer_id)
            AS unique_customers,
        SUM(p.annual_premium)
            AS written_premium,
        AVG(p.annual_premium)
            AS average_policy_premium,
        COUNT(*) FILTER (
            WHERE p.auto_renew = TRUE
        ) AS auto_renew_policy_count
    FROM core.policies AS p
    GROUP BY
        p.product_id,
        DATE_TRUNC('month', p.start_date)::DATE
),

payment_metrics AS (
    SELECT
        p.product_id,
        DATE_TRUNC('month', pay.due_date)::DATE
            AS report_month,
        COUNT(*) AS scheduled_payment_count,
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
        p.product_id,
        DATE_TRUNC('month', pay.due_date)::DATE
),

claim_metrics AS (
    SELECT
        p.product_id,
        DATE_TRUNC('month', c.reported_date)::DATE
            AS report_month,
        COUNT(*) AS claims_reported,
        SUM(c.claimed_amount) AS total_claimed_amount,
        SUM(
            COALESCE(c.approved_amount, 0)
        ) AS total_approved_amount,
        AVG(c.claimed_amount) AS average_claim_amount,
        COUNT(*) FILTER (
            WHERE c.claim_status = 'Settled'
        ) AS settled_claim_count,
        COUNT(*) FILTER (
            WHERE c.claim_status IN (
                'Submitted',
                'Under Review',
                'Approved'
            )
        ) AS open_claim_count,
        COUNT(*) FILTER (
            WHERE c.fraud_score >= 65
        ) AS high_risk_claim_count,
        AVG(
            c.settlement_date - c.reported_date
        ) FILTER (
            WHERE c.settlement_date IS NOT NULL
        ) AS average_settlement_days
    FROM core.claims AS c
    INNER JOIN core.policies AS p
        ON c.policy_id = p.policy_id
    GROUP BY
        p.product_id,
        DATE_TRUNC('month', c.reported_date)::DATE
)

SELECT
    pc.report_month,
    EXTRACT(YEAR FROM pc.report_month)::INTEGER
        AS report_year,
    EXTRACT(MONTH FROM pc.report_month)::INTEGER
        AS report_month_number,

    pc.product_id,
    pc.product_code,
    pc.product_name,
    pc.product_category,
    pc.base_premium,

    COALESCE(pm.new_policy_count, 0)
        AS new_policy_count,
    COALESCE(pm.unique_customers, 0)
        AS unique_customers,
    COALESCE(pm.written_premium, 0)
        AS written_premium,
    ROUND(
        COALESCE(pm.average_policy_premium, 0),
        2
    ) AS average_policy_premium,
    COALESCE(pm.auto_renew_policy_count, 0)
        AS auto_renew_policy_count,

    COALESCE(paym.scheduled_payment_count, 0)
        AS scheduled_payment_count,
    COALESCE(paym.premium_due, 0)
        AS premium_due,
    COALESCE(paym.premium_collected, 0)
        AS premium_collected,
    COALESCE(paym.overdue_payment_count, 0)
        AS overdue_payment_count,
    COALESCE(paym.failed_payment_count, 0)
        AS failed_payment_count,

    COALESCE(cm.claims_reported, 0)
        AS claims_reported,
    COALESCE(cm.total_claimed_amount, 0)
        AS total_claimed_amount,
    COALESCE(cm.total_approved_amount, 0)
        AS total_approved_amount,
    ROUND(
        COALESCE(cm.average_claim_amount, 0),
        2
    ) AS average_claim_amount,
    COALESCE(cm.settled_claim_count, 0)
        AS settled_claim_count,
    COALESCE(cm.open_claim_count, 0)
        AS open_claim_count,
    COALESCE(cm.high_risk_claim_count, 0)
        AS high_risk_claim_count,
    ROUND(
        cm.average_settlement_days,
        1
    ) AS average_settlement_days,

    ROUND(
        100.0
        * COALESCE(pm.auto_renew_policy_count, 0)
        / NULLIF(pm.new_policy_count, 0),
        2
    ) AS auto_renew_enrollment_pct,

    ROUND(
        100.0
        * COALESCE(paym.premium_collected, 0)
        / NULLIF(paym.premium_due, 0),
        2
    ) AS collection_rate_pct,

    ROUND(
        100.0
        * COALESCE(paym.overdue_payment_count, 0)
        / NULLIF(paym.scheduled_payment_count, 0),
        2
    ) AS overdue_payment_pct,

    ROUND(
        100.0
        * COALESCE(cm.total_approved_amount, 0)
        / NULLIF(paym.premium_collected, 0),
        2
    ) AS approved_claims_to_collections_pct

FROM product_calendar AS pc

LEFT JOIN policy_metrics AS pm
    ON pc.product_id = pm.product_id
    AND pc.report_month = pm.report_month

LEFT JOIN payment_metrics AS paym
    ON pc.product_id = paym.product_id
    AND pc.report_month = paym.report_month

LEFT JOIN claim_metrics AS cm
    ON pc.product_id = cm.product_id
    AND pc.report_month = cm.report_month;