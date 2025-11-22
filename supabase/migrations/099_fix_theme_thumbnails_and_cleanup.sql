-- =====================================================
-- Fix Theme Thumbnails and Cleanup
-- =====================================================
--
-- Purpose: 
--   1. Add full URL for Autumn Harvest Magic thumbnail
--   2. Delete Green Ogre Fantasy theme from meme_magic
--   3. Verify/activate Off-Road Explorer in animated_vehicles
--   4. Add full URLs for Pop Art Style, Surreal Dream Art, and Lowbrow Pop Surrealism
--
-- Storage Bucket: theme-thumbnails (public)
-- Project URL: https://jiorfutbmahpfgplkats.supabase.co
--
-- =====================================================

-- 1. Update Autumn Harvest Magic with full URL
UPDATE themes
SET thumbnail_url = 'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/thanksgiving_autumn_harvest_magic.png',
    updated_at = now()
WHERE name = 'Autumn Harvest Magic' AND category = 'seasonal';

-- 2. Delete Green Ogre Fantasy from meme_magic category
DELETE FROM themes
WHERE name = 'Green Ogre Fantasy' AND category = 'meme_magic';

-- 3. Verify and ensure Off-Road Explorer is active
-- First, check if it exists and make sure it's available
UPDATE themes
SET is_available = true,
    updated_at = now()
WHERE name = 'Off-Road Explorer' AND category = 'animated_vehicles';

-- Also ensure thumbnail URL is set correctly
UPDATE themes
SET thumbnail_url = 'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/animated_vehicles_off_road_truck.png',
    updated_at = now()
WHERE name = 'Off-Road Explorer' AND category = 'animated_vehicles';

-- 4. Update Pop Art Style with full URL
UPDATE themes
SET thumbnail_url = 'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/meme_magic_pop_art_style.png',
    updated_at = now()
WHERE name = 'Pop Art Style' AND category = 'pro_looks';

-- 5. Update Surreal Dream Art with full URL
UPDATE themes
SET thumbnail_url = 'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/meme_magic_surreal_dream_art.png',
    updated_at = now()
WHERE name = 'Surreal Dream Art' AND category = 'pro_looks';

-- 6. Update Lowbrow Pop Surrealism with full URL
UPDATE themes
SET thumbnail_url = 'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/meme_magic_lowbrow_pop_surrealism.png',
    updated_at = now()
WHERE name = 'Lowbrow Pop Surrealism' AND category = 'pro_looks';

-- =====================================================
-- Verification Queries (optional - can be run separately)
-- =====================================================

-- Verify Autumn Harvest Magic has thumbnail
-- SELECT 
--     name,
--     category,
--     thumbnail_url,
--     CASE 
--         WHEN thumbnail_url LIKE 'https://%' THEN '✅ Full URL set'
--         WHEN thumbnail_url IS NOT NULL THEN '⚠️ Partial URL'
--         ELSE '❌ No thumbnail'
--     END as status
-- FROM themes 
-- WHERE name = 'Autumn Harvest Magic';

-- Verify Green Ogre Fantasy is deleted
-- SELECT COUNT(*) as count
-- FROM themes 
-- WHERE name = 'Green Ogre Fantasy' AND category = 'meme_magic';
-- -- Should return 0

-- Verify Off-Road Explorer is active
-- SELECT 
--     name,
--     category,
--     is_available,
--     thumbnail_url,
--     CASE 
--         WHEN is_available = true AND thumbnail_url IS NOT NULL THEN '✅ Active with thumbnail'
--         WHEN is_available = true THEN '⚠️ Active but no thumbnail'
--         ELSE '❌ Not available'
--     END as status
-- FROM themes 
-- WHERE name = 'Off-Road Explorer' AND category = 'animated_vehicles';

-- Verify Pop Art Style, Surreal Dream Art, and Lowbrow Pop Surrealism have full URLs
-- SELECT 
--     name,
--     category,
--     thumbnail_url,
--     CASE 
--         WHEN thumbnail_url LIKE 'https://%' THEN '✅ Full URL set'
--         WHEN thumbnail_url IS NOT NULL THEN '⚠️ Partial URL'
--         ELSE '❌ No thumbnail'
--     END as status
-- FROM themes 
-- WHERE name IN ('Pop Art Style', 'Surreal Dream Art', 'Lowbrow Pop Surrealism') 
--   AND category = 'pro_looks';

-- =====================================================
-- Migration Complete!
-- =====================================================
-- 
-- Changes Made:
--   ✅ Autumn Harvest Magic: Full thumbnail URL added
--   ✅ Green Ogre Fantasy: Deleted from meme_magic
--   ✅ Off-Road Explorer: Verified active with thumbnail
--   ✅ Pop Art Style: Full thumbnail URL added
--   ✅ Surreal Dream Art: Full thumbnail URL added
--   ✅ Lowbrow Pop Surrealism: Full thumbnail URL added
--
-- Next Steps:
--   1. Run this migration in Supabase SQL Editor
--   2. Pull-to-refresh in your app
--   3. Verify all thumbnails load correctly
--
-- =====================================================

