-- =====================================================
-- Add Thumbnail URLs for Animated Vehicles Category
-- =====================================================
--
-- Purpose: Update all 10 themes in "animated_vehicles" category
--          with their thumbnail image URLs from Supabase Storage
--
-- Storage Bucket: theme-thumbnails (public)
-- Project URL: https://jiorfutbmahpfgplkats.supabase.co
--
-- =====================================================

-- 1. Friendly Car Eyes
UPDATE themes
SET thumbnail_url = 'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/animated_vehicles_friendly_car_eyes.png',
    updated_at = now()
WHERE name = 'Friendly Car Eyes' AND category = 'animated_vehicles';

-- 2. Racing Champion
UPDATE themes
SET thumbnail_url = 'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/animated_vehicles_racing_champion.png',
    updated_at = now()
WHERE name = 'Racing Champion' AND category = 'animated_vehicles';

-- 3. Vintage Cartoon Car
UPDATE themes
SET thumbnail_url = 'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/animated_vehicles_vintage_cartoon_car.png',
    updated_at = now()
WHERE name = 'Vintage Cartoon Car' AND category = 'animated_vehicles';

-- 4. Monster Truck Toon
UPDATE themes
SET thumbnail_url = 'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/animated_vehicles_monster_truck_toon.png',
    updated_at = now()
WHERE name = 'Monster Truck Toon' AND category = 'animated_vehicles';

-- 5. Friendly Bus
UPDATE themes
SET thumbnail_url = 'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/animated_vehicles_friendly_bus.png',
    updated_at = now()
WHERE name = 'Friendly Bus' AND category = 'animated_vehicles';

-- 6. Sports Car Hero
UPDATE themes
SET thumbnail_url = 'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/animated_vehicles_sports_car_hero.png',
    updated_at = now()
WHERE name = 'Sports Car Hero' AND category = 'animated_vehicles';

-- 7. Cartoon Truck
UPDATE themes
SET thumbnail_url = 'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/animated_vehicles_cartoon_truck.png',
    updated_at = now()
WHERE name = 'Cartoon Truck' AND category = 'animated_vehicles';

-- 8. Off-Road Explorer
-- Note: File name is "off_road_truck" but theme name is "Off-Road Explorer"
UPDATE themes
SET thumbnail_url = 'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/animated_vehicles_off_road_truck.png',
    updated_at = now()
WHERE name = 'Off-Road Explorer' AND category = 'animated_vehicles';

-- 9. Classic Roadster
UPDATE themes
SET thumbnail_url = 'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/animated_vehicles_classic_roadster.png',
    updated_at = now()
WHERE name = 'Classic Roadster' AND category = 'animated_vehicles';

-- 10. Rally Racer
UPDATE themes
SET thumbnail_url = 'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/animated_vehicles_rally_racer.png',
    updated_at = now()
WHERE name = 'Rally Racer' AND category = 'animated_vehicles';

-- =====================================================
-- Verification Query (optional - can be run separately)
-- =====================================================
-- Uncomment to verify all thumbnails are set:

-- SELECT 
--     name,
--     category,
--     thumbnail_url,
--     CASE 
--         WHEN thumbnail_url IS NOT NULL THEN '✅ Has thumbnail'
--         ELSE '❌ Missing thumbnail'
--     END as status
-- FROM themes 
-- WHERE category = 'animated_vehicles'
-- ORDER BY name;

-- =====================================================
-- Migration Complete!
-- =====================================================
-- 
-- Next Steps:
-- 1. Run this migration in Supabase SQL Editor
-- 2. Pull-to-refresh in your app
-- 3. Thumbnail images should appear in theme cards
--
-- Expected Result:
--   - All 10 themes in "animated_vehicles" category have thumbnail_url set
--   - Images will load via AsyncImage in ToolCard component
--   - Fallback to SF Symbol if image fails to load
--
-- =====================================================

