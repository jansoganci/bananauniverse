-- =====================================================
-- Migration: Add Snapchat-style ephemeral image fields
-- Purpose: Track saved status and auto-deletion time
-- Date: 2025-11-30
-- =====================================================

-- 1. Add columns to job_results table
ALTER TABLE public.job_results
ADD COLUMN IF NOT EXISTS saved_to_device BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS auto_delete_at TIMESTAMPTZ;

-- 2. Add comments
COMMENT ON COLUMN public.job_results.saved_to_device IS 'Has the user saved this image to their device?';
COMMENT ON COLUMN public.job_results.auto_delete_at IS 'When this image should be automatically deleted (if not saved)';

-- 3. Create index for fast cleanup queries
CREATE INDEX IF NOT EXISTS idx_job_results_auto_delete 
ON public.job_results(auto_delete_at) 
WHERE auto_delete_at IS NOT NULL AND saved_to_device = FALSE;

-- Log completion
DO $$
BEGIN
    RAISE NOTICE '✅ Added ephemeral image tracking fields to job_results';
END $$;

