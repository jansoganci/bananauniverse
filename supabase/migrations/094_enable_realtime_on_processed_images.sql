-- Migration: Enable Realtime on job_results table
-- Purpose: Allow frontend to subscribe to job status updates via Supabase Realtime
-- Date: 2025-11-21

-- ============================================================================
-- 1. Enable Realtime publication on job_results table
-- ============================================================================

-- Drop existing publication if exists (for idempotency)
DROP PUBLICATION IF EXISTS supabase_realtime;

-- Create publication for Realtime (includes job_results)
CREATE PUBLICATION supabase_realtime FOR TABLE job_results;

-- ============================================================================
-- 2. Add index on fal_job_id for faster Realtime queries
-- ============================================================================

-- Index already exists from migration 054, but ensure it's there
CREATE INDEX IF NOT EXISTS idx_job_results_fal_job_id
ON job_results(fal_job_id);

-- Add index on status + created_at for filtering pending jobs
CREATE INDEX IF NOT EXISTS idx_job_results_status_created
ON job_results(status, created_at DESC);

-- ============================================================================
-- 3. Add updated_at column for better Realtime tracking
-- ============================================================================

-- Add updated_at column if it doesn't exist
ALTER TABLE job_results
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- Create or replace function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_job_results_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS update_job_results_updated_at_trigger ON job_results;

-- Create trigger to auto-update updated_at on row changes
CREATE TRIGGER update_job_results_updated_at_trigger
    BEFORE UPDATE ON job_results
    FOR EACH ROW
    EXECUTE FUNCTION update_job_results_updated_at();

-- ============================================================================
-- 4. Verify columns exist for Realtime payload
-- ============================================================================

-- Ensure these columns exist (should already be there):
-- - fal_job_id (for filtering)
-- - status (for state tracking)
-- - image_url (for result)
-- - updated_at (for ordering - just added)
-- - user_id or device_id (for RLS)

-- Add comment for documentation
COMMENT ON PUBLICATION supabase_realtime IS
'Realtime publication for job_results table to enable live job status updates';

-- ============================================================================
-- 5. Grant necessary permissions for Realtime
-- ============================================================================

-- Ensure authenticated users can read their own job results
-- (RLS policies should already handle this, but verify)

-- Grant SELECT to authenticated role (for Realtime subscriptions)
GRANT SELECT ON job_results TO authenticated;
GRANT SELECT ON job_results TO anon;

-- ============================================================================
-- SUCCESS
-- ============================================================================

-- Realtime is now enabled on job_results
-- Frontend can subscribe with:
-- supabase.channel().on('postgres_changes', {
--   event: 'UPDATE',
--   schema: 'public',
--   table: 'job_results',
--   filter: 'fal_job_id=eq.xxx'
-- }).subscribe()
