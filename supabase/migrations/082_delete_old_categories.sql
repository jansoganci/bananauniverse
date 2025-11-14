-- =====================================================
-- Delete Old Categories and Their Themes
-- =====================================================
--
-- Purpose: Remove original categories to focus on viral content
--          Streamline app to trendy, fun, shareable themes only
--
-- Categories to DELETE:
--   - restoration (Image upscaling, photo restoration)
--   - seasonal (Old generic seasonal themes)
--   - pro_looks (Professional photos, LinkedIn headshots)
--   - main_tools (Photo editing tools)
--
-- This will DELETE approximately 28 themes total
--
-- Remaining categories after deletion:
--   - animated_vehicles (10 themes)
--   - anime_styles (15 themes)
--   - retro_aesthetic (10 themes)
--   - toy_style (10 themes)
--   - meme_magic (12 themes)
--   - thanksgiving (8 themes)
--   - christmas (10 themes)
--
-- Total remaining: ~75 viral themes
--
-- ⚠️ WARNING: THIS IS IRREVERSIBLE
--
-- =====================================================

-- Log what we're about to delete
DO $$
DECLARE
    restoration_count INTEGER;
    seasonal_count INTEGER;
    pro_looks_count INTEGER;
    main_tools_count INTEGER;
    total_before_delete INTEGER;
BEGIN
    -- Count themes in each category before deletion
    SELECT COUNT(*) INTO restoration_count FROM themes WHERE category = 'restoration';
    SELECT COUNT(*) INTO seasonal_count FROM themes WHERE category = 'seasonal';
    SELECT COUNT(*) INTO pro_looks_count FROM themes WHERE category = 'pro_looks';
    SELECT COUNT(*) INTO main_tools_count FROM themes WHERE category = 'main_tools';
    SELECT COUNT(*) INTO total_before_delete FROM themes;
    
    RAISE NOTICE '📊 Before Deletion:';
    RAISE NOTICE '   Total themes: %', total_before_delete;
    RAISE NOTICE '   restoration: % themes', restoration_count;
    RAISE NOTICE '   seasonal: % themes', seasonal_count;
    RAISE NOTICE '   pro_looks: % themes', pro_looks_count;
    RAISE NOTICE '   main_tools: % themes', main_tools_count;
    RAISE NOTICE '   Will delete: % themes total', restoration_count + seasonal_count + pro_looks_count + main_tools_count;
END $$;

-- Step 1: Delete all themes in these categories
-- (This happens automatically due to ON DELETE CASCADE, but being explicit)
DELETE FROM themes 
WHERE category IN ('restoration', 'seasonal', 'pro_looks', 'main_tools');

-- Step 2: Delete the categories
-- (Foreign key CASCADE will have already deleted themes)
DELETE FROM categories 
WHERE id IN ('restoration', 'seasonal', 'pro_looks', 'main_tools');

-- Step 3: Verification and summary
DO $$
DECLARE
    total_after_delete INTEGER;
    remaining_categories INTEGER;
    deleted_themes INTEGER;
BEGIN
    SELECT COUNT(*) INTO total_after_delete FROM themes;
    SELECT COUNT(*) INTO remaining_categories FROM categories WHERE is_active = true;
    
    RAISE NOTICE '✅ Deletion Complete!';
    RAISE NOTICE '   Total themes remaining: %', total_after_delete;
    RAISE NOTICE '   Active categories remaining: %', remaining_categories;
    RAISE NOTICE '';
    RAISE NOTICE '🎯 Your app now focuses on viral, trendy content:';
    RAISE NOTICE '   ✅ Animated Vehicles';
    RAISE NOTICE '   ✅ Anime Styles';
    RAISE NOTICE '   ✅ Retro Aesthetic';
    RAISE NOTICE '   ✅ Toy Style';
    RAISE NOTICE '   ✅ Meme Magic';
    RAISE NOTICE '   ✅ Thanksgiving';
    RAISE NOTICE '   ✅ Christmas';
END $$;

-- Optional: List remaining categories for verification
-- SELECT 
--     id,
--     name,
--     display_order,
--     (SELECT COUNT(*) FROM themes WHERE themes.category = categories.id) as theme_count
-- FROM categories
-- WHERE is_active = true
-- ORDER BY display_order;

-- =====================================================
-- Migration Complete!
-- =====================================================
-- 
-- Deleted:
--   - 4 old categories (restoration, seasonal, pro_looks, main_tools)
--   - ~28 themes total
--
-- Remaining:
--   - 7 viral categories
--   - ~75 trendy themes
--
-- Your app is now 100% focused on viral, fun, shareable content! 🚀
--
-- =====================================================

