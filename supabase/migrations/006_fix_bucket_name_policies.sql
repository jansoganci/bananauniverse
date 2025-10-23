-- Migration: Fix storage policies with correct bucket name
-- Author: AI Assistant
-- Date: 2025-10-15
-- Description: Update storage policies to use correct bucket name 'noname-banana-images-prod'

-- Drop existing policies with wrong bucket name
DROP POLICY IF EXISTS "Service role full access uploads" ON storage.objects;
DROP POLICY IF EXISTS "Service role full access processed" ON storage.objects;
DROP POLICY IF EXISTS "Public read processed" ON storage.objects;

-- Service role full access to uploads directory (correct bucket name)
CREATE POLICY "Service role full access uploads"
ON storage.objects FOR ALL
TO service_role
USING (
    bucket_id = 'noname-banana-images-prod' AND
    name LIKE 'uploads/%'
);

-- Service role full access to processed directory (correct bucket name)
CREATE POLICY "Service role full access processed"
ON storage.objects FOR ALL
TO service_role
USING (
    bucket_id = 'noname-banana-images-prod' AND
    name LIKE 'processed/%'
);

-- Public read access to processed directory (correct bucket name)
CREATE POLICY "Public read processed"
ON storage.objects FOR SELECT
TO public
USING (
    bucket_id = 'noname-banana-images-prod' AND
    name LIKE 'processed/%'
);

-- Log migration success
DO $$
BEGIN
  RAISE NOTICE '✅ Migration 006_fix_bucket_name_policies completed successfully';
  RAISE NOTICE '   - Updated storage policies to use correct bucket name: noname-banana-images-prod';
  RAISE NOTICE '   - Service role can now access uploads and processed directories';
  RAISE NOTICE '   - Public can read processed images';
END $$;
