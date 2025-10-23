-- Migration: Fix storage policies for processed images
-- This allows the job-status function to save processed images to Supabase Storage

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Users can upload own files" ON storage.objects;
DROP POLICY IF EXISTS "Users can read own files" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own files" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own files" ON storage.objects;
DROP POLICY IF EXISTS "Allow reads from processed directory" ON storage.objects;
DROP POLICY IF EXISTS "Allow uploads to processed directory" ON storage.objects;
DROP POLICY IF EXISTS "Allow updates to processed directory" ON storage.objects;
DROP POLICY IF EXISTS "Service role full access uploads" ON storage.objects;
DROP POLICY IF EXISTS "Service role full access processed" ON storage.objects;
DROP POLICY IF EXISTS "Public read processed" ON storage.objects;

-- Service role full access to uploads directory
CREATE POLICY "Service role full access uploads"
ON storage.objects FOR ALL
TO service_role
USING (
    bucket_id = 'noname-banana-images-prod' AND
    name LIKE 'uploads/%'
);

-- Service role full access to processed directory
CREATE POLICY "Service role full access processed"
ON storage.objects FOR ALL
TO service_role
USING (
    bucket_id = 'noname-banana-images-prod' AND
    name LIKE 'processed/%'
);

-- Public read access to processed directory
CREATE POLICY "Public read processed"
ON storage.objects FOR SELECT
TO public
USING (
    bucket_id = 'noname-banana-images-prod' AND
    name LIKE 'processed/%'
);
