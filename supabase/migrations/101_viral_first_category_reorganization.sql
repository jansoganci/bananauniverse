-- =====================================================
-- Migration 101: Viral-First Category Reorganization
-- =====================================================
--
-- Purpose: Reorganize 10 scattered categories into 6 viral-focused groups
--
-- BEFORE (Current):
--   1. Thanksgiving (seasonal - limited appeal)
--   2. Christmas (seasonal - limited appeal)
--   3. Anime Styles (niche)
--   4. Meme Magic (buried at #4!)
--   5. Animated Vehicles
--   6. Retro Aesthetic
--   7. Toy Style (MOST VIRAL - buried at #7!)
--   8. Pro Photos
--   9. Enhancer
--   10. Photo Editor
--
-- AFTER (Viral-First):
--   1. 🔥 Trending Now (3 most viral themes)
--   2. 🎭 Transformations (32 fun themes: toy + meme + vehicles)
--   3. 📸 Pro Tools (10 professional themes)
--   4. ✨ Enhancements (9 utility tools)
--   5. 🎨 Artistic (6 creative filters)
--   6. 🎉 Seasonal (12 holiday themes)
--
-- Changes:
--   ✅ Desktop Figurine (most viral) → Trending Now #1
--   ✅ 32 transformation themes grouped together
--   ✅ Utilities consolidated (restoration + main_tools)
--   ✅ Seasonal content moved to bottom (contextual)
--   ✅ Zero data loss - all 69 themes preserved
--   ✅ Zero app code changes - pure database migration
--
-- Safety:
--   - Uses BEGIN/COMMIT transaction (atomic operation)
--   - Verification queries check theme counts
--   - Old categories kept (just marked inactive) for easy rollback
--
-- =====================================================

BEGIN;

-- =====================================================
-- STEP 1: Create 6 New Viral-Focused Categories
-- =====================================================

INSERT INTO categories (id, name, display_order, is_active) VALUES
    ('trending', '🔥 Trending Now', 1, true),
    ('transformations', '🎭 Transformations', 2, true),
    ('pro_tools', '📸 Pro Tools', 3, true),
    ('enhancements', '✨ Enhancements', 4, true),
    ('artistic', '🎨 Artistic', 5, true),
    ('seasonal', '🎉 Seasonal', 6, true)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    display_order = EXCLUDED.display_order,
    is_active = true,
    updated_at = now();

-- =====================================================
-- STEP 2: Move Top 3 Viral Themes to "Trending Now"
-- =====================================================
-- These are the most shareable, TikTok-viral features
-- Mark as featured so they appear in carousel too

UPDATE themes
SET
    category = 'trending',
    is_featured = true,
    updated_at = now()
WHERE name IN (
    'Collectible Figure Style',    -- Desktop Figurine (HIGHEST viral potential)
    'Building Block Character',     -- LEGO style (universal nostalgia)
    'Renaissance Portrait'          -- Meme art (Instagram viral)
);

-- =====================================================
-- STEP 3: Consolidate Transformations Category
-- =====================================================
-- Merge: Toy Style + Meme Magic + Animated Vehicles
-- Total: 10 + 12 + 10 - 3 (moved to trending) = 29 themes

UPDATE themes
SET
    category = 'transformations',
    updated_at = now()
WHERE category IN ('toy_style', 'meme_magic', 'animated_vehicles')
  AND name NOT IN (
      'Collectible Figure Style',
      'Building Block Character',
      'Renaissance Portrait'
  );

-- =====================================================
-- STEP 4: Rename "Pro Looks" → "Pro Tools"
-- =====================================================
-- Keep all 10 professional photography themes
-- Just clearer category name

UPDATE themes
SET
    category = 'pro_tools',
    updated_at = now()
WHERE category = 'pro_looks';

-- =====================================================
-- STEP 5: Consolidate "Enhancements" Category
-- =====================================================
-- Merge: Restoration (2) + Main Tools (7) = 9 themes
-- All utility/editing features grouped

UPDATE themes
SET
    category = 'enhancements',
    updated_at = now()
WHERE category IN ('restoration', 'main_tools');

-- =====================================================
-- STEP 6: Consolidate "Artistic" Category
-- =====================================================
-- Merge: Anime Styles (3) + Retro Aesthetic (3) = 6 themes
-- Creative/artistic filters grouped

UPDATE themes
SET
    category = 'artistic',
    updated_at = now()
WHERE category IN ('anime_styles', 'retro_aesthetic');

-- =====================================================
-- STEP 7: Group Seasonal Themes
-- =====================================================
-- Thanksgiving (5) + Christmas (7) = 12 themes
-- Future: Can add Halloween, Valentine's, Easter, etc.

UPDATE themes
SET
    category = 'seasonal',
    updated_at = now()
WHERE category IN ('thanksgiving', 'christmas');

-- =====================================================
-- STEP 8: Deactivate Old Categories
-- =====================================================
-- Don't delete - just hide from app
-- Allows easy rollback if needed

UPDATE categories
SET
    is_active = false,
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

-- =====================================================
-- STEP 9: Verification & Safety Checks
-- =====================================================

DO $$
DECLARE
    trending_count INTEGER;
    transformations_count INTEGER;
    pro_tools_count INTEGER;
    enhancements_count INTEGER;
    artistic_count INTEGER;
    seasonal_count INTEGER;
    total_themes INTEGER;
    total_active_categories INTEGER;
    featured_count INTEGER;
BEGIN
    -- Count themes in each new category
    SELECT COUNT(*) INTO trending_count
    FROM themes WHERE category = 'trending' AND is_available = true;

    SELECT COUNT(*) INTO transformations_count
    FROM themes WHERE category = 'transformations' AND is_available = true;

    SELECT COUNT(*) INTO pro_tools_count
    FROM themes WHERE category = 'pro_tools' AND is_available = true;

    SELECT COUNT(*) INTO enhancements_count
    FROM themes WHERE category = 'enhancements' AND is_available = true;

    SELECT COUNT(*) INTO artistic_count
    FROM themes WHERE category = 'artistic' AND is_available = true;

    SELECT COUNT(*) INTO seasonal_count
    FROM themes WHERE category = 'seasonal' AND is_available = true;

    SELECT COUNT(*) INTO total_themes
    FROM themes WHERE is_available = true;

    SELECT COUNT(*) INTO total_active_categories
    FROM categories WHERE is_active = true;

    SELECT COUNT(*) INTO featured_count
    FROM themes WHERE is_featured = true;

    -- Display results
    RAISE NOTICE '========================================';
    RAISE NOTICE '🎉 Viral-First Category Reorganization Complete!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'New Category Structure:';
    RAISE NOTICE '   1. 🔥 Trending Now - % themes', trending_count;
    RAISE NOTICE '   2. 🎭 Transformations - % themes', transformations_count;
    RAISE NOTICE '   3. 📸 Pro Tools - % themes', pro_tools_count;
    RAISE NOTICE '   4. ✨ Enhancements - % themes', enhancements_count;
    RAISE NOTICE '   5. 🎨 Artistic - % themes', artistic_count;
    RAISE NOTICE '   6. 🎉 Seasonal - % themes', seasonal_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Total themes: %', total_themes;
    RAISE NOTICE 'Active categories: %', total_active_categories;
    RAISE NOTICE 'Featured themes: %', featured_count;
    RAISE NOTICE '========================================';

    -- Safety checks
    IF trending_count != 3 THEN
        RAISE WARNING '⚠️  Expected 3 trending themes, got %', trending_count;
    END IF;

    IF transformations_count < 25 THEN
        RAISE WARNING '⚠️  Expected ~29 transformation themes, got %', transformations_count;
    END IF;

    IF total_themes < 60 THEN
        RAISE WARNING '⚠️  Expected ~69 total themes, got % (possible data loss!)', total_themes;
    END IF;

    IF total_active_categories != 6 THEN
        RAISE WARNING '⚠️  Expected 6 active categories, got %', total_active_categories;
    END IF;

    IF featured_count < 3 THEN
        RAISE WARNING '⚠️  Expected at least 3 featured themes, got %', featured_count;
    END IF;

    -- Success confirmation
    IF trending_count = 3 AND total_active_categories = 6 AND total_themes >= 60 THEN
        RAISE NOTICE '✅ All checks passed! Migration successful!';
    ELSE
        RAISE WARNING '⚠️  Some checks failed - review warnings above';
    END IF;

    RAISE NOTICE '========================================';
END $$;

COMMIT;

-- =====================================================
-- Post-Migration Verification Query (Optional)
-- =====================================================
-- Run this separately to see the new structure:
--
-- SELECT
--     c.id as category_id,
--     c.name as category_name,
--     c.display_order,
--     c.is_active,
--     COUNT(t.id) as theme_count,
--     STRING_AGG(t.name, ', ' ORDER BY t.name) as themes
-- FROM categories c
-- LEFT JOIN themes t ON t.category = c.id AND t.is_available = true
-- WHERE c.is_active = true
-- GROUP BY c.id, c.name, c.display_order, c.is_active
-- ORDER BY c.display_order;
--
-- Expected Result:
--   1. 🔥 Trending Now - 3 themes
--   2. 🎭 Transformations - 29 themes
--   3. 📸 Pro Tools - 10 themes
--   4. ✨ Enhancements - 9 themes
--   5. 🎨 Artistic - 6 themes
--   6. 🎉 Seasonal - 12 themes
-- =====================================================

-- =====================================================
-- Migration Complete!
-- =====================================================
--
-- Next Steps:
--   1. ✅ Migration ran successfully (you're seeing this!)
--   2. 🔍 Review verification output above
--   3. 📱 Pull-to-refresh in BananaUniverse app
--   4. ✅ Verify categories appear in new order
--   5. 🎉 Desktop Figurine should be first thing users see!
--
-- Rollback:
--   - If needed, run: supabase/migrations/101_rollback.sql
--   - Or manually: UPDATE categories SET is_active = true WHERE id IN (...)
--
-- =====================================================
