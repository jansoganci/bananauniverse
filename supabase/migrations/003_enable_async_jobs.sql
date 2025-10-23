-- =====================================================
-- Migration: Enable Async Job Processing
-- =====================================================
--
-- This migration enables async job processing with:
-- 1. Anonymous user support via device_id
-- 2. Concurrent job limits (max 3 per user/device)
-- 3. Enhanced RLS policies
-- 4. Performance indexes
--
-- IDEMPOTENT - Safe to run multiple times
--
-- =====================================================

-- =====================================================
-- 1. ADD DEVICE_ID SUPPORT FOR ANONYMOUS USERS
-- =====================================================

-- Add device_id column to jobs table (if not exists)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'jobs' AND column_name = 'device_id'
  ) THEN
    ALTER TABLE jobs ADD COLUMN device_id TEXT;
    
    -- Add constraint: either user_id OR device_id must be present
    ALTER TABLE jobs ADD CONSTRAINT jobs_user_or_device_check 
      CHECK (
        (user_id IS NOT NULL AND device_id IS NULL) OR 
        (user_id IS NULL AND device_id IS NOT NULL)
      );
    
    -- Add comment for documentation
    COMMENT ON COLUMN jobs.device_id IS 'Device identifier for anonymous users. Either user_id or device_id must be set, not both.';
  END IF;
END $$;

-- Make user_id nullable (was NOT NULL before)
ALTER TABLE jobs ALTER COLUMN user_id DROP NOT NULL;

-- =====================================================
-- 2. UPDATE RLS POLICIES FOR ANONYMOUS SUPPORT
-- =====================================================

-- Drop old policies
DROP POLICY IF EXISTS "Users can view own jobs" ON jobs;
DROP POLICY IF EXISTS "Users can create own jobs" ON jobs;
DROP POLICY IF EXISTS "Users can update own jobs" ON jobs;

-- New policy: Users can view their own jobs (authenticated or anonymous)
CREATE POLICY "Users can view own jobs"
  ON jobs FOR SELECT
  USING (
    -- Authenticated users can see their jobs
    (auth.uid() = user_id) OR
    -- Service role can see all (for Edge Functions)
    (auth.jwt()->>'role' = 'service_role')
  );

-- New policy: Users can create jobs (authenticated or anonymous via service role)
CREATE POLICY "Users can create own jobs"
  ON jobs FOR INSERT
  WITH CHECK (
    -- Authenticated users creating their own jobs
    (auth.uid() = user_id AND device_id IS NULL) OR
    -- Service role can create jobs for anyone (used by Edge Functions for anonymous)
    (auth.jwt()->>'role' = 'service_role')
  );

-- New policy: Service role can update jobs (for status changes)
CREATE POLICY "Service role can update jobs"
  ON jobs FOR UPDATE
  USING (auth.jwt()->>'role' = 'service_role');

-- =====================================================
-- 3. ADD INDEXES FOR ANONYMOUS USERS & POLLING
-- =====================================================

-- Index for anonymous user job queries
CREATE INDEX IF NOT EXISTS idx_jobs_device_id ON jobs(device_id) 
  WHERE device_id IS NOT NULL;

-- Composite index for efficient status polling
CREATE INDEX IF NOT EXISTS idx_jobs_user_status ON jobs(user_id, status) 
  WHERE user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_jobs_device_status ON jobs(device_id, status) 
  WHERE device_id IS NOT NULL;

-- Index for pending/processing jobs (for concurrent limit check)
CREATE INDEX IF NOT EXISTS idx_jobs_active_status ON jobs(status, created_at) 
  WHERE status IN ('pending', 'processing');

-- =====================================================
-- 4. CONCURRENT JOB LIMIT FUNCTION
-- =====================================================

-- Function to count active jobs (pending or processing) for a user/device
CREATE OR REPLACE FUNCTION public.get_active_job_count(
  p_user_id UUID DEFAULT NULL,
  p_device_id TEXT DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
  job_count INTEGER;
BEGIN
  -- Validate input: at least one must be provided
  IF p_user_id IS NULL AND p_device_id IS NULL THEN
    RAISE EXCEPTION 'Either user_id or device_id must be provided';
  END IF;
  
  -- Count active jobs (pending or processing)
  SELECT COUNT(*)
  INTO job_count
  FROM jobs
  WHERE 
    status IN ('pending', 'processing')
    AND (
      (p_user_id IS NOT NULL AND user_id = p_user_id) OR
      (p_device_id IS NOT NULL AND device_id = p_device_id)
    );
  
  RETURN job_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.get_active_job_count(UUID, TEXT) TO authenticated, anon, service_role;

-- Add comment
COMMENT ON FUNCTION public.get_active_job_count IS 
  'Returns count of active (pending or processing) jobs for a user or device. Used to enforce concurrent job limits.';

-- =====================================================
-- 5. HELPER FUNCTION: CHECK JOB LIMIT BEFORE INSERT
-- =====================================================

-- Function to validate concurrent job limit (max 3)
CREATE OR REPLACE FUNCTION public.check_job_limit()
RETURNS TRIGGER AS $$
DECLARE
  active_count INTEGER;
  max_concurrent_jobs INTEGER := 3;
BEGIN
  -- Get active job count
  active_count := public.get_active_job_count(NEW.user_id, NEW.device_id);
  
  -- Check limit
  IF active_count >= max_concurrent_jobs THEN
    RAISE EXCEPTION 'Concurrent job limit exceeded. Maximum % active jobs allowed. Current: %', 
      max_concurrent_jobs, active_count
      USING HINT = 'Wait for existing jobs to complete before submitting new ones';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to check limit on insert
DROP TRIGGER IF EXISTS check_job_limit_trigger ON jobs;
CREATE TRIGGER check_job_limit_trigger
  BEFORE INSERT ON jobs
  FOR EACH ROW
  EXECUTE FUNCTION public.check_job_limit();

-- Add comment
COMMENT ON FUNCTION public.check_job_limit IS 
  'Trigger function that enforces max 3 concurrent active jobs per user/device';

-- =====================================================
-- 6. UPDATE JOB_STATS VIEW FOR ANONYMOUS SUPPORT
-- =====================================================

-- Drop old view
DROP VIEW IF EXISTS job_stats;

-- Recreate with device_id support
CREATE OR REPLACE VIEW job_stats AS
SELECT 
  COALESCE(user_id::TEXT, 'device:' || device_id) as identifier,
  user_id,
  device_id,
  COUNT(*) as total_jobs,
  COUNT(*) FILTER (WHERE status = 'completed') as completed_jobs,
  COUNT(*) FILTER (WHERE status = 'failed') as failed_jobs,
  COUNT(*) FILTER (WHERE status = 'processing') as processing_jobs,
  COUNT(*) FILTER (WHERE status = 'pending') as pending_jobs,
  MAX(created_at) as last_job_at
FROM jobs
GROUP BY user_id, device_id;

-- Grant access
GRANT SELECT ON job_stats TO authenticated, service_role;

-- Add comment
COMMENT ON VIEW job_stats IS 
  'Job statistics aggregated by user_id or device_id. Supports both authenticated and anonymous users.';

-- =====================================================
-- 7. CLEANUP FUNCTION FOR OLD JOBS (OPTIONAL)
-- =====================================================

-- Function to clean up old completed/failed jobs (older than 30 days)
CREATE OR REPLACE FUNCTION public.cleanup_old_jobs()
RETURNS INTEGER AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM jobs
  WHERE 
    status IN ('completed', 'failed')
    AND created_at < NOW() - INTERVAL '30 days';
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.cleanup_old_jobs() TO service_role;

-- Add comment
COMMENT ON FUNCTION public.cleanup_old_jobs IS 
  'Deletes completed/failed jobs older than 30 days. Returns count of deleted rows. Run periodically via cron.';

-- =====================================================
-- 8. ADD METADATA COLUMNS (OPTIONAL - FOR DEBUGGING)
-- =====================================================

-- Add columns for better debugging and analytics
DO $$ 
BEGIN
  -- Add processing_time_seconds (calculated on completion)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'jobs' AND column_name = 'processing_time_seconds'
  ) THEN
    ALTER TABLE jobs ADD COLUMN processing_time_seconds INTEGER;
    COMMENT ON COLUMN jobs.processing_time_seconds IS 'Total processing time in seconds (calculated on completion)';
  END IF;
  
  -- Add fal_status (to track Fal.AI specific status)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'jobs' AND column_name = 'fal_status'
  ) THEN
    ALTER TABLE jobs ADD COLUMN fal_status TEXT;
    COMMENT ON COLUMN jobs.fal_status IS 'Status from Fal.AI API (for debugging async jobs)';
  END IF;
END $$;

-- =====================================================
-- 9. FUNCTION TO AUTO-CALCULATE PROCESSING TIME
-- =====================================================

-- Trigger function to calculate processing time on completion
CREATE OR REPLACE FUNCTION public.calculate_processing_time()
RETURNS TRIGGER AS $$
BEGIN
  -- Only calculate when job completes or fails
  IF NEW.status IN ('completed', 'failed') AND OLD.status != NEW.status THEN
    NEW.processing_time_seconds := EXTRACT(EPOCH FROM (NEW.updated_at - NEW.created_at))::INTEGER;
    
    -- Set completed_at if not already set
    IF NEW.status = 'completed' AND NEW.completed_at IS NULL THEN
      NEW.completed_at := NEW.updated_at;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS calculate_processing_time_trigger ON jobs;
CREATE TRIGGER calculate_processing_time_trigger
  BEFORE UPDATE ON jobs
  FOR EACH ROW
  EXECUTE FUNCTION public.calculate_processing_time();

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================

-- Log migration success
DO $$
BEGIN
  RAISE NOTICE '✅ Migration 003_enable_async_jobs completed successfully';
  RAISE NOTICE '   - Anonymous user support enabled (device_id)';
  RAISE NOTICE '   - Concurrent job limit set to 3';
  RAISE NOTICE '   - RLS policies updated for service role access';
  RAISE NOTICE '   - Performance indexes created';
  RAISE NOTICE '   - Helper functions created';
END $$;

