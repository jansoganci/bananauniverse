-- =====================================================
-- Migration 066: Add Idempotency Keys Cleanup
-- Purpose: Prevent unbounded growth of idempotency_keys table
-- Date: 2025-01-27
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE 'Adding idempotency_keys cleanup system...';
END $$;

-- =====================================================
-- STEP 1: Create Cleanup Function for Idempotency Keys
-- =====================================================

CREATE OR REPLACE FUNCTION cleanup_old_idempotency_keys(
    p_retention_days INTEGER DEFAULT 90
)
RETURNS TABLE(deleted_count INTEGER, errors TEXT[]) AS $$
DECLARE
    v_deleted_count INTEGER := 0;
    v_error_count INTEGER := 0;
    v_error_messages TEXT[] := '{}';
    v_cutoff_date TIMESTAMPTZ;
    v_batch_size INTEGER := 1000;
    v_batch_deleted INTEGER;
    v_total_batches INTEGER := 0;
BEGIN
    -- Validate retention period
    IF p_retention_days < 1 OR p_retention_days > 365 THEN
        RAISE EXCEPTION 'Retention period must be between 1 and 365 days';
    END IF;

    -- Calculate cutoff date
    v_cutoff_date := NOW() - (p_retention_days || ' days')::INTERVAL;

    RAISE LOG '[CLEANUP] Starting idempotency_keys cleanup (retention: % days, cutoff: %)', 
        p_retention_days, v_cutoff_date;

    -- Delete in batches to avoid long-running transactions
    -- Only delete keys older than retention AND older than 7 days (protect recent activity)
    LOOP
        -- Delete one batch
        WITH keys_to_delete AS (
            SELECT id FROM idempotency_keys
            WHERE created_at < v_cutoff_date
              AND created_at < NOW() - INTERVAL '7 days'  -- Protect recent keys
            LIMIT v_batch_size
        )
        DELETE FROM idempotency_keys
        WHERE id IN (SELECT id FROM keys_to_delete);

        GET DIAGNOSTICS v_batch_deleted = ROW_COUNT;
        v_deleted_count := v_deleted_count + v_batch_deleted;
        v_total_batches := v_total_batches + 1;

        RAISE LOG '[CLEANUP] Batch %: Deleted % idempotency keys', v_total_batches, v_batch_deleted;

        -- Exit loop if no more rows to delete
        EXIT WHEN v_batch_deleted = 0;

        -- Small delay between batches to avoid locking issues
        PERFORM pg_sleep(0.1);
    END LOOP;

    RAISE LOG '[CLEANUP] Idempotency keys cleanup complete: % records deleted in % batches', 
        v_deleted_count, v_total_batches;

    RETURN QUERY SELECT v_deleted_count, v_error_messages;

EXCEPTION
    WHEN OTHERS THEN
        RAISE LOG '[CLEANUP] ERROR cleaning idempotency_keys: %', SQLERRM;
        v_error_messages := ARRAY[SQLERRM];
        RETURN QUERY SELECT 0, v_error_messages;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION cleanup_old_idempotency_keys(INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION cleanup_old_idempotency_keys(INTEGER) TO authenticated;

COMMENT ON FUNCTION cleanup_old_idempotency_keys(INTEGER) IS
'Deletes idempotency_keys older than retention period (default 90 days). Deletes in batches to avoid long locks. Preserves recent keys (last 7 days) for active users.';

-- =====================================================
-- STEP 2: Add Index for Efficient Cleanup Queries
-- =====================================================

-- Index on created_at for fast cleanup queries
CREATE INDEX IF NOT EXISTS idx_idempotency_keys_created_at 
ON idempotency_keys(created_at);

-- =====================================================
-- STEP 3: Verification
-- =====================================================

DO $$
DECLARE
    v_function_exists BOOLEAN;
    v_index_exists BOOLEAN;
    v_table_size BIGINT;
    v_record_count BIGINT;
BEGIN
    -- Check if function exists
    SELECT EXISTS (
        SELECT 1 FROM pg_proc 
        WHERE proname = 'cleanup_old_idempotency_keys'
    ) INTO v_function_exists;

    -- Check if index exists
    SELECT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE indexname = 'idx_idempotency_keys_created_at'
    ) INTO v_index_exists;

    -- Get current table stats
    SELECT pg_total_relation_size('idempotency_keys') INTO v_table_size;
    SELECT COUNT(*) INTO v_record_count FROM idempotency_keys;

    IF NOT v_function_exists THEN
        RAISE EXCEPTION 'cleanup_old_idempotency_keys function not created!';
    END IF;

    IF NOT v_index_exists THEN
        RAISE EXCEPTION 'idx_idempotency_keys_created_at index not created!';
    END IF;

    RAISE NOTICE '========================================';
    RAISE NOTICE 'Idempotency Keys Cleanup System';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'cleanup_old_idempotency_keys(): ✅ CREATED';
    RAISE NOTICE 'idx_idempotency_keys_created_at: ✅ CREATED';
    RAISE NOTICE 'Current table size: %', pg_size_pretty(v_table_size);
    RAISE NOTICE 'Current record count: %', v_record_count;
    RAISE NOTICE 'Default retention: 90 days';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ SUCCESS: Idempotency cleanup system ready!';
END $$;

-- =====================================================
-- Migration Complete
-- =====================================================
-- ✅ cleanup_old_idempotency_keys() function created
-- ✅ Index on created_at for efficient queries
-- ✅ Batch deletion to avoid long locks
-- ✅ Preserves recent keys (last 7 days) for active users
-- ✅ Default retention: 90 days
-- ✅ Safe to call from cleanup-db Edge Function

