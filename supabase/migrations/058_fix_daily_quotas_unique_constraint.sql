-- =====================================================
-- Migration 058: Fix daily_quotas Unique Constraint for NULL Handling
-- Purpose: Fix ON CONFLICT issues with NULL user_id values
-- Date: 2025-11-13
-- =====================================================

-- =====================================================
-- PROBLEM: UNIQUE(user_id, device_id, date) doesn't work with NULLs
-- =====================================================
-- PostgreSQL treats NULL as distinct from other NULLs in unique constraints.
-- This means multiple rows with (NULL, 'device123', '2025-01-13') can exist.
-- The ON CONFLICT clause in consume_quota fails because it can't match the constraint.

-- =====================================================
-- SOLUTION: Use expression-based unique index with COALESCE
-- =====================================================

-- Step 1: Drop old constraint (if it exists as a named constraint)
DO $$
BEGIN
    -- Check if constraint exists and drop it
    IF EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'daily_quotas_user_id_device_id_date_key'
    ) THEN
        ALTER TABLE daily_quotas DROP CONSTRAINT daily_quotas_user_id_device_id_date_key;
        RAISE NOTICE 'Dropped old unique constraint: daily_quotas_user_id_device_id_date_key';
    END IF;
END $$;

-- Step 2: Create expression-based unique index
-- This index treats NULL as empty string '', making it unique-comparable
CREATE UNIQUE INDEX IF NOT EXISTS idx_daily_quotas_unique_user_device_date
ON daily_quotas (
    COALESCE(user_id::text, ''),
    COALESCE(device_id, ''),
    date
);

-- =====================================================
-- VERIFICATION
-- =====================================================
DO $$
BEGIN
    -- Verify index exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE indexname = 'idx_daily_quotas_unique_user_device_date'
    ) THEN
        RAISE EXCEPTION 'Unique index not created';
    END IF;

    RAISE NOTICE 'SUCCESS: daily_quotas unique constraint fixed';
    RAISE NOTICE 'ON CONFLICT will now work correctly with NULL user_id values';
END $$;

-- =====================================================
-- COMMENTS
-- =====================================================
COMMENT ON INDEX idx_daily_quotas_unique_user_device_date IS
'Expression-based unique index that handles NULL user_id values correctly. Used by consume_quota ON CONFLICT clause.';
