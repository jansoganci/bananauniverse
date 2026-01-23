-- =====================================================
-- Get Current Thumbnail Filenames from Database
-- =====================================================
-- 
-- Purpose: Extract current thumbnail filenames from database
--          to use for uploading new images
--
-- Usage: Run this query in Supabase SQL Editor
--        Copy the filename column values
-- =====================================================

SELECT 
    -- Extract filename from full URL
    CASE 
        WHEN thumbnail_url LIKE '%/%' THEN
            SUBSTRING(thumbnail_url FROM '/([^/]+)$')
        ELSE
            thumbnail_url
    END as filename
FROM themes
WHERE is_available = true
  AND thumbnail_url IS NOT NULL
ORDER BY category, name;
