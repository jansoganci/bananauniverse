-- =====================================================
-- Rollback Script for Migration 101
-- =====================================================
--
-- Purpose: Undo viral-first category reorganization
--          Restore original 10-category structure
--
-- Use this if:
--   - Migration caused unexpected issues
--   - Need to revert to old category structure
--   - Testing went wrong
--
-- WARNING: Only run this if you need to undo migration 101!
--
-- =====================================================

BEGIN;

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '⚠️  Rolling back Migration 101';
    RAISE NOTICE '========================================';
END $$;

-- =====================================================
-- STEP 1: Restore Themes to Original Categories
-- =====================================================

-- Move Trending themes back to original categories
UPDATE themes
SET
    category = 'toy_style',
    is_featured = true,  -- Keep featured status
    updated_at = now()
WHERE name IN ('Collectible Figure Style', 'Building Block Character');

UPDATE themes
SET
    category = 'meme_magic',
    is_featured = true,
    updated_at = now()
WHERE name = 'Renaissance Portrait';

-- Restore Toy Style themes (minus the 2 that went to trending)
UPDATE themes
SET
    category = 'toy_style',
    updated_at = now()
WHERE category = 'transformations'
  AND name IN (
      'Action Figure Hero',
      'Fashion Doll Style',
      'Plush Toy Style',
      'Retro Toy Robot',
      'Die-Cast Model Style',
      'Wooden Toy Character',
      'Designer Toy Art',
      'Chibi Nendoroid Style'
  );

-- Restore Meme Magic themes (minus Renaissance Portrait)
UPDATE themes
SET
    category = 'meme_magic',
    updated_at = now()
WHERE category = 'transformations'
  AND name NOT IN (
      'Collectible Figure Style',
      'Building Block Character',
      'Renaissance Portrait',
      'Action Figure Hero',
      'Fashion Doll Style',
      'Plush Toy Style',
      'Retro Toy Robot',
      'Die-Cast Model Style',
      'Wooden Toy Character',
      'Designer Toy Art',
      'Chibi Nendoroid Style'
  )
  -- Meme Magic theme check (partial list - adjust if needed)
  AND (
      name LIKE '%Ogre%' OR
      name LIKE '%Animated Family%' OR
      name LIKE '%South Park%' OR
      name LIKE '%Funko%' OR
      name LIKE '%Simpson%' OR
      name LIKE '%Salvador%' OR
      name LIKE '%Picasso%' OR
      name LIKE '%Warhol%' OR
      name LIKE '%Botero%' OR
      name LIKE '%Haring%'
  );

-- Restore Animated Vehicles themes
UPDATE themes
SET
    category = 'animated_vehicles',
    updated_at = now()
WHERE category = 'transformations'
  AND name NOT IN (
      'Collectible Figure Style',
      'Building Block Character',
      'Renaissance Portrait'
  )
  -- Remaining transformations that aren't toy or meme
  AND category = 'transformations';

-- Restore Pro Looks
UPDATE themes
SET
    category = 'pro_looks',
    updated_at = now()
WHERE category = 'pro_tools';

-- Split Enhancements back into Restoration + Main Tools
UPDATE themes
SET
    category = 'restoration',
    updated_at = now()
WHERE category = 'enhancements'
  AND name IN (
      'Image Upscaler (2x-4x)',
      'Historical Photo Restore'
  );

UPDATE themes
SET
    category = 'main_tools',
    updated_at = now()
WHERE category = 'enhancements';

-- Split Artistic back into Anime + Retro
UPDATE themes
SET
    category = 'anime_styles',
    updated_at = now()
WHERE category = 'artistic'
  AND name IN (
      'Studio Ghibli Style',
      'Anime Portrait',
      'Manga Black & White'
  );

UPDATE themes
SET
    category = 'retro_aesthetic',
    updated_at = now()
WHERE category = 'artistic';

-- Split Seasonal back into Thanksgiving + Christmas
UPDATE themes
SET
    category = 'thanksgiving',
    updated_at = now()
WHERE category = 'seasonal'
  AND name LIKE '%Turkey%'
     OR name LIKE '%Thanksgiving%'
     OR name LIKE '%Autumn%'
     OR name LIKE '%Pilgrim%'
     OR name LIKE '%Gratitude%';

UPDATE themes
SET
    category = 'christmas',
    updated_at = now()
WHERE category = 'seasonal';

-- =====================================================
-- STEP 2: Reactivate Original 10 Categories
-- =====================================================

UPDATE categories
SET
    is_active = true,
    updated_at = now()
WHERE id IN (
    'toy_style',
    'meme_magic',
    'animated_vehicles',
    'pro_looks',
    'restoration',
    'main_tools',
    'anime_styles',
    'retro_aesthetic',
    'thanksgiving',
    'christmas'
);

-- Restore original display order
UPDATE categories SET display_order = 1 WHERE id = 'thanksgiving';
UPDATE categories SET display_order = 2 WHERE id = 'christmas';
UPDATE categories SET display_order = 3 WHERE id = 'anime_styles';
UPDATE categories SET display_order = 4 WHERE id = 'meme_magic';
UPDATE categories SET display_order = 5 WHERE id = 'animated_vehicles';
UPDATE categories SET display_order = 6 WHERE id = 'retro_aesthetic';
UPDATE categories SET display_order = 7 WHERE id = 'toy_style';
UPDATE categories SET display_order = 8 WHERE id = 'pro_looks';
UPDATE categories SET display_order = 9 WHERE id = 'restoration';
UPDATE categories SET display_order = 10 WHERE id = 'main_tools';

-- =====================================================
-- STEP 3: Deactivate New Categories
-- =====================================================

UPDATE categories
SET
    is_active = false,
    updated_at = now()
WHERE id IN (
    'trending',
    'transformations',
    'pro_tools',
    'enhancements',
    'artistic',
    'seasonal'
);

-- =====================================================
-- STEP 4: Verification
-- =====================================================

DO $$
DECLARE
    total_themes INTEGER;
    total_active_categories INTEGER;
BEGIN
    SELECT COUNT(*) INTO total_themes
    FROM themes WHERE is_available = true;

    SELECT COUNT(*) INTO total_active_categories
    FROM categories WHERE is_active = true;

    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Rollback Complete!';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Total themes: % (should be ~69)', total_themes;
    RAISE NOTICE 'Active categories: % (should be 10)', total_active_categories;
    RAISE NOTICE '========================================';

    IF total_active_categories = 10 THEN
        RAISE NOTICE '✅ Successfully restored to 10 original categories';
    ELSE
        RAISE WARNING '⚠️  Expected 10 categories, got %', total_active_categories;
    END IF;

    IF total_themes < 60 THEN
        RAISE WARNING '⚠️  Theme count seems low: %', total_themes;
    END IF;
END $$;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'Next step: Pull-to-refresh in app to see original categories';
    RAISE NOTICE '';
END $$;

COMMIT;

-- =====================================================
-- Rollback Complete!
-- =====================================================
