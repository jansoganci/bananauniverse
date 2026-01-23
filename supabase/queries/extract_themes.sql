-- =====================================================
-- Extract All Theme Names and Prompts
-- =====================================================
-- 
-- Purpose: Extract theme names and their prompts
-- Ordered by: name (alphabetically)
--
-- Usage: Run this query in Supabase SQL Editor
-- =====================================================

SELECT 
    category,
    name,
    prompt
FROM themes
ORDER BY category, name ASC;
