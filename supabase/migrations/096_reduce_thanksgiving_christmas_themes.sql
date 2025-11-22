-- =====================================================
-- Reduce Thanksgiving and Christmas Theme Count
-- =====================================================
--
-- Purpose: Reduce theme count to balance categories
--          Thanksgiving: 8 → 5 themes (hide 3)
--          Christmas: 10 → 5 themes (hide 5)
--
-- Method: Set is_available = false (NOT DELETE)
--         Themes remain in database, can be re-enabled later
--
-- Date: 2025-11-21
--
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE 'Starting theme reduction for Thanksgiving and Christmas...';
END $$;

-- =====================================================
-- STEP 1: Hide 3 Thanksgiving Themes
-- =====================================================

-- Hide: Pilgrim Heritage Portrait (too specific)
UPDATE themes
SET is_available = false,
    updated_at = now()
WHERE category = 'thanksgiving'
  AND name = 'Pilgrim Heritage Portrait';

-- Hide: Harvest Festival Joy (similar to Autumn Harvest Magic)
UPDATE themes
SET is_available = false,
    updated_at = now()
WHERE category = 'thanksgiving'
  AND name = 'Harvest Festival Joy';

-- Hide: Turkey Day Fun (too childish)
UPDATE themes
SET is_available = false,
    updated_at = now()
WHERE category = 'thanksgiving'
  AND name = 'Turkey Day Fun';

-- =====================================================
-- STEP 2: Hide 5 Christmas Themes
-- =====================================================

-- Hide: Gingerbread Delight (too specific)
UPDATE themes
SET is_available = false,
    updated_at = now()
WHERE category = 'christmas'
  AND name = 'Gingerbread Delight';

-- Hide: North Pole Elf Magic (too childish)
UPDATE themes
SET is_available = false,
    updated_at = now()
WHERE category = 'christmas'
  AND name = 'North Pole Elf Magic';

-- Hide: Santa's Workshop Style (similar to North Pole)
UPDATE themes
SET is_available = false,
    updated_at = now()
WHERE category = 'christmas'
  AND name = 'Santa''s Workshop Style';

-- Hide: Snowy Christmas Eve (similar to Frosty Winter Wonderland)
UPDATE themes
SET is_available = false,
    updated_at = now()
WHERE category = 'christmas'
  AND name = 'Snowy Christmas Eve';

-- Hide: Candy Cane Cheer (too specific)
UPDATE themes
SET is_available = false,
    updated_at = now()
WHERE category = 'christmas'
  AND name = 'Candy Cane Cheer';

-- =====================================================
-- VERIFICATION
-- =====================================================

DO $$
DECLARE
    thanksgiving_active INTEGER;
    thanksgiving_total INTEGER;
    christmas_active INTEGER;
    christmas_total INTEGER;
BEGIN
    -- Count active themes
    SELECT COUNT(*) INTO thanksgiving_active
    FROM themes
    WHERE category = 'thanksgiving' AND is_available = true;
    
    SELECT COUNT(*) INTO thanksgiving_total
    FROM themes
    WHERE category = 'thanksgiving';
    
    SELECT COUNT(*) INTO christmas_active
    FROM themes
    WHERE category = 'christmas' AND is_available = true;
    
    SELECT COUNT(*) INTO christmas_total
    FROM themes
    WHERE category = 'christmas';
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Theme Reduction Complete!';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Thanksgiving:';
    RAISE NOTICE '   Active: % themes (was 8)', thanksgiving_active;
    RAISE NOTICE '   Hidden: % themes', thanksgiving_total - thanksgiving_active;
    RAISE NOTICE '   Total in DB: % themes', thanksgiving_total;
    RAISE NOTICE '';
    RAISE NOTICE 'Christmas:';
    RAISE NOTICE '   Active: % themes (was 10)', christmas_active;
    RAISE NOTICE '   Hidden: % themes', christmas_total - christmas_active;
    RAISE NOTICE '   Total in DB: % themes', christmas_total;
    RAISE NOTICE '';
    
    -- Verify target counts
    IF thanksgiving_active = 5 AND christmas_active = 5 THEN
        RAISE NOTICE '✅ SUCCESS: Target counts achieved!';
        RAISE NOTICE '   Thanksgiving: 5 active themes';
        RAISE NOTICE '   Christmas: 5 active themes';
    ELSE
        RAISE WARNING '⚠️  Unexpected counts - please verify manually';
    END IF;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Note: Hidden themes can be re-enabled by setting is_available = true';
    RAISE NOTICE '========================================';
END $$;

-- =====================================================
-- Migration Complete!
-- =====================================================
-- 
-- Result:
--   Thanksgiving: 8 → 5 active themes (3 hidden)
--   Christmas: 10 → 5 active themes (5 hidden)
--
-- Hidden themes remain in database and can be re-enabled later
--
-- =====================================================

