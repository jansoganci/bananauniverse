-- =====================================================
-- Check Themes Missing Thumbnail URLs
-- =====================================================
-- 
-- Purpose: Find active themes that don't have thumbnail_url set
--
-- Usage: Run this query in Supabase SQL Editor
-- =====================================================

-- 1. Count total active themes
SELECT 
    'Total Active Themes' as status,
    COUNT(*) as count
FROM themes
WHERE is_available = true;

-- 2. Count themes WITH thumbnails
SELECT 
    'Themes WITH Thumbnails' as status,
    COUNT(*) as count
FROM themes
WHERE is_available = true
  AND thumbnail_url IS NOT NULL
  AND thumbnail_url != '';

-- 3. Count themes WITHOUT thumbnails
SELECT 
    'Themes WITHOUT Thumbnails' as status,
    COUNT(*) as count
FROM themes
WHERE is_available = true
  AND (thumbnail_url IS NULL OR thumbnail_url = '');

-- 4. List themes WITHOUT thumbnails
SELECT 
    category,
    name,
    thumbnail_url
FROM themes
WHERE is_available = true
  AND (thumbnail_url IS NULL OR thumbnail_url = '')
ORDER BY category, name;
