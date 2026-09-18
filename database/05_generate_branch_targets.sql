-- Generate monthly performance targets for every branch.

BEGIN;

WITH months AS (
    SELECT
        generate_series(
            DATE '2023-01-01',
            DATE '2026-08-01',
            INTERVAL '1 month'
        )::DATE AS target_month
),
target_calculations AS (
    SELECT
        b.branch_id,
        m.target_month,

        CASE
            WHEN EXTRACT(MONTH FROM m.target_month) IN (11, 12)
                THEN 1.15
            WHEN EXTRACT(MONTH FROM m.target_month) IN (6, 7, 8)
                THEN 1.08
            WHEN EXTRACT(MONTH FROM m.target_month) IN (1, 2)
                THEN 0.92
            ELSE 1.00
        END::NUMERIC AS seasonal_factor,

        (
            EXTRACT(YEAR FROM m.target_month)::INTEGER - 2023
        ) AS years_since_2023

    FROM core.branches AS b
    CROSS JOIN months AS m
    WHERE b.is_active = TRUE
)
INSERT INTO core.branch_targets (
    branch_id,
    target_month,
    premium_target,
    policy_target,
    renewal_rate_target
)
SELECT
    branch_id,
    target_month,

    ROUND(
        (
            140000 + (branch_id * 2500)
        )::NUMERIC
        * (1 + years_since_2023 * 0.06)
        * seasonal_factor,
        2
    ) AS premium_target,

    GREATEST(
        50,
        ROUND(
            (
                60 + MOD(branch_id, 15)
            ) * seasonal_factor
        )::INTEGER
    ) AS policy_target,

    LEAST(
        92.00,
        (
            78.00
            + MOD(branch_id, 7) * 1.50
            + years_since_2023 * 0.50
        )
    ) AS renewal_rate_target

FROM target_calculations

ON CONFLICT (branch_id, target_month)
DO UPDATE SET
    premium_target = EXCLUDED.premium_target,
    policy_target = EXCLUDED.policy_target,
    renewal_rate_target = EXCLUDED.renewal_rate_target;

COMMIT;