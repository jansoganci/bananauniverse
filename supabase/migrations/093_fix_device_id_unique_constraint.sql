-- =====================================================
-- Migration 093: Fix device_id Unique Constraint
-- Purpose: Add proper unique constraint for ON CONFLICT clause
-- Date: 2025-11-20
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE 'Fixing device_id unique constraint...';
END $$;

-- =====================================================
-- STEP 1: Drop the Partial Index (if exists)
-- =====================================================

DROP INDEX IF EXISTS idx_user_credits_device_id_unique;

DO $$
BEGIN
    RAISE NOTICE '✅ Step 1: Dropped partial unique index';
END $$;

-- =====================================================
-- STEP 2: Add Regular Unique Constraint on device_id
-- =====================================================
-- This allows ON CONFLICT (device_id) to work properly

ALTER TABLE user_credits
DROP CONSTRAINT IF EXISTS user_credits_device_id_key;

ALTER TABLE user_credits
ADD CONSTRAINT user_credits_device_id_key UNIQUE (device_id);

DO $$
BEGIN
    RAISE NOTICE '✅ Step 2: Added unique constraint on device_id';
END $$;

-- =====================================================
-- STEP 3: Ensure user_id Unique Constraint Exists
-- =====================================================

ALTER TABLE user_credits
DROP CONSTRAINT IF EXISTS user_credits_user_id_key;

ALTER TABLE user_credits
ADD CONSTRAINT user_credits_user_id_key UNIQUE (user_id);

DO $$
BEGIN
    RAISE NOTICE '✅ Step 3: Ensured unique constraint on user_id';
END $$;

-- =====================================================
-- VERIFICATION
-- =====================================================

DO $$
DECLARE
    v_device_constraint BOOLEAN;
    v_user_constraint BOOLEAN;
BEGIN
    -- Check device_id constraint
    SELECT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'user_credits'
        AND constraint_name = 'user_credits_device_id_key'
    ) INTO v_device_constraint;

    -- Check user_id constraint
    SELECT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'user_credits'
        AND constraint_name = 'user_credits_user_id_key'
    ) INTO v_user_constraint;

    IF NOT v_device_constraint THEN
        RAISE EXCEPTION 'VERIFICATION FAILED: device_id unique constraint not added';
    END IF;

    IF NOT v_user_constraint THEN
        RAISE EXCEPTION 'VERIFICATION FAILED: user_id unique constraint not found';
    END IF;

    RAISE NOTICE '========================================';
    RAISE NOTICE 'Migration 093: Fix device_id Constraint';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ device_id unique constraint added';
    RAISE NOTICE '✅ user_id unique constraint verified';
    RAISE NOTICE '✅ ON CONFLICT clauses will now work';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🎉 SUCCESS: Migration complete!';
    RAISE NOTICE '========================================';
END $$;
