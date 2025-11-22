-- =====================================================
-- Migration 105: Add Badge Fields to Themes
-- =====================================================
--
-- Purpose: Add "NEW" and "🔥 VIRAL" badge support
--          Helps users discover trending and new tools
--
-- Fields:
--   - is_new: Boolean (auto-calculated based on created_at)
--   - is_popular: Boolean (manually curated or auto-calculated)
--   - popularity_score: Integer (usage tracking)
--
-- =====================================================

BEGIN;

-- =====================================================
-- STEP 1: Add Badge Columns
-- =====================================================

-- Add is_new column (shows for 30 days after creation)
ALTER TABLE themes
ADD COLUMN IF NOT EXISTS is_new BOOLEAN DEFAULT false;

-- Add is_popular column (manually curated or based on usage)
ALTER TABLE themes
ADD COLUMN IF NOT EXISTS is_popular BOOLEAN DEFAULT false;

-- Add popularity_score column (tracks usage count)
ALTER TABLE themes
ADD COLUMN IF NOT EXISTS popularity_score INTEGER DEFAULT 0;

-- =====================================================
-- STEP 2: Mark Current Trending Themes as Popular
-- =====================================================

-- Mark themes in "trending" category as popular
UPDATE themes
SET
    is_popular = true,
    updated_at = now()
WHERE category = 'trending'
  AND is_available = true;

-- =====================================================
-- STEP 3: Mark Recently Added Themes as New
-- =====================================================

-- Mark themes created in last 30 days as new
-- (Assumes created_at field exists and is populated)
UPDATE themes
SET
    is_new = true,
    updated_at = now()
WHERE created_at > now() - interval '30 days'
  AND is_available = true;

-- If created_at doesn't exist, manually mark Anime Manga Style as new
UPDATE themes
SET
    is_new = true,
    updated_at = now()
WHERE name = 'Anime Manga Style';

-- =====================================================
-- STEP 4: Verification
-- =====================================================

DO $$
DECLARE
    new_count INTEGER;
    popular_count INTEGER;
    rec RECORD;
BEGIN
    -- Count badges
    SELECT COUNT(*) INTO new_count
    FROM themes WHERE is_new = true AND is_available = true;

    SELECT COUNT(*) INTO popular_count
    FROM themes WHERE is_popular = true AND is_available = true;

    -- Display results
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Badge Fields Added!';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Themes with NEW badge: %', new_count;
    RAISE NOTICE 'Themes with POPULAR badge: %', popular_count;
    RAISE NOTICE '========================================';

    -- List popular themes
    RAISE NOTICE '';
    RAISE NOTICE '🔥 Popular Themes:';
    FOR rec IN
        SELECT name FROM themes
        WHERE is_popular = true AND is_available = true
        ORDER BY name
    LOOP
        RAISE NOTICE '   - %', rec.name;
    END LOOP;

    -- List new themes
    RAISE NOTICE '';
    RAISE NOTICE '✨ New Themes:';
    FOR rec IN
        SELECT name FROM themes
        WHERE is_new = true AND is_available = true
        ORDER BY name
    LOOP
        RAISE NOTICE '   - %', rec.name;
    END LOOP;

    RAISE NOTICE '';
    RAISE NOTICE '✅ Next: Update SwiftUI ToolCard to display badges!';
END $$;

COMMIT;

-- =====================================================
-- Migration Complete!
-- =====================================================
--
-- Next Steps:
--   1. ✅ Run this migration
--   2. 📱 Update ToolCard.swift to show badges
--   3. ✅ Pull-to-refresh to see badges in app
--
-- Badge Logic:
--   - NEW: Shows for themes created in last 30 days
--   - POPULAR: Shows for trending themes (manually curated)
--
-- =====================================================
