-- =====================================================
-- Seed Themes Table with Existing Tools
-- =====================================================
--
-- Purpose: Migrate all existing tools from Tool.swift static
--          arrays into the themes database table
--
-- Source: BananaUniverse/Core/Models/Tool.swift
-- Total Tools: 30+
--
-- Featured Strategy:
-- - 2 main tools
-- - 1 seasonal tool
-- - 1 pro tool
-- - 1 restoration tool
-- =====================================================

-- Insert Main Tools (7 tools, 2 featured)
INSERT INTO themes (name, description, category, model_name, placeholder_icon, prompt, is_featured, is_available, requires_pro, default_settings)
VALUES
    (
        'Remove Object from Image',
        'Remove unwanted objects from your photos seamlessly',
        'main_tools',
        'lama-cleaner',
        'eraser.fill',
        'Remove the selected object naturally, keeping the background seamless and realistic',
        true,  -- Featured
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Remove Background',
        'Remove image backgrounds with precision',
        'main_tools',
        'rembg',
        'scissors',
        'Remove the background cleanly, keeping edges sharp and lighting natural',
        true,  -- Featured
        true,
        false,
        '{}'::jsonb
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
        '{}'::jsonb
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
        '{}'::jsonb
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
        '{}'::jsonb
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
        '{}'::jsonb
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
        '{}'::jsonb
    );

-- Insert Pro Looks Tools (10 tools, 1 featured)
INSERT INTO themes (name, description, category, model_name, placeholder_icon, prompt, is_featured, is_available, requires_pro, default_settings)
VALUES
    (
        'LinkedIn Headshot',
        'Professional headshots for LinkedIn',
        'pro_looks',
        'professional-headshot',
        'person.crop.square',
        'Transform this photo into a professional LinkedIn headshot with clean light and natural tone',
        true,  -- Featured
        true,
        false,
        '{}'::jsonb
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
        '{}'::jsonb
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
        '{}'::jsonb
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
        '{}'::jsonb
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
        '{}'::jsonb
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
        '{}'::jsonb
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
        '{}'::jsonb
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
        '{}'::jsonb
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
        '{}'::jsonb
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
        '{}'::jsonb
    );

-- Insert Restoration Tools (2 tools, 1 featured)
INSERT INTO themes (name, description, category, model_name, placeholder_icon, prompt, is_featured, is_available, requires_pro, default_settings)
VALUES
    (
        'Image Upscaler (2x-4x)',
        'Enhance and upscale image resolution',
        'restoration',
        'upscale',
        'arrow.up.backward.and.arrow.down.forward',
        'Enhance and upscale this image sharply, keeping all details and textures intact',
        true,  -- Featured
        true,
        false,
        '{}'::jsonb
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
        '{}'::jsonb
    );

-- Insert Seasonal Tools (9 tools, 1 featured for current season)
INSERT INTO themes (name, description, category, model_name, placeholder_icon, prompt, is_featured, is_available, requires_pro, default_settings)
VALUES
    -- Thanksgiving Tools
    (
        'Thanksgiving Magic Edit',
        'Add warm thanksgiving atmosphere to photos',
        'seasonal',
        'nano-banana/edit',
        'leaf.fill',
        'Transform this image with warm thanksgiving atmosphere, adding autumn colors, cozy lighting, and festive thanksgiving elements while maintaining natural realism',
        false,  -- Not featured by default (seasonal)
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Thanksgiving Family Portrait',
        'Create warm family portraits with thanksgiving vibes',
        'seasonal',
        'nano-banana/edit',
        'person.3.fill',
        'Create a warm family portrait with thanksgiving setting, soft autumn lighting, and cozy family gathering atmosphere',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Autumn Color Enhancer',
        'Enhance photos with beautiful autumn colors',
        'seasonal',
        'nano-banana/edit',
        'paintpalette.fill',
        'Enhance this image with beautiful autumn colors, warm golden tones, and seasonal foliage effects',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    -- Christmas Tools
    (
        'Christmas Magic Edit',
        'Add magical christmas elements to photos',
        'seasonal',
        'nano-banana/edit',
        'gift.fill',
        'Add magical christmas elements to this image - snow, warm lights, festive decorations, and holiday magic while keeping it natural and realistic',
        true,  -- Featured (current season)
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Holiday Portrait',
        'Create beautiful holiday portraits',
        'seasonal',
        'nano-banana/edit',
        'star.fill',
        'Transform into a beautiful holiday portrait with festive lighting, warm winter atmosphere, and elegant holiday styling',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Winter Wonderland',
        'Create magical winter scenes',
        'seasonal',
        'nano-banana/edit',
        'snowflake',
        'Create a magical winter wonderland scene with realistic snow, winter lighting, and enchanting seasonal atmosphere',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Santa Hat Overlay',
        'Add festive Santa hats to photos',
        'seasonal',
        'nano-banana/edit',
        'person.crop.circle.badge.plus',
        'Add a festive Santa hat naturally to the person in this image, matching lighting and perspective perfectly',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    -- New Year Tools
    (
        'New Year Glamour',
        'Create glamorous new year portraits',
        'seasonal',
        'nano-banana/edit',
        'sparkles',
        'Create a glamorous new year portrait with celebration lighting, elegant styling, and festive party atmosphere',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Confetti Celebration',
        'Add festive confetti to celebration photos',
        'seasonal',
        'nano-banana/edit',
        'party.popper.fill',
        'Add festive confetti and celebration elements to this image with realistic lighting and natural integration',
        false,
        true,
        false,
        '{}'::jsonb
    );

-- Verify seeding
-- Expected: 28 total tools
--   - 7 main_tools (2 featured)
--   - 10 pro_looks (1 featured)
--   - 2 restoration (1 featured)
--   - 9 seasonal (1 featured)
--   Total featured: 5 tools

-- Query to verify counts
DO $$
DECLARE
    total_count INTEGER;
    featured_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO total_count FROM themes;
    SELECT COUNT(*) INTO featured_count FROM themes WHERE is_featured = true;

    RAISE NOTICE 'Themes seeded successfully!';
    RAISE NOTICE 'Total themes: %', total_count;
    RAISE NOTICE 'Featured themes: %', featured_count;
    RAISE NOTICE 'Expected: 28 total, 5 featured';
END $$;
