-- =====================================================
-- Get Thumbnail Filenames with Extensions
-- =====================================================
-- 
-- Purpose: Check file extensions for all thumbnails
--          to ensure correct format when uploading
--
-- Usage: Run this query in Supabase SQL Editor
-- =====================================================

SELECT 
    name,
    -- Extract filename from full URL
    CASE 
        WHEN thumbnail_url LIKE '%/%' THEN
            SUBSTRING(thumbnail_url FROM '/([^/]+)$')
        ELSE
            thumbnail_url
    END as filename,
    -- Extract extension
    CASE 
        WHEN thumbnail_url LIKE '%.png' THEN '.png'
        WHEN thumbnail_url LIKE '%.jpg' THEN '.jpg'
        WHEN thumbnail_url LIKE '%.jpeg' THEN '.jpeg'
        ELSE 'unknown'
    END as extension
FROM themes
WHERE is_available = true
  AND thumbnail_url IS NOT NULL
ORDER BY category, name;
