-- =====================================================
-- Rollback Script for Migration 103
-- =====================================================
--
-- Purpose: Remove Anime Manga Style and restore Comic Book Hero
--
-- =====================================================

BEGIN;

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '⚠️  Rolling back Migration 103';
    RAISE NOTICE '========================================';
END $$;

-- Remove Anime Manga Style theme
DELETE FROM themes
WHERE name = 'Anime Manga Style'
  AND category = 'trending';

-- Move Comic Book Hero back to trending
UPDATE themes
SET
    category = 'trending',
    is_featured = true,
    updated_at = now()
WHERE name = 'Comic Book Hero'
  AND category = 'transformations';

DO $$
DECLARE
    trending_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO trending_count
    FROM themes WHERE category = 'trending' AND is_available = true;

    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Rollback Complete!';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Trending Now: % themes (should be 6)', trending_count;
    RAISE NOTICE 'Anime Manga Style removed';
    RAISE NOTICE 'Comic Book Hero restored to trending';
    RAISE NOTICE '========================================';
END $$;

COMMIT;
