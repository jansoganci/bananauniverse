-- =====================================================
-- Update Category Display Order
-- =====================================================
--
-- Purpose: Reorder categories to match desired sequence
--          Categories will appear in this order in the app
--
-- New Order:
--   1. Anime Styles
--   2. Thanksgiving
--   3. Christmas
--   4. Meme Magic
--   5. Animated Vehicles
--   6. Retro Aesthetic (kept after main categories)
--   7. Toy Style (kept after main categories)
--
-- =====================================================

-- 1. Anime Styles → display_order: 1
UPDATE categories
SET display_order = 1,
    updated_at = now()
WHERE id = 'anime_styles';

-- 2. Thanksgiving → display_order: 2
UPDATE categories
SET display_order = 2,
    updated_at = now()
WHERE id = 'thanksgiving';

-- 3. Christmas → display_order: 3
UPDATE categories
SET display_order = 3,
    updated_at = now()
WHERE id = 'christmas';

-- 4. Meme Magic → display_order: 4
UPDATE categories
SET display_order = 4,
    updated_at = now()
WHERE id = 'meme_magic';

-- 5. Animated Vehicles → display_order: 5
UPDATE categories
SET display_order = 5,
    updated_at = now()
WHERE id = 'animated_vehicles';

-- 6. Retro Aesthetic → display_order: 6 (kept after main categories)
UPDATE categories
SET display_order = 6,
    updated_at = now()
WHERE id = 'retro_aesthetic';

-- 7. Toy Style → display_order: 7 (kept after main categories)
UPDATE categories
SET display_order = 7,
    updated_at = now()
WHERE id = 'toy_style';

-- =====================================================
-- Verification Query (optional - can be run separately)
-- =====================================================
-- Uncomment to verify the new order:

-- SELECT 
--     id,
--     name,
--     display_order,
--     is_active
-- FROM categories
-- WHERE is_active = true
-- ORDER BY display_order;

-- Expected Result:
--   1. Anime Styles
--   2. Thanksgiving
--   3. Christmas
--   4. Meme Magic
--   5. Animated Vehicles
--   6. Retro Aesthetic
--   7. Toy Style

-- =====================================================
-- Migration Complete!
-- =====================================================
-- 
-- Next Steps:
-- 1. Run this migration in Supabase SQL Editor
-- 2. Pull-to-refresh in your app
-- 3. Categories should appear in the new order
--
-- Note: CategoryService already sorts by display_order.asc,
--       so no code changes needed!
--
-- =====================================================

