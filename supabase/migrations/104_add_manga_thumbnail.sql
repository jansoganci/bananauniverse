-- =====================================================
-- Migration 104: Add Thumbnail to Anime Manga Style
-- =====================================================
--
-- Purpose: Set thumbnail_url for Anime Manga Style theme
--
-- =====================================================

BEGIN;

UPDATE themes
SET
    thumbnail_url = 'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/anime-manga-style.jpg',
    updated_at = now()
WHERE name = 'Anime Manga Style';

-- Verification
DO $$
DECLARE
    thumbnail_set BOOLEAN;
    current_url TEXT;
BEGIN
    SELECT
        thumbnail_url IS NOT NULL,
        thumbnail_url
    INTO thumbnail_set, current_url
    FROM themes
    WHERE name = 'Anime Manga Style';

    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Thumbnail Updated!';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Theme: Anime Manga Style';
    RAISE NOTICE 'Thumbnail set: %', thumbnail_set;
    RAISE NOTICE 'URL: %', current_url;
    RAISE NOTICE '========================================';

    IF NOT thumbnail_set THEN
        RAISE WARNING '⚠️  Thumbnail URL was not set!';
    ELSE
        RAISE NOTICE '✅ Thumbnail URL configured successfully!';
        RAISE NOTICE 'Pull-to-refresh in app to see the image!';
    END IF;
END $$;

COMMIT;
