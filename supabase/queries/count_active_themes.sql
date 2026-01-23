-- =====================================================
-- Count Active Themes
-- =====================================================
-- 
-- Purpose: Count total active themes in database
--
-- Usage: Run this query in Supabase SQL Editor
-- =====================================================

SELECT 
    COUNT(*) as total_active_themes
FROM themes
WHERE is_available = true;
