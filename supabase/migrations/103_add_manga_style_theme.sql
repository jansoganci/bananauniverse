-- =====================================================
-- Migration 103: Add Manga Style Theme to Trending
-- =====================================================
--
-- Purpose: Add viral "Anime Manga Style" theme
--          Replace "Comic Book Hero" with manga (155M+ TikTok views)
--
-- WHY: AI Manga Filter = 155M+ TikTok videos (most viral!)
--      Black & white manga aesthetic is highly shareable
--
-- COPYRIGHT SAFE: "Manga" is a generic Japanese word for comics
--                 Not trademarked or copyrighted
--
-- BEFORE:
--   🔥 Trending Now: 6 themes (includes Comic Book Hero)
--
-- AFTER:
--   🔥 Trending Now: 6 themes (Comic Book Hero → Anime Manga Style)
--
-- =====================================================

BEGIN;

-- =====================================================
-- STEP 1: Create Anime Manga Style Theme
-- =====================================================

INSERT INTO themes (
    name,
    description,
    category,
    model_name,
    placeholder_icon,
    prompt,
    is_featured,
    is_available,
    requires_pro,
    default_settings
) VALUES (
    'Anime Manga Style',
    'Transform into black & white manga art',
    'trending',
    'nano-banana/edit',
    'book.closed.fill',
    'Transform into manga style: clean black ink linework with varied line weight, dramatic high contrast black and white, halftone screen tone patterns for shading, speed lines and action effects, large expressive anime eyes with detailed highlights, dynamic hair with motion, manga panel composition with frame, powerful emotional expression, classic Japanese manga aesthetic, hand-drawn ink quality, authentic manga illustration style, bold graphic impact',
    true,
    true,
    false,
    '{}'::jsonb
)
ON CONFLICT (name, category) DO UPDATE SET
    description = EXCLUDED.description,
    prompt = EXCLUDED.prompt,
    is_featured = EXCLUDED.is_featured,
    updated_at = now();

-- =====================================================
-- STEP 2: Move Comic Book Hero Back to Transformations
-- =====================================================

UPDATE themes
SET
    category = 'transformations',
    is_featured = false,
    updated_at = now()
WHERE name = 'Comic Book Hero'
  AND category = 'trending';

-- =====================================================
-- STEP 3: Verification
-- =====================================================

DO $$
DECLARE
    trending_count INTEGER;
    manga_exists BOOLEAN;
    comic_in_trending BOOLEAN;
    rec RECORD;
BEGIN
    -- Count trending themes
    SELECT COUNT(*) INTO trending_count
    FROM themes WHERE category = 'trending' AND is_available = true;

    -- Check if manga exists in trending
    SELECT EXISTS(
        SELECT 1 FROM themes
        WHERE name = 'Anime Manga Style' AND category = 'trending'
    ) INTO manga_exists;

    -- Check if comic book is still in trending
    SELECT EXISTS(
        SELECT 1 FROM themes
        WHERE name = 'Comic Book Hero' AND category = 'trending'
    ) INTO comic_in_trending;

    -- Display results
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Manga Style Theme Added!';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Trending Now: % themes (should be 6)', trending_count;
    RAISE NOTICE 'Anime Manga Style created: %', manga_exists;
    RAISE NOTICE 'Comic Book Hero in trending: % (should be false)', comic_in_trending;
    RAISE NOTICE '========================================';

    -- Safety checks
    IF trending_count != 6 THEN
        RAISE WARNING '⚠️  Expected 6 trending themes, got %', trending_count;
    END IF;

    IF NOT manga_exists THEN
        RAISE WARNING '⚠️  Anime Manga Style was not created!';
    END IF;

    IF comic_in_trending THEN
        RAISE WARNING '⚠️  Comic Book Hero is still in trending!';
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

    RAISE NOTICE '';
    RAISE NOTICE '✅ Migration complete! Pull-to-refresh to see Anime Manga Style';
END $$;

COMMIT;

-- =====================================================
-- Migration Complete!
-- =====================================================
--
-- Next Steps:
--   1. ✅ Migration ran successfully
--   2. 📱 Pull-to-refresh in BananaUniverse app
--   3. ✅ Verify "Anime Manga Style" appears in Trending Now
--   4. 🎉 155M+ TikTok trend now featured!
--
-- =====================================================
