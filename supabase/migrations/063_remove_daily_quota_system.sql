-- =====================================================
-- Migration 063: Remove Daily Quota System
-- Purpose: Delete all daily quota infrastructure
-- Date: 2025-11-13
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE 'Starting removal of daily quota system...';
END $$;

-- =====================================================
-- STEP 1: Drop Quota Functions
-- =====================================================

-- Drop all quota functions with CASCADE to remove dependencies
-- Use a DO block to drop by name regardless of signature
DO $$
DECLARE
    func_record RECORD;
    v_count INTEGER;
BEGIN
    -- Count functions before dropping
    SELECT COUNT(*) INTO v_count FROM pg_proc WHERE proname IN ('consume_quota', 'get_quota', 'add_credits');
    RAISE NOTICE 'Found % quota functions before dropping', v_count;

    -- Drop all consume_quota functions
    FOR func_record IN
        SELECT oid::regprocedure, proname
        FROM pg_proc
        WHERE proname = 'consume_quota'
    LOOP
        RAISE NOTICE 'Attempting to drop: %', func_record.oid::regprocedure;
        EXECUTE 'DROP FUNCTION IF EXISTS ' || func_record.oid::regprocedure || ' CASCADE';
        RAISE NOTICE 'Successfully dropped: %', func_record.oid::regprocedure;
    END LOOP;

    -- Drop all get_quota functions
    FOR func_record IN
        SELECT oid::regprocedure, proname
        FROM pg_proc
        WHERE proname = 'get_quota'
    LOOP
        RAISE NOTICE 'Attempting to drop: %', func_record.oid::regprocedure;
        EXECUTE 'DROP FUNCTION IF EXISTS ' || func_record.oid::regprocedure || ' CASCADE';
        RAISE NOTICE 'Successfully dropped: %', func_record.oid::regprocedure;
    END LOOP;

    -- Drop all add_credits functions with specific quota-related signatures
    -- Note: We'll recreate add_credits in migration 064 with new signature
    FOR func_record IN
        SELECT oid::regprocedure, proname, pronargs
        FROM pg_proc
        WHERE proname = 'add_credits'
        AND pronargs = 4  -- Only drop 4-parameter version (user_id, device_id, amount, idempotency_key)
    LOOP
        RAISE NOTICE 'Attempting to drop add_credits with % args: %', func_record.pronargs, func_record.oid::regprocedure;
        EXECUTE 'DROP FUNCTION IF EXISTS ' || func_record.oid::regprocedure || ' CASCADE';
        RAISE NOTICE 'Successfully dropped: %', func_record.oid::regprocedure;
    END LOOP;

    -- Count functions after dropping
    SELECT COUNT(*) INTO v_count FROM pg_proc WHERE proname IN ('consume_quota', 'get_quota');
    RAISE NOTICE 'Found % quota functions after dropping (should be 0)', v_count;
END $$;

DO $$
BEGIN
    RAISE NOTICE 'Dropped quota functions';
END $$;

-- =====================================================
-- STEP 2: Drop Daily Quotas Table
-- =====================================================

-- Drop all policies first
DROP POLICY IF EXISTS "users_select_own_quota" ON daily_quotas;
DROP POLICY IF EXISTS "anon_select_device_quota" ON daily_quotas;
DROP POLICY IF EXISTS "service_role_all_quotas" ON daily_quotas;
DROP POLICY IF EXISTS "Users can view their own quota" ON daily_quotas;
DROP POLICY IF EXISTS "Anonymous users can view own quota" ON daily_quotas;

-- Drop triggers
DROP TRIGGER IF EXISTS trigger_update_daily_quotas_updated_at ON daily_quotas;

-- Drop the table (CASCADE will drop dependent objects)
DROP TABLE IF EXISTS daily_quotas CASCADE;

DO $$
BEGIN
    RAISE NOTICE 'Dropped daily_quotas table';
END $$;

-- =====================================================
-- STEP 3: Drop Quota-Related Helper Functions
-- =====================================================

-- Drop updated_at trigger function if only used by daily_quotas
DROP FUNCTION IF EXISTS update_daily_quotas_updated_at();

DO $$
BEGIN
    RAISE NOTICE 'Dropped quota helper functions';
END $$;

-- =====================================================
-- STEP 4: Clean Up Idempotency Keys Table (Optional)
-- =====================================================

-- Delete old quota-related idempotency keys (older than 30 days)
-- This is optional - idempotency keys can accumulate
DELETE FROM idempotency_keys
WHERE created_at < NOW() - INTERVAL '30 days';

DO $$
BEGIN
    RAISE NOTICE 'Cleaned up old idempotency keys';
END $$;

-- =====================================================
-- STEP 5: Drop Any Quota-Related Views
-- =====================================================

-- Drop quota consumption log view if it exists
DROP VIEW IF EXISTS quota_consumption_summary;
DROP VIEW IF EXISTS daily_quota_stats;

DO $$
BEGIN
    RAISE NOTICE 'Dropped quota-related views';
END $$;

-- =====================================================
-- STEP 6: Verification
-- =====================================================

DO $$
DECLARE
    v_table_exists BOOLEAN;
    v_function_count INTEGER;
BEGIN
    -- Check if daily_quotas table still exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name = 'daily_quotas'
    ) INTO v_table_exists;

    IF v_table_exists THEN
        RAISE EXCEPTION 'ERROR: daily_quotas table still exists!';
    END IF;

    -- Check if old quota functions still exist (not add_credits, as that will be recreated)
    SELECT COUNT(*) INTO v_function_count
    FROM pg_proc
    WHERE proname IN ('consume_quota', 'get_quota');

    IF v_function_count > 0 THEN
        RAISE EXCEPTION 'ERROR: Old quota functions still exist! Count: %', v_function_count;
    END IF;

    -- Note: add_credits will be recreated in migration 064 with new signature

    RAISE NOTICE '========================================';
    RAISE NOTICE 'Daily Quota System Removal Complete';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'daily_quotas table: DELETED';
    RAISE NOTICE 'consume_quota(): DELETED';
    RAISE NOTICE 'get_quota(): DELETED';
    RAISE NOTICE 'Old add_credits() (quota version): DELETED';
    RAISE NOTICE 'Quota-related policies: DELETED';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ SUCCESS: Daily quota system fully removed!';
END $$;

-- =====================================================
-- Migration Complete
-- =====================================================
-- ✅ All quota functions deleted
-- ✅ daily_quotas table deleted
-- ✅ Quota RLS policies deleted
-- ✅ Old idempotency keys cleaned up
-- ✅ Quota views deleted
--
-- Next: Migration 064 - Create new credit functions
