-- =====================================================
-- Migration: 054_create_job_results_webhook.sql
-- Purpose: Webhook architecture - store completed job results
-- Date: 2025-11-13
-- =====================================================

-- =====================================================
-- TABLE: job_results (for webhook architecture)
-- =====================================================

CREATE TABLE IF NOT EXISTS public.job_results (
    -- Primary Key
    fal_job_id TEXT PRIMARY KEY,

    -- User Identification
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT,

    -- Job Status
    status TEXT NOT NULL,  -- pending | completed | failed

    -- Result Data
    image_url TEXT,        -- Signed URL to processed image in storage
    error TEXT,            -- Error message if failed

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ,

    -- Constraints
    CHECK (user_id IS NOT NULL OR device_id IS NOT NULL),
    CHECK (status IN ('pending', 'completed', 'failed'))
);

-- =====================================================
-- INDEXES
-- =====================================================

-- Primary lookup: Find result by fal job ID
CREATE INDEX idx_job_results_fal_job_id ON public.job_results(fal_job_id);

-- User lookup: Find all results for authenticated user
CREATE INDEX idx_job_results_user_id ON public.job_results(user_id) WHERE user_id IS NOT NULL;

-- Anonymous lookup: Find all results for device
CREATE INDEX idx_job_results_device_id ON public.job_results(device_id) WHERE device_id IS NOT NULL;

-- Status lookup: Find pending/completed/failed jobs
CREATE INDEX idx_job_results_status ON public.job_results(status);

-- Cleanup: Find old completed jobs
CREATE INDEX idx_job_results_completed_at ON public.job_results(completed_at) WHERE completed_at IS NOT NULL;

-- =====================================================
-- ROW-LEVEL SECURITY (RLS)
-- =====================================================

ALTER TABLE public.job_results ENABLE ROW LEVEL SECURITY;

-- Policy 1: Users can view their own results (authenticated)
CREATE POLICY "Users can view own job results"
    ON public.job_results
    FOR SELECT
    USING (auth.uid() = user_id);

-- Policy 2: Anonymous users can view results by device_id
CREATE POLICY "Anonymous users can view own job results"
    ON public.job_results
    FOR SELECT
    USING (device_id IS NOT NULL);

-- Policy 3: Service role has full access (for Edge Functions)
CREATE POLICY "Service role has full access to job results"
    ON public.job_results
    FOR ALL
    USING (auth.jwt()->>'role' = 'service_role');

-- =====================================================
-- CLEANUP FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION cleanup_job_results()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    deleted_count INTEGER := 0;
    temp_count INTEGER;
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

    -- Delete pending jobs older than 24 hours (stuck jobs)
    DELETE FROM public.job_results
    WHERE status = 'pending'
      AND created_at < now() - INTERVAL '24 hours';

    GET DIAGNOSTICS temp_count = ROW_COUNT;
    deleted_count := deleted_count + temp_count;

    RETURN deleted_count;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.cleanup_job_results() TO service_role;

-- =====================================================
-- VERIFICATION
-- =====================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'job_results') THEN
        RAISE NOTICE 'WARNING: job_results table not found';
    ELSE
        RAISE NOTICE 'SUCCESS: job_results table created successfully';
    END IF;
END $$;

-- =====================================================
-- COMMENTS
-- =====================================================

COMMENT ON TABLE public.job_results IS 'Stores results from fal.ai webhook callbacks';
COMMENT ON COLUMN public.job_results.fal_job_id IS 'fal.ai request_id from queue submission';
COMMENT ON COLUMN public.job_results.status IS 'Job status: pending | completed | failed';
COMMENT ON COLUMN public.job_results.image_url IS 'Signed URL to processed image in Supabase Storage';
COMMENT ON FUNCTION public.cleanup_job_results() IS 'Deletes job results older than 7 days (completed/failed) or 24 hours (pending)';
