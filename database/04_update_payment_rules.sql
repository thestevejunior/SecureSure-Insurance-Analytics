-- Migration: permit unpaid payment records to have no payment date
-- and enforce consistency between payment status and amount.

BEGIN;

ALTER TABLE core.payments
    ALTER COLUMN payment_date DROP NOT NULL;

ALTER TABLE core.payments
    DROP CONSTRAINT IF EXISTS chk_payment_status_consistency;

ALTER TABLE core.payments
    ADD CONSTRAINT chk_payment_status_consistency
    CHECK (
        (
            payment_status = 'Paid'
            AND amount_paid = amount_due
            AND payment_date IS NOT NULL
        )
        OR
        (
            payment_status = 'Partial'
            AND amount_paid > 0
            AND amount_paid < amount_due
            AND payment_date IS NOT NULL
        )
        OR
        (
            payment_status IN ('Overdue', 'Pending', 'Failed')
            AND amount_paid = 0
            AND payment_date IS NULL
        )
    );

COMMIT;