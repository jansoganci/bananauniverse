-- =====================================================
-- Add Theme Thumbnails for Categories 7-11
-- =====================================================
--
-- Purpose: Update themes table with thumbnail URLs for:
--   - Section 7: Retro Aesthetic (7.2-7.10)
--   - Section 8: Toy Style (8.1-8.10)
--   - Section 9: Meme Magic (9.1-9.12, excluding 9.7)
--   - Section 10: Thanksgiving (10.1-10.5)
--   - Section 11: Christmas (11.1-11.5)
--
-- Note: Thumbnails should be uploaded to Supabase Storage
--       at path: /theme-thumbnails/{filename}
--       This migration assumes the base URL structure.
--
-- =====================================================

-- Section 7: RETRO AESTHETIC (7.2-7.10)

UPDATE themes
SET thumbnail_url = 'retro_aesthetic_y2k_cyber_aesthetic.png'
WHERE name = 'Y2K Cyber Aesthetic' AND category = 'pro_looks';

UPDATE themes
SET thumbnail_url = 'retro_aesthetic_film_noir.png'
WHERE name = 'Film Noir' AND category = 'pro_looks';

UPDATE themes
SET thumbnail_url = 'retro_aesthetic_polaroid_instant.png'
WHERE name = 'Polaroid Instant' AND category = 'pro_looks';

UPDATE themes
SET thumbnail_url = 'retro_aesthetic_vintage_film_photography.png'
WHERE name = 'Vintage Film Photography' AND category = 'pro_looks';

UPDATE themes
SET thumbnail_url = 'retro_aesthetic_lo-fi_aesthetic.png'
WHERE name = 'Lo-Fi Aesthetic' AND category = 'pro_looks';

UPDATE themes
SET thumbnail_url = 'retro_aesthetic_90s_disposable_camera.png'
WHERE name = '90s Disposable Camera' AND category = 'pro_looks';

UPDATE themes
SET thumbnail_url = 'retro_aesthetic_sepia_vintage_portrait.png'
WHERE name = 'Sepia Vintage Portrait' AND category = 'pro_looks';

UPDATE themes
SET thumbnail_url = 'retro_aesthetic_retro_magazine_cover.png'
WHERE name = 'Retro Magazine Cover' AND category = 'pro_looks';

UPDATE themes
SET thumbnail_url = 'retro_aesthetic_faded_summer_memory.png'
WHERE name = 'Faded Summer Memory' AND category = 'pro_looks';

-- Section 8: TOY STYLE (8.1-8.10)

UPDATE themes
SET thumbnail_url = 'toy_style_collectible_figure_style.png'
WHERE name = 'Collectible Figure Style' AND category = 'pro_looks';

UPDATE themes
SET thumbnail_url = 'toy_style_building_block_character.png'
WHERE name = 'Building Block Character' AND category = 'pro_looks';

UPDATE themes
SET thumbnail_url = 'toy_style_action_figure_hero.png'
WHERE name = 'Action Figure Hero' AND category = 'pro_looks';

UPDATE themes
SET thumbnail_url = 'toy_style_fashion_doll_style.png'
WHERE name = 'Fashion Doll Style' AND category = 'pro_looks';

UPDATE themes
SET thumbnail_url = 'toy_style_plush_toy_style.png'
WHERE name = 'Plush Toy Style' AND category = 'pro_looks';

UPDATE themes
SET thumbnail_url = 'toy_style_retro_toy_robot.png'
WHERE name = 'Retro Toy Robot' AND category = 'pro_looks';

UPDATE themes
SET thumbnail_url = 'toy_style_die-cast_model_style.png'
WHERE name = 'Die-Cast Model Style' AND category = 'pro_looks';

UPDATE themes
SET thumbnail_url = 'toy_style_wooden_toy_character.png'
WHERE name = 'Wooden Toy Character' AND category = 'pro_looks';

UPDATE themes
SET thumbnail_url = 'toy_style_designer_toy_art.png'
WHERE name = 'Designer Toy Art' AND category = 'pro_looks';

UPDATE themes
SET thumbnail_url = 'toy_style_chibi_nendoroid_style.png'
WHERE name = 'Chibi Nendoroid Style' AND category = 'pro_looks';

-- Section 9: MEME MAGIC (9.1-9.12, excluding 9.7 Green Ogre Fantasy)

UPDATE themes
SET thumbnail_url = 'meme_magic_renaissance_portrait.png'
WHERE name = 'Renaissance Portrait' AND category = 'pro_looks';

UPDATE themes
SET thumbnail_url = 'meme_magic_medieval_painting.png'
WHERE name = 'Medieval Painting' AND category = 'pro_looks';

UPDATE themes
SET thumbnail_url = 'meme_magic_pop_art_style.png'
WHERE name = 'Pop Art Style' AND category = 'pro_looks';

UPDATE themes
SET thumbnail_url = 'meme_magic_comic_book_hero.png'
WHERE name = 'Comic Book Hero' AND category = 'pro_looks';

UPDATE themes
SET thumbnail_url = 'meme_magic_pixel_art_retro.png'
WHERE name = 'Pixel Art Retro' AND category = 'pro_looks';

UPDATE themes
SET thumbnail_url = 'meme_magic_yellow_animated_family.png'
WHERE name = 'Yellow Animated Family' AND category = 'pro_looks';

-- 9.7 Green Ogre Fantasy is intentionally skipped (deleted from documentation)

UPDATE themes
SET thumbnail_url = 'meme_magic_impressionist_painting.png'
WHERE name = 'Impressionist Painting' AND category = 'pro_looks';

UPDATE themes
SET thumbnail_url = 'meme_magic_surreal_dream_art.png'
WHERE name = 'Surreal Dream Art' AND category = 'pro_looks';

UPDATE themes
SET thumbnail_url = 'meme_magic_vaporwave_aesthetic.png'
WHERE name = 'Vaporwave Aesthetic' AND category = 'pro_looks';

UPDATE themes
SET thumbnail_url = 'meme_magic_cubist_portrait.png'
WHERE name = 'Cubist Portrait' AND category = 'pro_looks';

UPDATE themes
SET thumbnail_url = 'meme_magic_lowbrow_pop_surrealism.png'
WHERE name = 'Lowbrow Pop Surrealism' AND category = 'pro_looks';

-- Section 10: THANKSGIVING (10.1-10.5)

UPDATE themes
SET thumbnail_url = 'thanksgiving_thanksgiving_feast_portrait.png'
WHERE name = 'Thanksgiving Feast Portrait' AND category = 'seasonal';

UPDATE themes
SET thumbnail_url = 'thanksgiving_autumn_harvest_magic.png'
WHERE name = 'Autumn Harvest Magic' AND category = 'seasonal';

UPDATE themes
SET thumbnail_url = 'thanksgiving_cozy_autumn_hearth.png'
WHERE name = 'Cozy Autumn Hearth' AND category = 'seasonal';

UPDATE themes
SET thumbnail_url = 'thanksgiving_grateful_heart_portrait.png'
WHERE name = 'Grateful Heart Portrait' AND category = 'seasonal';

UPDATE themes
SET thumbnail_url = 'thanksgiving_pumpkin_patch_charm.png'
WHERE name = 'Pumpkin Patch Charm' AND category = 'seasonal';

-- Section 11: CHRISTMAS (11.1-11.5)

UPDATE themes
SET thumbnail_url = 'christmas_christmas_card_portrait.png'
WHERE name = 'Christmas Card Portrait' AND category = 'seasonal';

UPDATE themes
SET thumbnail_url = 'christmas_christmas_magic_sparkle.png'
WHERE name = 'Christmas Magic Sparkle' AND category = 'seasonal';

UPDATE themes
SET thumbnail_url = 'christmas_frosty_winter_wonderland.png'
WHERE name = 'Frosty Winter Wonderland' AND category = 'seasonal';

UPDATE themes
SET thumbnail_url = 'christmas_christmas_lights_glow.png'
WHERE name = 'Christmas Lights Glow' AND category = 'seasonal';

UPDATE themes
SET thumbnail_url = 'christmas_vintage_christmas_nostalgia.png'
WHERE name = 'Vintage Christmas Nostalgia' AND category = 'seasonal';

-- Verification: Count updated themes
DO $$
DECLARE
    updated_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO updated_count
    FROM themes
    WHERE thumbnail_url IS NOT NULL
    AND thumbnail_url != '';

    RAISE NOTICE 'Total themes with thumbnails: %', updated_count;
END $$;

-- Done! Theme thumbnails have been added.
-- Next steps:
-- 1. Upload thumbnail images to Supabase Storage bucket 'theme-thumbnails'
-- 2. Update thumbnail_url with full storage URLs if needed
-- 3. Test thumbnail loading in the app
