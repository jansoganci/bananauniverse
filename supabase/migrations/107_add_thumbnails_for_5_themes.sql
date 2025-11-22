-- =====================================================
-- Migration 107: Add Thumbnails for 5 Updated Themes
-- =====================================================
--
-- Purpose: Set thumbnail_url for themes that got new images
--
-- Themes updated:
--   1. Building Block Character
--   2. Collectible Figure Style
--   3. Medieval Painting
--   4. Action Figure Hero
--   5. Cartoon Truck
--
-- =====================================================

BEGIN;

-- =====================================================
-- STEP 1: Update Thumbnail URLs
-- =====================================================

UPDATE themes
SET
    thumbnail_url = 'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/building-block-character.jpg',
    updated_at = now()
WHERE name = 'Building Block Character';

UPDATE themes
SET
    thumbnail_url = 'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/collectible-figure-style.jpg',
    updated_at = now()
WHERE name = 'Collectible Figure Style';

UPDATE themes
SET
    thumbnail_url = 'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/medieval-painting.jpg',
    updated_at = now()
WHERE name = 'Medieval Painting';

UPDATE themes
SET
    thumbnail_url = 'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/action-figure-hero.jpg',
    updated_at = now()
WHERE name = 'Action Figure Hero';

UPDATE themes
SET
    thumbnail_url = 'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/cartoon-truck.jpg',
    updated_at = now()
WHERE name = 'Cartoon Truck';

-- =====================================================
-- STEP 2: Verification
-- =====================================================

DO $$
DECLARE
    rec RECORD;
    total_updated INTEGER := 0;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Thumbnails Updated for 5 Themes';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';

    -- List all updated themes with their thumbnail URLs
    FOR rec IN
        SELECT name, thumbnail_url
        FROM themes
        WHERE name IN (
            'Building Block Character',
            'Collectible Figure Style',
            'Medieval Painting',
            'Action Figure Hero',
            'Cartoon Truck'
        )
        ORDER BY name
    LOOP
        IF rec.thumbnail_url IS NOT NULL THEN
            total_updated := total_updated + 1;
            RAISE NOTICE '✅ %', rec.name;
            RAISE NOTICE '   URL: %', rec.thumbnail_url;
        ELSE
            RAISE WARNING '⚠️  % - No thumbnail URL set!', rec.name;
        END IF;
    END LOOP;

    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Total themes updated: % / 5', total_updated;
    RAISE NOTICE '========================================';

    IF total_updated = 5 THEN
        RAISE NOTICE '✅ All 5 thumbnails updated successfully!';
        RAISE NOTICE 'Pull-to-refresh in app to see new images!';
    ELSE
        RAISE WARNING '⚠️  Only % out of 5 themes were updated', total_updated;
    END IF;
END $$;

COMMIT;

-- =====================================================
-- Migration Complete!
-- =====================================================
--
-- Next Steps:
--   1. ✅ Run this migration
--   2. 📱 Pull-to-refresh in BananaUniverse app
--   3. ✅ See new thumbnails in carousel and category rows!
--
-- =====================================================
