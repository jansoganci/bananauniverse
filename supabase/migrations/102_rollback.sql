-- =====================================================
-- Rollback Script for Migration 102
-- =====================================================
--
-- Purpose: Undo Trending Now expansion
--          Restore themes to original categories
--
-- Use this if:
--   - Migration caused unexpected issues
--   - Need to revert to 3-theme Trending Now
--
-- WARNING: Only run this if you need to undo migration 102!
--
-- =====================================================

BEGIN;

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '⚠️  Rolling back Migration 102';
    RAISE NOTICE '========================================';
END $$;

-- =====================================================
-- STEP 1: Move Themes Back to Original Categories
-- =====================================================

-- Move Kawaii Chibi Style back to artistic
UPDATE themes
SET
    category = 'artistic',
    is_featured = false,  -- Remove featured status
    updated_at = now()
WHERE name = 'Kawaii Chibi Style'
  AND category = 'trending';

-- Move Pop Art Style back to transformations
UPDATE themes
SET
    category = 'transformations',
    is_featured = false,
    updated_at = now()
WHERE name = 'Pop Art Style'
  AND category = 'trending';

-- Move Manga Black & White back to artistic
UPDATE themes
SET
    category = 'artistic',
    is_featured = false,
    updated_at = now()
WHERE name = 'Manga Black & White'
  AND category = 'trending';

-- =====================================================
-- STEP 2: Verification
-- =====================================================

DO $$
DECLARE
    trending_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO trending_count
    FROM themes WHERE category = 'trending' AND is_available = true;

    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Rollback Complete!';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Trending Now: % themes (should be 3)', trending_count;
    RAISE NOTICE '========================================';

    IF trending_count = 3 THEN
        RAISE NOTICE '✅ Successfully restored to 3 trending themes';
    ELSE
        RAISE WARNING '⚠️  Expected 3 themes, got %', trending_count;
    END IF;
END $$;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'Next step: Pull-to-refresh in app to see original Trending Now';
    RAISE NOTICE '';
END $$;

COMMIT;

-- =====================================================
-- Rollback Complete!
-- =====================================================
