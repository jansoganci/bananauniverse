-- =====================================================
-- Migration 056: Fix job_results RLS Policy
-- Purpose: Fix broken anonymous user RLS policy
-- Date: 2025-11-13
-- =====================================================

-- =====================================================
-- PROBLEM: Old policy allows ANY device to read ANY job
-- SOLUTION: Check device_id against session variable
-- =====================================================

-- Drop the broken policy
DROP POLICY IF EXISTS "Anonymous users can view own job results" ON public.job_results;

-- Create correct policy with session variable check
CREATE POLICY "Anonymous users can view own job results"
    ON public.job_results
    FOR SELECT
    USING (
        device_id IS NOT NULL
        AND device_id = current_setting('request.device_id', true)
    );

-- =====================================================
-- VERIFICATION
-- =====================================================
DO $$
BEGIN
    -- Verify policy exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'job_results'
        AND policyname = 'Anonymous users can view own job results'
    ) THEN
        RAISE EXCEPTION 'RLS policy not created';
    END IF;

    RAISE NOTICE 'SUCCESS: job_results RLS policy fixed';
    RAISE NOTICE 'Anonymous users can now ONLY see jobs matching their device_id session variable';
END $$;

-- =====================================================
-- COMMENTS
-- =====================================================
COMMENT ON POLICY "Anonymous users can view own job results" ON public.job_results IS
'Allows anonymous users to view ONLY their own job results by matching device_id with current_setting(request.device_id). Fixed in migration 056.';
