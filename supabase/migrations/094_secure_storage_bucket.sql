-- =====================================================
-- Migration: Secure Storage Buckets (RLS)
-- Purpose: Restrict access to uploads and processed images to owners only
-- Date: 2025-11-30
-- =====================================================

-- 1. Reset existing policies to start fresh
DROP POLICY IF EXISTS "Public read processed" ON storage.objects;
DROP POLICY IF EXISTS "Service role full access uploads" ON storage.objects;
DROP POLICY IF EXISTS "Service role full access processed" ON storage.objects;
DROP POLICY IF EXISTS "Users can view own uploads" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own uploads" ON storage.objects;
DROP POLICY IF EXISTS "Users can manage own uploads" ON storage.objects;
DROP POLICY IF EXISTS "Service role full access" ON storage.objects;

-- 2. ALLOW: Users can view/upload/delete ONLY their own files in 'uploads/'
-- Matches path pattern: uploads/{user_id}/*
CREATE POLICY "Users can manage own uploads"
ON storage.objects FOR ALL
TO authenticated
USING (
    bucket_id = 'noname-banana-images-prod' AND
    name LIKE 'uploads/%' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- 3. ALLOW: Users can view ONLY their own processed images
-- Checks if the user owns the job in 'job_results' table
-- Matches filename with fal_job_id (ignoring extension)
CREATE POLICY "Users can view own processed images"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'noname-banana-images-prod' AND
    name LIKE 'processed/%' AND
    EXISTS (
        SELECT 1 FROM job_results
        WHERE job_results.user_id = auth.uid()
        AND job_results.fal_job_id = split_part(split_part(name, '/', 2), '.', 1)
    )
);

-- 4. ALLOW: Service Role (Backend) has full access
CREATE POLICY "Service role full access"
ON storage.objects FOR ALL
TO service_role
USING (bucket_id = 'noname-banana-images-prod');

-- Log completion
DO $$
BEGIN
    RAISE NOTICE '✅ Secured storage buckets with strict RLS policies';
END $$;

