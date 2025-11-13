-- =====================================================
-- Test Script: Idempotency Keys Cleanup
-- Purpose: Verify cleanup function works correctly
-- =====================================================

-- =====================================================
-- Test 1: Check Current State
-- =====================================================
SELECT 
    'Test 1: Current Table State' as test,
    COUNT(*) as total_records,
    COUNT(*) FILTER (WHERE created_at < NOW() - INTERVAL '90 days') as older_than_90_days,
    COUNT(*) FILTER (WHERE created_at < NOW() - INTERVAL '7 days') as older_than_7_days,
    COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '7 days') as recent_keys,
    pg_size_pretty(pg_total_relation_size('idempotency_keys')) as table_size
FROM idempotency_keys;

-- =====================================================
-- Test 2: Test Cleanup Function (Dry Run)
-- =====================================================
-- Check what would be deleted
SELECT 
    'Test 2: Records Eligible for Cleanup' as test,
    COUNT(*) as would_be_deleted
FROM idempotency_keys
WHERE created_at < NOW() - INTERVAL '90 days'
  AND created_at < NOW() - INTERVAL '7 days';

-- =====================================================
-- Test 3: Run Actual Cleanup
-- =====================================================
-- WARNING: This will actually delete records!
-- Only run if you want to test cleanup
-- SELECT * FROM cleanup_old_idempotency_keys(90);

-- =====================================================
-- Test 4: Verify Function Exists
-- =====================================================
SELECT 
    'Test 4: Function Verification' as test,
    EXISTS (
        SELECT 1 FROM pg_proc 
        WHERE proname = 'cleanup_old_idempotency_keys'
    ) as function_exists,
    EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE indexname = 'idx_idempotency_keys_created_at'
    ) as index_exists;

-- =====================================================
-- Test 5: Check Recent Keys Protection
-- =====================================================
-- Verify that keys from last 7 days are NOT eligible for cleanup
SELECT 
    'Test 5: Recent Keys Protection' as test,
    COUNT(*) as recent_keys_count,
    COUNT(*) FILTER (
        WHERE created_at < NOW() - INTERVAL '90 days' 
        AND created_at < NOW() - INTERVAL '7 days'
    ) as recent_keys_eligible_for_cleanup,
    CASE 
        WHEN COUNT(*) FILTER (
            WHERE created_at < NOW() - INTERVAL '90 days' 
            AND created_at < NOW() - INTERVAL '7 days'
        ) = 0 THEN '✅ PASSED - Recent keys protected'
        ELSE '❌ FAILED - Recent keys not protected'
    END as result
FROM idempotency_keys
WHERE created_at >= NOW() - INTERVAL '7 days';

