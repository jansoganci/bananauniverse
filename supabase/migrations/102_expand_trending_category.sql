-- =====================================================
-- Migration 102: Expand Trending Now Category
-- =====================================================
--
-- Purpose: Add 3 more viral themes to "Trending Now" category
--          Current: 3 themes → After: 6 themes
--
-- WHY: 3 themes feels empty for the most important category
--      Need to showcase more viral content upfront
--
-- COPYRIGHT SAFE: All themes use generic style descriptions
--   ✅ "Kawaii Chibi Style" (generic cute doll aesthetic)
--   ✅ "Pop Art Style" (Warhol-inspired, not named)
--   ✅ "Manga Black & White" (manga = generic Japanese comic style, not trademarked)
--
-- BEFORE:
--   🔥 Trending Now: 3 themes
--     - Collectible Figure Style
--     - Building Block Character
--     - Renaissance Portrait
--
-- AFTER:
--   🔥 Trending Now: 6 themes
--     - Collectible Figure Style
--     - Building Block Character
--     - Renaissance Portrait
--     - Kawaii Chibi Style ← NEW!
--     - Pop Art Style ← NEW!
--     - Manga Black & White ← NEW! (155M+ TikTok views!)
--
-- =====================================================

BEGIN;

-- =====================================================
-- STEP 1: Move 3 Additional Viral Themes to Trending
-- =====================================================

-- Move Kawaii Chibi Style from artistic to trending
UPDATE themes
SET
    category = 'trending',
    is_featured = true,  -- Make it featured (appears in carousel)
    updated_at = now()
WHERE name = 'Kawaii Chibi Style'
  AND category = 'artistic';

-- Move Pop Art Style from transformations to trending
UPDATE themes
SET
    category = 'trending',
    is_featured = true,
    updated_at = now()
WHERE name = 'Pop Art Style'
  AND category = 'transformations';

-- Move Manga Black & White from artistic to trending
UPDATE themes
SET
    category = 'trending',
    is_featured = true,
    updated_at = now()
WHERE name = 'Manga Black & White'
  AND category = 'artistic';

-- =====================================================
-- STEP 2: Verification
-- =====================================================

DO $$
DECLARE
    trending_count INTEGER;
    transformations_count INTEGER;
    artistic_count INTEGER;
    rec RECORD;
BEGIN
    -- Count themes in each category
    SELECT COUNT(*) INTO trending_count
    FROM themes WHERE category = 'trending' AND is_available = true;

    SELECT COUNT(*) INTO transformations_count
    FROM themes WHERE category = 'transformations' AND is_available = true;

    SELECT COUNT(*) INTO artistic_count
    FROM themes WHERE category = 'artistic' AND is_available = true;

    -- Display results
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Trending Category Expanded!';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Trending Now: % themes (was 3, now 6)', trending_count;
    RAISE NOTICE 'Transformations: % themes (down 1: Pop Art)', transformations_count;
    RAISE NOTICE 'Artistic: % themes (down 2: Kawaii Chibi + Manga)', artistic_count;
    RAISE NOTICE '========================================';

    -- Safety checks
    IF trending_count != 6 THEN
        RAISE WARNING '⚠️  Expected 6 trending themes, got %', trending_count;
    ELSE
        RAISE NOTICE '✅ Perfect! Trending Now has 6 viral themes';
    END IF;

    -- List all trending themes
    RAISE NOTICE '';
    RAISE NOTICE '🔥 Trending Now themes:';
    FOR rec IN
        SELECT name FROM themes
        WHERE category = 'trending' AND is_available = true
        ORDER BY name
    LOOP
        RAISE NOTICE '   - %', rec.name;
    END LOOP;
END $$;

COMMIT;

-- =====================================================
-- Migration Complete!
-- =====================================================
--
-- Next Steps:
--   1. ✅ Migration ran successfully
--   2. 📱 Pull-to-refresh in BananaUniverse app
--   3. ✅ Verify "🔥 Trending Now" shows 6 themes
--   4. 🎉 Category feels substantial now!
--
-- Rollback:
--   See: 102_rollback.sql
--
-- =====================================================
