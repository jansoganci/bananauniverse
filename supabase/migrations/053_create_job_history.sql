-- =====================================================
-- Migration: 053_create_job_history.sql
-- Purpose: Optional job tracking for async polling
-- Status: OPTIONAL - graceful degradation if missing
-- Date: 2025-11-13
-- =====================================================

-- =====================================================
-- TABLE: job_history
-- =====================================================

CREATE TABLE IF NOT EXISTS public.job_history (
    -- Primary Key
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- User Identification (one of these will be set)
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT,

    -- Job Identifiers
    fal_job_id TEXT NOT NULL UNIQUE,

    -- Job Status
    status TEXT NOT NULL DEFAULT 'queued',

    -- Job Data
    input_url TEXT,
    result_url TEXT,
    prompt TEXT,
    error TEXT,

    -- Queue Metadata
    queue_position INTEGER,

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ,

    -- Constraints
    CHECK (user_id IS NOT NULL OR device_id IS NOT NULL),
    CHECK (status IN ('queued', 'processing', 'completed', 'failed')),
    CHECK (completed_at IS NULL OR completed_at >= created_at)
);

-- =====================================================
-- INDEXES
-- =====================================================

-- Primary lookup: Find jobs by fal.ai request_id
CREATE INDEX idx_job_history_fal_job_id ON public.job_history(fal_job_id);

-- User lookup: Find all jobs for authenticated user
CREATE INDEX idx_job_history_user_id ON public.job_history(user_id) WHERE user_id IS NOT NULL;

-- Anonymous lookup: Find all jobs for device
CREATE INDEX idx_job_history_device_id ON public.job_history(device_id) WHERE device_id IS NOT NULL;

-- Status monitoring: Find all jobs in specific state
CREATE INDEX idx_job_history_status ON public.job_history(status);

-- Cleanup: Find old jobs efficiently
CREATE INDEX idx_job_history_created_at ON public.job_history(created_at);

-- Stuck job detection: Find jobs that never completed
CREATE INDEX idx_job_history_incomplete ON public.job_history(status, updated_at)
    WHERE status IN ('queued', 'processing');

-- =====================================================
-- ROW-LEVEL SECURITY (RLS)
-- =====================================================

ALTER TABLE public.job_history ENABLE ROW LEVEL SECURITY;

-- Policy 1: Users can view their own jobs (authenticated)
CREATE POLICY "Users can view own jobs"
    ON public.job_history
    FOR SELECT
    USING (auth.uid() = user_id);

-- Policy 2: Users can insert their own jobs (authenticated)
CREATE POLICY "Users can insert own jobs"
    ON public.job_history
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Policy 3: Users can update their own jobs (authenticated)
CREATE POLICY "Users can update own jobs"
    ON public.job_history
    FOR UPDATE
    USING (auth.uid() = user_id);

-- Policy 4: Anonymous users can view jobs by device_id
CREATE POLICY "Anonymous users can view own jobs"
    ON public.job_history
    FOR SELECT
    USING (device_id IS NOT NULL);

-- Policy 5: Anonymous users can insert jobs by device_id
CREATE POLICY "Anonymous users can insert own jobs"
    ON public.job_history
    FOR INSERT
    WITH CHECK (device_id IS NOT NULL);

-- Policy 6: Service role has full access (for Edge Functions)
CREATE POLICY "Service role has full access"
    ON public.job_history
    FOR ALL
    USING (auth.jwt()->>'role' = 'service_role');

-- =====================================================
-- CLEANUP FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION cleanup_job_history()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    deleted_count INTEGER := 0;
    stuck_count INTEGER := 0;
BEGIN
    -- Delete completed/failed jobs older than 30 days
    DELETE FROM public.job_history
    WHERE status IN ('completed', 'failed')
      AND completed_at < now() - INTERVAL '30 days';

    GET DIAGNOSTICS deleted_count = ROW_COUNT;

    -- Delete stuck jobs (processing > 24 hours)
    DELETE FROM public.job_history
    WHERE status IN ('queued', 'processing')
      AND updated_at < now() - INTERVAL '24 hours';

    GET DIAGNOSTICS stuck_count = ROW_COUNT;

    RETURN deleted_count + stuck_count;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.cleanup_job_history() TO service_role;

-- =====================================================
-- VERIFICATION
-- =====================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'job_history') THEN
        RAISE NOTICE 'WARNING: job_history table not found - Edge Functions will use graceful degradation';
    ELSE
        RAISE NOTICE 'SUCCESS: job_history table created successfully';
    END IF;
END $$;
