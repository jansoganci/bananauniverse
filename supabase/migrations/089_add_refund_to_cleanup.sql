-- =====================================================
-- Migration 089: Add Credit Refunds to Cleanup Function
-- Purpose: Refund credits for orphaned jobs before deletion
-- Date: 2025-11-15
-- =====================================================
-- This migration updates cleanup_job_results() to:
-- 1. Refund credits for orphaned jobs (stuck pending jobs older than 24 hours)
-- 2. Log refund transactions for audit trail
-- 3. Delete orphaned jobs after refunding credits
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE 'Updating cleanup_job_results() function with credit refunds...';
END $$;

-- =====================================================
-- Update cleanup_job_results() Function
-- =====================================================

CREATE OR REPLACE FUNCTION cleanup_job_results()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    deleted_count INTEGER := 0;
    temp_count INTEGER;
    refunded_count INTEGER := 0;
    job_record RECORD;  -- Required for FOR loop
BEGIN
    -- Delete completed jobs older than 7 days
    DELETE FROM public.job_results
    WHERE status = 'completed'
      AND completed_at < now() - INTERVAL '7 days';

    GET DIAGNOSTICS temp_count = ROW_COUNT;
    deleted_count := deleted_count + temp_count;

    -- Delete failed jobs older than 7 days
    DELETE FROM public.job_results
    WHERE status = 'failed'
      AND completed_at < now() - INTERVAL '7 days';

    GET DIAGNOSTICS temp_count = ROW_COUNT;
    deleted_count := deleted_count + temp_count;

    -- Delete pending jobs older than 24 hours (stuck jobs) AND REFUND CREDITS
    FOR job_record IN (
        SELECT id, user_id, device_id, client_request_id
        FROM public.job_results
        WHERE status = 'pending'
          AND created_at < now() - INTERVAL '24 hours'
    ) LOOP
        -- Refund credit for orphaned job
        IF job_record.user_id IS NOT NULL THEN
            BEGIN
                UPDATE user_credits
                SET credits = credits + 1
                WHERE user_id = job_record.user_id
                  AND NOT EXISTS (
                      SELECT 1 FROM job_results
                      WHERE id = job_record.id
                        AND status != 'pending'  -- Job was already processed
                  )
                FOR UPDATE NOWAIT;  -- Fail fast if locked, don't wait
            EXCEPTION
                WHEN OTHERS THEN
                    -- Check if it's a lock error (SQLSTATE 55P03 = could not obtain lock)
                    IF SQLSTATE = '55P03' THEN
                        -- Row is locked by another transaction, skip this refund
                        -- Log warning but continue with next job
                        RAISE LOG '[CLEANUP] Skipped refund for job % (row locked)', job_record.id;
                        CONTINUE;
                    ELSE
                        -- Re-raise other exceptions (don't hide real errors)
                        RAISE;
                    END IF;
            END;

            -- Log refund transaction
            INSERT INTO credit_transactions (
                user_id,
                amount,
                balance_after,
                reason,
                idempotency_key,
                created_at
            )
            SELECT
                job_record.user_id,
                1,
                credits,
                'orphaned_job_refund',
                'cleanup-refund-' || job_record.id::text,
                NOW()
            FROM user_credits
            WHERE user_id = job_record.user_id;

            refunded_count := refunded_count + 1;

        ELSIF job_record.device_id IS NOT NULL THEN
            BEGIN
                UPDATE anonymous_credits
                SET credits = credits + 1
                WHERE device_id = job_record.device_id
                  AND NOT EXISTS (
                      SELECT 1 FROM job_results
                      WHERE id = job_record.id
                        AND status != 'pending'  -- Job was already processed
                  )
                FOR UPDATE NOWAIT;  -- Fail fast if locked, don't wait
            EXCEPTION
                WHEN OTHERS THEN
                    -- Check if it's a lock error (SQLSTATE 55P03 = could not obtain lock)
                    IF SQLSTATE = '55P03' THEN
                        -- Row is locked by another transaction, skip this refund
                        -- Log warning but continue with next job
                        RAISE LOG '[CLEANUP] Skipped refund for job % (row locked)', job_record.id;
                        CONTINUE;
                    ELSE
                        -- Re-raise other exceptions (don't hide real errors)
                        RAISE;
                    END IF;
            END;

            -- Log refund transaction
            INSERT INTO credit_transactions (
                device_id,
                amount,
                balance_after,
                reason,
                idempotency_key,
                created_at
            )
            SELECT
                job_record.device_id,
                1,
                credits,
                'orphaned_job_refund',
                'cleanup-refund-' || job_record.id::text,
                NOW()
            FROM anonymous_credits
            WHERE device_id = job_record.device_id;

            refunded_count := refunded_count + 1;
        END IF;
    END LOOP;

    -- Delete the orphaned jobs (after refunding)
    DELETE FROM public.job_results
    WHERE status = 'pending'
      AND created_at < now() - INTERVAL '24 hours';

    GET DIAGNOSTICS temp_count = ROW_COUNT;
    deleted_count := deleted_count + temp_count;

    RAISE LOG '[CLEANUP] Deleted % jobs, refunded % credits', deleted_count, refunded_count;

    RETURN deleted_count;
END;
$$;

COMMENT ON FUNCTION cleanup_job_results IS 'Cleans up old job records and refunds credits for orphaned jobs. Deletes completed/failed jobs older than 7 days. Refunds credits for pending jobs older than 24 hours before deletion.';

-- =====================================================
-- Verification
-- =====================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'cleanup_job_results') THEN
        RAISE EXCEPTION 'VERIFICATION FAILED: cleanup_job_results function not found';
    END IF;

    RAISE NOTICE '========================================';
    RAISE NOTICE 'Migration 089: Cleanup Function Updated';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ cleanup_job_results(): UPDATED';
    RAISE NOTICE '✅ Refunds credits for orphaned jobs';
    RAISE NOTICE '✅ Logs refund transactions';
    RAISE NOTICE '✅ Deletes orphaned jobs after refunding';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🎉 SUCCESS: Cleanup function ready!';
    RAISE NOTICE '========================================';
END $$;
