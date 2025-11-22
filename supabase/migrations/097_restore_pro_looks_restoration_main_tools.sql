-- =====================================================
-- Restore Pro Looks, Restoration, and Main Tools Categories
-- =====================================================
--
-- Purpose: Re-add deleted categories at the bottom of the list
--          These categories were deleted in Migration 082
--          Now restoring them with themes already uploaded
--
-- Categories to Restore:
--   1. pro_looks (Pro Photos) - display_order: 8
--   2. restoration (Enhancer) - display_order: 9
--   3. main_tools (Photo Editor) - display_order: 10
--
-- Note: Themes for these categories should already be in database
--       (user mentioned they already uploaded images)
--
-- Date: 2025-11-21
--
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE 'Restoring pro_looks, restoration, and main_tools categories...';
END $$;

-- =====================================================
-- STEP 1: Restore pro_looks Category
-- =====================================================

INSERT INTO categories (id, name, display_order, is_active)
VALUES ('pro_looks', 'Pro Photos', 8, true)
ON CONFLICT (id) 
DO UPDATE SET
    name = EXCLUDED.name,
    display_order = EXCLUDED.display_order,
    is_active = EXCLUDED.is_active,
    updated_at = now();

DO $$
BEGIN
    RAISE NOTICE '✅ Restored pro_looks category (display_order: 8)';
END $$;

-- =====================================================
-- STEP 2: Restore restoration Category
-- =====================================================

INSERT INTO categories (id, name, display_order, is_active)
VALUES ('restoration', 'Enhancer', 9, true)
ON CONFLICT (id) 
DO UPDATE SET
    name = EXCLUDED.name,
    display_order = EXCLUDED.display_order,
    is_active = EXCLUDED.is_active,
    updated_at = now();

DO $$
BEGIN
    RAISE NOTICE '✅ Restored restoration category (display_order: 9)';
END $$;

-- =====================================================
-- STEP 3: Restore main_tools Category
-- =====================================================

INSERT INTO categories (id, name, display_order, is_active)
VALUES ('main_tools', 'Photo Editor', 10, true)
ON CONFLICT (id) 
DO UPDATE SET
    name = EXCLUDED.name,
    display_order = EXCLUDED.display_order,
    is_active = EXCLUDED.is_active,
    updated_at = now();

DO $$
BEGIN
    RAISE NOTICE '✅ Restored main_tools category (display_order: 10)';
END $$;

-- =====================================================
-- VERIFICATION
-- =====================================================

DO $$
DECLARE
    pro_looks_count INTEGER;
    restoration_count INTEGER;
    main_tools_count INTEGER;
    total_active_categories INTEGER;
BEGIN
    -- Count themes in each restored category
    SELECT COUNT(*) INTO pro_looks_count
    FROM themes
    WHERE category = 'pro_looks' AND is_available = true;
    
    SELECT COUNT(*) INTO restoration_count
    FROM themes
    WHERE category = 'restoration' AND is_available = true;
    
    SELECT COUNT(*) INTO main_tools_count
    FROM themes
    WHERE category = 'main_tools' AND is_available = true;
    
    SELECT COUNT(*) INTO total_active_categories
    FROM categories
    WHERE is_active = true;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Category Restoration Complete!';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Restored Categories:';
    RAISE NOTICE '   ✅ pro_looks (Pro Photos) - % active themes', pro_looks_count;
    RAISE NOTICE '   ✅ restoration (Enhancer) - % active themes', restoration_count;
    RAISE NOTICE '   ✅ main_tools (Photo Editor) - % active themes', main_tools_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Total active categories: %', total_active_categories;
    RAISE NOTICE '';
    RAISE NOTICE 'Display Order (bottom 3):';
    RAISE NOTICE '   8. Pro Photos';
    RAISE NOTICE '   9. Enhancer';
    RAISE NOTICE '   10. Photo Editor';
    RAISE NOTICE '========================================';
    
    -- Warn if categories have no themes
    IF pro_looks_count = 0 THEN
        RAISE WARNING '⚠️  pro_looks category has no active themes - add themes to make it visible';
    END IF;
    
    IF restoration_count = 0 THEN
        RAISE WARNING '⚠️  restoration category has no active themes - add themes to make it visible';
    END IF;
    
    IF main_tools_count = 0 THEN
        RAISE WARNING '⚠️  main_tools category has no active themes - add themes to make it visible';
    END IF;
END $$;

-- =====================================================
-- Migration Complete!
-- =====================================================
-- 
-- Result:
--   ✅ pro_looks (Pro Photos) restored at display_order: 8
--   ✅ restoration (Enhancer) restored at display_order: 9
--   ✅ main_tools (Photo Editor) restored at display_order: 10
--
-- These categories will appear at the BOTTOM of the home screen
-- (after all existing categories)
--
-- Next Steps:
--   1. Verify themes exist for these categories (user mentioned images uploaded)
--   2. If themes are is_available = false, set them to true
--   3. Pull-to-refresh in app to see new categories
--
-- =====================================================

