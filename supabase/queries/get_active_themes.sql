-- =====================================================
-- Get Active Themes (Currently Used in App)
-- =====================================================
-- 
-- Purpose: List all themes that are currently active
--          (is_available = true) in the app
--
-- Usage: Run this query in Supabase SQL Editor
-- =====================================================

SELECT 
    category,
    name,
    prompt,
    is_featured,
    thumbnail_url
FROM themes
WHERE is_available = true
ORDER BY category, name ASC;
