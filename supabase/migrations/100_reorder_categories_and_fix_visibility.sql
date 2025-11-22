-- =====================================================
-- Reorder Categories and Fix Visibility
-- =====================================================
--
-- Purpose: 
--   1. Reorder categories: Thanksgiving & Christmas first, Anime 3rd
--   2. Restore themes from Migration 070 (pro_looks, restoration, main_tools)
--   3. Ensure toy_style themes are available
--   4. Add thumbnail URLs for all restored themes
--
-- New Display Order:
--   1. Thanksgiving
--   2. Christmas
--   3. Anime Styles
--   4. Meme Magic
--   5. Animated Vehicles
--   6. Retro Aesthetic
--   7. Toy Style
--   8. Pro Photos (pro_looks)
--   9. Enhancer (restoration)
--   10. Photo Editor (main_tools)
--
-- =====================================================

-- =====================================================
-- STEP 1: Reorder Categories (INSERT or UPDATE)
-- =====================================================
-- Note: Using INSERT ... ON CONFLICT to ensure categories exist

-- 1. Thanksgiving → display_order: 1
INSERT INTO categories (id, name, display_order, is_active)
VALUES ('thanksgiving', 'Thanksgiving', 1, true)
ON CONFLICT (id) DO UPDATE SET
    display_order = 1,
    is_active = true,
    updated_at = now();

-- 2. Christmas → display_order: 2
INSERT INTO categories (id, name, display_order, is_active)
VALUES ('christmas', 'Christmas', 2, true)
ON CONFLICT (id) DO UPDATE SET
    display_order = 2,
    is_active = true,
    updated_at = now();

-- 3. Anime Styles → display_order: 3
INSERT INTO categories (id, name, display_order, is_active)
VALUES ('anime_styles', 'Anime Styles', 3, true)
ON CONFLICT (id) DO UPDATE SET
    display_order = 3,
    is_active = true,
    updated_at = now();

-- 4. Meme Magic → display_order: 4
INSERT INTO categories (id, name, display_order, is_active)
VALUES ('meme_magic', 'Meme Magic', 4, true)
ON CONFLICT (id) DO UPDATE SET
    display_order = 4,
    is_active = true,
    updated_at = now();

-- 5. Animated Vehicles → display_order: 5
INSERT INTO categories (id, name, display_order, is_active)
VALUES ('animated_vehicles', 'Animated Vehicles', 5, true)
ON CONFLICT (id) DO UPDATE SET
    display_order = 5,
    is_active = true,
    updated_at = now();

-- 6. Retro Aesthetic → display_order: 6
INSERT INTO categories (id, name, display_order, is_active)
VALUES ('retro_aesthetic', 'Retro Aesthetic', 6, true)
ON CONFLICT (id) DO UPDATE SET
    display_order = 6,
    is_active = true,
    updated_at = now();

-- 7. Toy Style → display_order: 7
INSERT INTO categories (id, name, display_order, is_active)
VALUES ('toy_style', 'Toy Style', 7, true)
ON CONFLICT (id) DO UPDATE SET
    display_order = 7,
    is_active = true,
    updated_at = now();

-- 8. Pro Photos (pro_looks) → display_order: 8
INSERT INTO categories (id, name, display_order, is_active)
VALUES ('pro_looks', 'Pro Photos', 8, true)
ON CONFLICT (id) DO UPDATE SET
    display_order = 8,
    is_active = true,
    updated_at = now();

-- 9. Enhancer (restoration) → display_order: 9
INSERT INTO categories (id, name, display_order, is_active)
VALUES ('restoration', 'Enhancer', 9, true)
ON CONFLICT (id) DO UPDATE SET
    display_order = 9,
    is_active = true,
    updated_at = now();

-- 10. Photo Editor (main_tools) → display_order: 10
INSERT INTO categories (id, name, display_order, is_active)
VALUES ('main_tools', 'Photo Editor', 10, true)
ON CONFLICT (id) DO UPDATE SET
    display_order = 10,
    is_active = true,
    updated_at = now();

-- =====================================================
-- STEP 2: Restore Themes from Migration 070
-- =====================================================
-- Note: These themes were deleted in Migration 082, now restoring them

-- Storage Bucket: theme-thumbnails (public)
-- Project URL: https://jiorfutbmahpfgplkats.supabase.co

-- =====================================================
-- Restore Pro Looks Themes (10 themes)
-- =====================================================

INSERT INTO themes (name, description, category, model_name, placeholder_icon, prompt, is_featured, is_available, requires_pro, default_settings, thumbnail_url)
VALUES
    (
        'LinkedIn Headshot',
        'Professional headshots for LinkedIn',
        'pro_looks',
        'professional-headshot',
        'person.crop.square',
        'Transform this photo into a professional LinkedIn headshot with clean light and natural tone',
        true,
        true,
        false,
        '{}'::jsonb,
        'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/pro_looks_linkedin_headshot.png'
    ),
    (
        'Passport Photo',
        'Generate official passport photos',
        'pro_looks',
        'passport-photo-generator',
        'doc.text.image',
        'Generate a passport-style photo with plain background and balanced facial lighting',
        false,
        true,
        false,
        '{}'::jsonb,
        'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/pro_looks_passport_photo.png'
    ),
    (
        'Twitter/X Avatar',
        'Create eye-catching social media avatars',
        'pro_looks',
        'social-media-avatar',
        'at',
        'Create a clear, vibrant avatar optimized for small-size visibility and natural color tone',
        false,
        true,
        false,
        '{}'::jsonb,
        'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/pro_looks_twitter-x_avatar.png'
    ),
    (
        'Gradient Headshot',
        'Professional photos with gradient backgrounds',
        'pro_looks',
        'gradient-background-portrait',
        'square.split.diagonal.2x2',
        'Generate a professional headshot with a soft gradient background and balanced tone',
        false,
        true,
        false,
        '{}'::jsonb,
        'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/pro_looks_gradient_headshot.png'
    ),
    (
        'Resume Photo',
        'Professional photos for resumes and CVs',
        'pro_looks',
        'professional-resume-photo',
        'doc.plaintext',
        'Create a professional resume photo with neutral lighting and confident expression',
        false,
        true,
        false,
        '{}'::jsonb,
        'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/pro_looks_resume_photo.png'
    ),
    (
        'Slide Background Maker',
        'Create professional presentation backgrounds',
        'pro_looks',
        'presentation-background-generator',
        'rectangle.on.rectangle',
        'Design a clean, balanced slide background with good text readability and visual harmony',
        false,
        true,
        false,
        '{}'::jsonb,
        'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/pro_looks_slide_background_maker.png'
    ),
    (
        'Thumbnail Generator',
        'Create engaging video thumbnails',
        'pro_looks',
        'youtube-thumbnail-generator',
        'play.rectangle.fill',
        'Generate an engaging thumbnail with strong focus, clear subject, and bold visual contrast',
        false,
        true,
        false,
        '{}'::jsonb,
        'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/pro_looks_thumbnail_generator.png'
    ),
    (
        'CV/Portfolio Portrait',
        'Modern portfolio photos for creatives',
        'pro_looks',
        'portfolio-portrait',
        'person.text.rectangle',
        'Create a modern portfolio portrait with professional lighting and authentic expression',
        false,
        true,
        false,
        '{}'::jsonb,
        'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/pro_looks_cv-portfolio_portrait.png'
    ),
    (
        'Profile Banner Generator',
        'Create stylish profile banners',
        'pro_looks',
        'banner-generator',
        'rectangle.fill',
        'Generate a stylish banner image with balanced composition and soft background focus',
        false,
        true,
        false,
        '{}'::jsonb,
        'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/pro_looks_profile_banner_generator.png'
    ),
    (
        'Designer-Style ID Photo',
        'Contemporary ID photos with designer aesthetic',
        'pro_looks',
        'designer-id-photo',
        'person.crop.circle.badge.checkmark',
        'Create a contemporary ID photo with clean lighting and designer aesthetic',
        false,
        true,
        false,
        '{}'::jsonb,
        'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/pro_looks_designer-style_id_photo.png'
    )
ON CONFLICT (name, category) DO UPDATE SET
    is_available = true,
    thumbnail_url = EXCLUDED.thumbnail_url,
    updated_at = now();

-- =====================================================
-- Restore Restoration Themes (2 themes)
-- =====================================================

INSERT INTO themes (name, description, category, model_name, placeholder_icon, prompt, is_featured, is_available, requires_pro, default_settings, thumbnail_url)
VALUES
    (
        'Image Upscaler (2x-4x)',
        'Enhance and upscale image resolution',
        'restoration',
        'upscale',
        'arrow.up.backward.and.arrow.down.forward',
        'Enhance and upscale this image sharply, keeping all details and textures intact',
        true,
        true,
        false,
        '{}'::jsonb,
        'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/restoration_image_upscaler_(2x-4x).png'
    ),
    (
        'Historical Photo Restore',
        'Restore and colorize old photos',
        'restoration',
        'codeformer',
        'clock.arrow.circlepath',
        'Restore this old photo faithfully, preserving its original look and emotional tone',
        false,
        true,
        false,
        '{}'::jsonb,
        'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/restoration_historical_photo_restore.png'
    )
ON CONFLICT (name, category) DO UPDATE SET
    is_available = true,
    thumbnail_url = EXCLUDED.thumbnail_url,
    updated_at = now();

-- =====================================================
-- Restore Main Tools Themes (7 themes)
-- =====================================================

INSERT INTO themes (name, description, category, model_name, placeholder_icon, prompt, is_featured, is_available, requires_pro, default_settings, thumbnail_url)
VALUES
    (
        'Remove Object from Image',
        'Remove unwanted objects from your photos seamlessly',
        'main_tools',
        'lama-cleaner',
        'eraser.fill',
        'Remove the selected object naturally, keeping the background seamless and realistic',
        true,
        true,
        false,
        '{}'::jsonb,
        'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/main_tools_remove_object_from_image.png'
    ),
    (
        'Remove Background',
        'Remove image backgrounds with precision',
        'main_tools',
        'rembg',
        'scissors',
        'Remove the background cleanly, keeping edges sharp and lighting natural',
        true,
        true,
        false,
        '{}'::jsonb,
        'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/main_tools_remove_background.png'
    ),
    (
        'Put Items on Models',
        'Virtually try on clothing and accessories',
        'main_tools',
        'virtual-try-on',
        'person.crop.rectangle',
        'Place the selected item naturally on the person, matching lighting, angle, and scale',
        false,
        true,
        false,
        '{}'::jsonb,
        'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/main_tools_put_items_on_models.png'
    ),
    (
        'Add Objects to Images',
        'Add new objects to your photos realistically',
        'main_tools',
        'stable-diffusion-inpainting',
        'plus.square.fill',
        'Add the object realistically into the scene, blending light, shadow, and texture perfectly',
        false,
        true,
        false,
        '{}'::jsonb,
        'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/main_tools_add_objects_to_images.png'
    ),
    (
        'Change Image Perspectives',
        'Adjust perspective and viewing angles',
        'main_tools',
        'perspective-transform',
        'rotate.3d',
        'Adjust the image perspective realistically, keeping proportions and depth accurate',
        false,
        true,
        false,
        '{}'::jsonb,
        'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/main_tools_change_image_perspectives.png'
    ),
    (
        'Generate Image Series',
        'Create variations of your images',
        'main_tools',
        'stable-diffusion',
        'square.grid.3x3.fill',
        'Create a realistic variation of this image, keeping the subject consistent',
        false,
        true,
        false,
        '{}'::jsonb,
        'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/main_tools_generate_image_series.png'
    ),
    (
        'Style Transfers on Images',
        'Apply artistic styles to your photos',
        'main_tools',
        'neural-style',
        'paintbrush.fill',
        'Apply the selected artistic style to this image while preserving key details and structure',
        false,
        true,
        false,
        '{}'::jsonb,
        'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/main_tools_style_transfers_on_images.png'
    )
ON CONFLICT (name, category) DO UPDATE SET
    is_available = true,
    thumbnail_url = EXCLUDED.thumbnail_url,
    updated_at = now();

-- =====================================================
-- Restore Toy Style Themes (10 themes)
-- =====================================================
-- Note: Toy Style themes were added in Migration 077, but may have been affected
--       Also fixing Migration 098's category error (was 'pro_looks', should be 'toy_style')

INSERT INTO themes (name, description, category, model_name, placeholder_icon, prompt, is_featured, is_available, requires_pro, default_settings, thumbnail_url)
VALUES
    (
        'Collectible Figure Style',
        'Transform into vinyl collectible figure',
        'toy_style',
        'nano-banana/edit',
        'cube.fill',
        'Transform into collectible vinyl figure style: oversized rectangular head (1.5x body proportion), large glossy black dot eyes with white highlights, minimal facial features, chibi proportions with small body, glossy vinyl toy texture, solid vibrant color blocks, bobblehead aesthetic, centered frontal pose on display base, studio lighting with soft shadows, white background for product display, cute simplified expression, vinyl collectible toy aesthetic, premium toy photography quality, shelf-ready collectible presentation',
        true,
        true,
        false,
        '{}'::jsonb,
        'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/toy_style_collectible_figure_style.png'
    ),
    (
        'Building Block Character',
        'Classic construction toy minifigure',
        'toy_style',
        'nano-banana/edit',
        'square.stack.3d.up.fill',
        'Transform into building block minifigure: cylindrical head with simple dot eyes, C-shaped hands, rigid blocky body construction, solid primary colors (red/blue/yellow/white), plastic toy texture with slight shine, snap-together joint details visible, standing pose on baseplate, toy photography studio lighting, simple background with building blocks, cheerful smile expression, construction toy aesthetic, authentic building block proportions, playful toy character quality, iconic toy design',
        true,
        true,
        false,
        '{}'::jsonb,
        'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/toy_style_building_block_character.png'
    ),
    (
        'Action Figure Hero',
        'Poseable superhero action figure',
        'toy_style',
        'nano-banana/edit',
        'figure.arms.open',
        'Transform into action figure style: articulated joint segments visible at shoulders/elbows/knees, muscular heroic proportions (6-inch scale aesthetic), glossy painted plastic texture, bold superhero colors with panel lining, dynamic action pose, detailed sculpted costume, dramatic heroic expression, toy photography setup with action background, hard plastic material look, premium collectible quality, shelf display presentation, classic action figure aesthetic, 1/12 scale toy rendering',
        false,
        true,
        false,
        '{}'::jsonb,
        'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/toy_style_action_figure_hero.png'
    ),
    (
        'Fashion Doll Style',
        'Glamorous fashion doll aesthetic',
        'toy_style',
        'nano-banana/edit',
        'sparkles',
        'Transform into fashion doll style: large expressive eyes with long eyelashes, perfect smooth plastic skin texture, glossy styled hair with vibrant colors, slim fashion doll proportions, glamorous outfit details, rooted hair texture visible, articulated joints at shoulders/hips, standing in doll box display pose, pink gradient background, confident glamorous smile, fashion doll aesthetic, premium collector doll quality, boutique doll packaging presentation, iconic fashion toy style',
        false,
        true,
        false,
        '{}'::jsonb,
        'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/toy_style_fashion_doll_style.png'
    ),
    (
        'Plush Toy Style',
        'Soft cuddly stuffed toy transformation',
        'toy_style',
        'nano-banana/edit',
        'teddybear.fill',
        'Transform into plush toy style: soft fuzzy fabric texture throughout, embroidered simple facial features (button eyes, stitched smile), rounded soft proportions with no hard edges, pastel or warm colors, visible seam lines and stitching details, huggable stuffed appearance, sitting or standing plush pose, cozy home background, gentle friendly expression, stuffed animal aesthetic, soft toy material rendering, cuddly comfort toy quality, handmade plush charm',
        false,
        true,
        false,
        '{}'::jsonb,
        'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/toy_style_plush_toy_style.png'
    ),
    (
        'Retro Toy Robot',
        'Classic tin robot action figure',
        'toy_style',
        'nano-banana/edit',
        'robot.fill',
        'Transform into retro robot toy: vintage 1980s robot design, angular geometric shapes with panel details, metallic painted finish (silver/red/blue), visible mechanical joints and rivets, boxy proportions with antenna details, button controls and lights on chest, standing mechanical pose, retro sci-fi background, determined robot expression, vintage toy robot aesthetic, tin toy craftsmanship quality, nostalgic 80s toy collectible, classic robot toy charm',
        false,
        true,
        false,
        '{}'::jsonb,
        'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/toy_style_retro_toy_robot.png'
    ),
    (
        'Die-Cast Model Style',
        'Detailed metal model figure',
        'toy_style',
        'nano-banana/edit',
        'sparkle',
        'Transform into die-cast model style: metallic painted finish with realistic reflections, detailed sculpted features and proportions, metal toy weight and quality feel, authentic paint application (multiple colors and details), precision-molded parts with seam lines, collector display pose on stand, museum display background, serious detailed expression, premium die-cast collectible aesthetic, high-end toy photography, adult collector quality, authentic scale model rendering',
        false,
        true,
        false,
        '{}'::jsonb,
        'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/toy_style_die-cast_model_style.png'
    ),
    (
        'Wooden Toy Character',
        'Classic handcrafted wooden toy',
        'toy_style',
        'nano-banana/edit',
        'tree.fill',
        'Transform into wooden toy style: natural wood grain texture visible, simple hand-painted features with brush strokes, rounded smooth wooden shapes, warm natural wood colors with painted accents, jointed limbs connected with visible pegs, artisan craft quality, standing on wooden base, soft natural lighting, gentle friendly expression, handcrafted wooden toy aesthetic, traditional toy craftsmanship, nostalgic childhood toy quality, timeless wooden toy charm',
        false,
        true,
        false,
        '{}'::jsonb,
        'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/toy_style_wooden_toy_character.png'
    ),
    (
        'Designer Toy Art',
        'Urban vinyl art toy collectible',
        'toy_style',
        'nano-banana/edit',
        'paintpalette.fill',
        'Transform into designer art toy: artistic stylized proportions with creative exaggeration, matte or glossy vinyl texture, bold graphic design patterns, limited edition colorway aesthetic, street art and graffiti influences, unique artistic pose, modern minimalist background, creative artistic expression, urban vinyl toy aesthetic, gallery art toy quality, contemporary designer collectible, limited edition art piece rendering, museum-worthy designer toy',
        false,
        true,
        false,
        '{}'::jsonb,
        'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/toy_style_designer_toy_art.png'
    ),
    (
        'Chibi Nendoroid Style',
        'Adorable poseable chibi figure',
        'toy_style',
        'nano-banana/edit',
        'face.smiling.fill',
        'Transform into chibi figure style: super-deformed proportions (large head 1:1 with body), interchangeable facial expressions, articulated joints for posing, glossy ABS plastic finish, vibrant anime colors, detailed accessories and base stand, dynamic cute pose with effects, white studio background with soft shadows, adorable cheerful expression, Japanese chibi figure aesthetic, premium poseable figure quality, collector display presentation, maximum cuteness chibi rendering',
        false,
        true,
        false,
        '{}'::jsonb,
        'https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/toy_style_chibi_nendoroid_style.png'
    )
ON CONFLICT (name, category) DO UPDATE SET
    is_available = true,
    thumbnail_url = EXCLUDED.thumbnail_url,
    updated_at = now();

-- =====================================================
-- VERIFICATION
-- =====================================================

DO $$
DECLARE
    thanksgiving_count INTEGER;
    christmas_count INTEGER;
    anime_count INTEGER;
    meme_magic_count INTEGER;
    animated_vehicles_count INTEGER;
    retro_aesthetic_count INTEGER;
    toy_style_count INTEGER;
    pro_looks_count INTEGER;
    restoration_count INTEGER;
    main_tools_count INTEGER;
    total_active_categories INTEGER;
BEGIN
    -- Count active themes in each category
    SELECT COUNT(*) INTO thanksgiving_count
    FROM themes WHERE category = 'thanksgiving' AND is_available = true;
    
    SELECT COUNT(*) INTO christmas_count
    FROM themes WHERE category = 'christmas' AND is_available = true;
    
    SELECT COUNT(*) INTO anime_count
    FROM themes WHERE category = 'anime_styles' AND is_available = true;
    
    SELECT COUNT(*) INTO meme_magic_count
    FROM themes WHERE category = 'meme_magic' AND is_available = true;
    
    SELECT COUNT(*) INTO animated_vehicles_count
    FROM themes WHERE category = 'animated_vehicles' AND is_available = true;
    
    SELECT COUNT(*) INTO retro_aesthetic_count
    FROM themes WHERE category = 'retro_aesthetic' AND is_available = true;
    
    SELECT COUNT(*) INTO toy_style_count
    FROM themes WHERE category = 'toy_style' AND is_available = true;
    
    SELECT COUNT(*) INTO pro_looks_count
    FROM themes WHERE category = 'pro_looks' AND is_available = true;
    
    SELECT COUNT(*) INTO restoration_count
    FROM themes WHERE category = 'restoration' AND is_available = true;
    
    SELECT COUNT(*) INTO main_tools_count
    FROM themes WHERE category = 'main_tools' AND is_available = true;
    
    SELECT COUNT(*) INTO total_active_categories
    FROM categories WHERE is_active = true;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Category Reordering Complete!';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Category Order & Theme Counts:';
    RAISE NOTICE '   1. Thanksgiving - % themes', thanksgiving_count;
    RAISE NOTICE '   2. Christmas - % themes', christmas_count;
    RAISE NOTICE '   3. Anime Styles - % themes', anime_count;
    RAISE NOTICE '   4. Meme Magic - % themes', meme_magic_count;
    RAISE NOTICE '   5. Animated Vehicles - % themes', animated_vehicles_count;
    RAISE NOTICE '   6. Retro Aesthetic - % themes', retro_aesthetic_count;
    RAISE NOTICE '   7. Toy Style - % themes', toy_style_count;
    RAISE NOTICE '   8. Pro Photos (pro_looks) - % themes', pro_looks_count;
    RAISE NOTICE '   9. Enhancer (restoration) - % themes', restoration_count;
    RAISE NOTICE '   10. Photo Editor (main_tools) - % themes', main_tools_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Total active categories: %', total_active_categories;
    RAISE NOTICE '========================================';
    
    -- Warn if categories have no themes (they won't appear in app)
    IF pro_looks_count = 0 THEN
        RAISE WARNING '⚠️  pro_looks category has no active themes - will not appear in app';
    END IF;
    
    IF restoration_count = 0 THEN
        RAISE WARNING '⚠️  restoration category has no active themes - will not appear in app';
    END IF;
    
    IF main_tools_count = 0 THEN
        RAISE WARNING '⚠️  main_tools category has no active themes - will not appear in app';
    END IF;
END $$;

-- =====================================================
-- Verification Query (optional - can be run separately)
-- =====================================================
-- Uncomment to verify the new order:

-- SELECT 
--     c.id,
--     c.name,
--     c.display_order,
--     c.is_active,
--     COUNT(t.id) as theme_count
-- FROM categories c
-- LEFT JOIN themes t ON t.category = c.id AND t.is_available = true
-- WHERE c.is_active = true
-- GROUP BY c.id, c.name, c.display_order, c.is_active
-- ORDER BY c.display_order;

-- Expected Result:
--   1. Thanksgiving
--   2. Christmas
--   3. Anime Styles
--   4. Meme Magic
--   5. Animated Vehicles
--   6. Retro Aesthetic
--   7. Toy Style
--   8. Pro Photos (pro_looks)
--   9. Enhancer (restoration)
--   10. Photo Editor (main_tools)

-- =====================================================
-- Migration Complete!
-- =====================================================
-- 
-- Changes Made:
--   ✅ Categories reordered: Thanksgiving & Christmas first, Anime 3rd
--   ✅ pro_looks: 10 themes restored with thumbnails
--   ✅ restoration: 2 themes restored with thumbnails
--   ✅ main_tools: 7 themes restored with thumbnails
--   ✅ toy_style: Themes verified and activated
--
-- Note: Categories will only appear in app if they have at least 1 active theme
--       (CategoryRow hides empty categories)
--
-- Next Steps:
--   1. Run this migration in Supabase SQL Editor
--   2. Pull-to-refresh in your app
--   3. Verify categories appear in correct order
--   4. If pro_looks/restoration/main_tools still don't appear, check:
--      - Do themes exist in these categories?
--      - Are themes is_available = true?
--
-- =====================================================

