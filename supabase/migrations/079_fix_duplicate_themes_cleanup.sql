-- =====================================================
-- Fix Duplicate Themes and Add Unique Constraint
-- =====================================================
--
-- Purpose: Clean up duplicate themes and prevent future duplicates
--
-- Steps:
-- 1. Remove duplicate themes (keep oldest by created_at)
-- 2. Add unique constraint on (name, category)
-- 3. Prevent future duplicates
--
-- =====================================================

-- Step 1: Remove Duplicate Themes
-- Keep the oldest theme for each (name, category) combination
DO $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- Delete duplicates, keeping the oldest one
    WITH ranked_themes AS (
        SELECT 
            id,
            ROW_NUMBER() OVER (
                PARTITION BY name, category 
                ORDER BY created_at ASC
            ) as rn
        FROM themes
    )
    DELETE FROM themes
    WHERE id IN (
        SELECT id FROM ranked_themes WHERE rn > 1
    );
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE NOTICE '🧹 Cleaned up % duplicate themes', deleted_count;
END $$;

-- Step 2: Add Unique Constraint
-- This prevents future duplicates
ALTER TABLE themes 
ADD CONSTRAINT themes_name_category_unique 
UNIQUE (name, category);

-- Step 3: Create index for the unique constraint (if not auto-created)
CREATE INDEX IF NOT EXISTS idx_themes_name_category 
ON themes(name, category);

-- Verification
DO $$
DECLARE
    total_themes INTEGER;
    total_categories INTEGER;
BEGIN
    SELECT COUNT(*) INTO total_themes FROM themes;
    SELECT COUNT(DISTINCT category) INTO total_categories FROM themes;
    
    RAISE NOTICE '✅ Cleanup complete!';
    RAISE NOTICE '   Total themes: %', total_themes;
    RAISE NOTICE '   Categories with themes: %', total_categories;
    RAISE NOTICE '   Unique constraint added: themes(name, category)';
END $$;

-- =====================================================
-- After this migration:
-- - All duplicates removed
-- - Unique constraint ensures no future duplicates
-- - Migrations can now be safely re-run
-- =====================================================

