-- =====================================================
-- Migration 106: Add Short Description for Carousel
-- =====================================================
--
-- Purpose: Add short_description field for featured carousel
--          messaging overlay
--
-- =====================================================

BEGIN;

-- =====================================================
-- STEP 1: Add short_description Column
-- =====================================================

ALTER TABLE themes
ADD COLUMN IF NOT EXISTS short_description TEXT;

-- =====================================================
-- STEP 2: Add Short Descriptions for Trending Themes
-- =====================================================

-- Trending category (featured in carousel)
UPDATE themes SET short_description = 'Turn yourself into a collectible desk toy'
WHERE name = 'Collectible Figure Style';

UPDATE themes SET short_description = 'Classic block character transformation'
WHERE name = 'Building Block Character';

UPDATE themes SET short_description = 'Classical art meets internet humor'
WHERE name = 'Renaissance Portrait';

UPDATE themes SET short_description = 'Adorable chibi doll style'
WHERE name = 'Kawaii Chibi Style';

UPDATE themes SET short_description = 'Bold Warhol-inspired pop art'
WHERE name = 'Pop Art Style';

UPDATE themes SET short_description = 'Bold black & white manga art style'
WHERE name = 'Anime Manga Style';

-- Add for other popular themes (optional)
UPDATE themes SET short_description = 'Dynamic superhero action figure style'
WHERE name = 'Comic Book Hero';

UPDATE themes SET short_description = 'Enchanting Ghibli anime aesthetic'
WHERE name = 'Studio Ghibli Style';

UPDATE themes SET short_description = 'Illuminated medieval manuscript art'
WHERE name = 'Medieval Painting';

-- =====================================================
-- STEP 3: Verification
-- =====================================================

DO $$
DECLARE
    total_with_short_desc INTEGER;
    trending_with_short_desc INTEGER;
    rec RECORD;
BEGIN
    -- Count themes with short descriptions
    SELECT COUNT(*) INTO total_with_short_desc
    FROM themes WHERE short_description IS NOT NULL;

    SELECT COUNT(*) INTO trending_with_short_desc
    FROM themes WHERE category = 'trending' AND short_description IS NOT NULL;

    -- Display results
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Short Descriptions Added!';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Total themes with short_description: %', total_with_short_desc;
    RAISE NOTICE 'Trending themes with short_description: %', trending_with_short_desc;
    RAISE NOTICE '========================================';

    -- List trending themes with short descriptions
    RAISE NOTICE '';
    RAISE NOTICE '🔥 Trending Themes (for carousel):';
    FOR rec IN
        SELECT name, short_description FROM themes
        WHERE category = 'trending' AND is_available = true
        ORDER BY name
    LOOP
        RAISE NOTICE '   - %: "%"', rec.name, rec.short_description;
    END LOOP;

    RAISE NOTICE '';
    RAISE NOTICE '✅ Next: Build app to see new carousel messaging!';
END $$;

COMMIT;

-- =====================================================
-- Migration Complete!
-- =====================================================
--
-- Next Steps:
--   1. ✅ Run this migration
--   2. 📱 Build and run BananaUniverse app
--   3. ✅ See new carousel with text overlays!
--
-- Note: CarouselCard.swift will fall back to full description
--       if short_description is NULL
--
-- =====================================================
