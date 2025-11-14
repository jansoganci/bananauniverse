-- =====================================================
-- Add "Retro Aesthetic" Category (Lo-Fi / Vintage)
-- =====================================================
--
-- Purpose: Transform photos into nostalgic retro aesthetics
--          Viral potential: Nostalgia content = massive engagement
--
-- Category Details:
--   id: retro_aesthetic
--   name: Retro Aesthetic
--   display_order: 8
--   is_active: true
--
-- Themes: 10 retro transformation styles
--
-- Apple Safety:
--   ✅ Generic era/style references only
--   ✅ No brand names or copyrighted material
--
-- =====================================================

-- Step 1: Insert Category
INSERT INTO categories (id, name, display_order, is_active)
VALUES ('retro_aesthetic', 'Retro Aesthetic', 8, true)
ON CONFLICT (id) 
DO UPDATE SET
    name = EXCLUDED.name,
    display_order = EXCLUDED.display_order,
    is_active = EXCLUDED.is_active,
    updated_at = now();

-- Step 2: Insert 10 Retro Style Themes
INSERT INTO themes (
    name, 
    description, 
    category, 
    model_name, 
    placeholder_icon, 
    prompt, 
    is_featured, 
    is_available, 
    requires_pro, 
    default_settings
) VALUES
    (
        'VHS 80s Aesthetic',
        'Classic 1980s VHS tape nostalgia',
        'retro_aesthetic',
        'nano-banana/edit',
        'tv.fill',
        'Transform into VHS 80s aesthetic: analog video artifacts with scan lines, color bleeding and chromatic aberration, VHS tracking noise and glitches, saturated neon colors (hot pink/electric blue/bright purple), slight motion blur and ghosting, date timestamp overlay (bottom corner), retro 80s fashion and hairstyle, grainy low-fi video quality, nostalgic home video feel, vintage camcorder lighting, authentic VHS tape degradation, warm nostalgic 1980s atmosphere',
        true,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Y2K Cyber Aesthetic',
        'Early 2000s digital culture vibes',
        'retro_aesthetic',
        'nano-banana/edit',
        'desktopcomputer',
        'Transform into Y2K aesthetic: glossy metallic textures and chrome effects, holographic rainbow gradients, pixelated digital elements and glitch art, bright cyber colors (lime green/hot pink/silver/cyan), futuristic early-2000s fashion, geometric shapes and grid patterns, digital camera flash lighting, cyber background with tech elements, confident cool expression, early internet culture aesthetic, nostalgic millennium vibes, retro-futuristic digital rendering, playful tech-optimistic mood',
        true,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Film Noir',
        'Classic black and white detective film style',
        'retro_aesthetic',
        'nano-banana/edit',
        'moon.fill',
        'Transform into film noir style: dramatic black and white with high contrast, venetian blind shadow patterns, cigarette smoke atmosphere effects, 1940s fashion and styling, dramatic side lighting creating deep shadows, rain or fog effects in background, serious mysterious expression, classic detective movie aesthetic, vintage film grain texture, cinematic noir composition, moody atmospheric lighting, timeless noir mystery mood, Hollywood golden age quality',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Polaroid Instant',
        'Vintage instant camera photograph',
        'retro_aesthetic',
        'nano-banana/edit',
        'camera.fill',
        'Transform into Polaroid instant photo: white border frame with bottom caption space, slightly faded vintage colors, soft focus with vignette edges, warm nostalgic color cast (yellow/orange tint), subtle chemical development imperfections, 1970s casual styling, soft natural lighting, simple everyday background, genuine candid expression, instant camera aesthetic, authentic Polaroid texture and grain, nostalgic family photo feel, timeless captured moment quality',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Vintage Film Photography',
        'Classic 35mm film camera aesthetic',
        'retro_aesthetic',
        'nano-banana/edit',
        'film.fill',
        'Transform into vintage film photography: authentic film grain texture, rich warm color palette (amber/sepia/muted tones), slight light leaks and lens flares, natural vignetting on edges, soft focus with shallow depth of field, classic film stock color science, natural vintage lighting, timeless everyday setting, authentic genuine expression, 35mm analog camera aesthetic, professional film photography quality, nostalgic artistic mood, timeless photographic beauty',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Lo-Fi Aesthetic',
        'Chill relaxed lo-fi art style',
        'retro_aesthetic',
        'nano-banana/edit',
        'music.note',
        'Transform into lo-fi aesthetic: soft pastel color grading (muted pinks/blues/purples), gentle grain and noise texture, dreamy soft focus, cozy relaxed atmosphere, warm ambient lighting, simple minimalist composition, chill study vibes background elements, peaceful content expression, lo-fi hip hop aesthetic, illustrated artistic style, comfortable laid-back mood, modern nostalgia feel, relaxing chill vibe rendering, calm peaceful atmosphere',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        '90s Disposable Camera',
        'Carefree 1990s snapshot vibe',
        'retro_aesthetic',
        'nano-banana/edit',
        'camera.viewfinder',
        'Transform into 90s disposable camera style: bright flash on-camera lighting, slightly overexposed highlights, dated color science (warm yellows/cool shadows), casual spontaneous composition, authentic film grain, 90s fashion and styling, everyday party or hangout setting, genuine carefree smile, disposable camera aesthetic, nostalgic 90s snapshot quality, fun spontaneous energy, authentic moment captured, youthful carefree 90s vibe',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Sepia Vintage Portrait',
        'Classic early photography sepia tone',
        'retro_aesthetic',
        'nano-banana/edit',
        'photo.on.rectangle',
        'Transform into sepia vintage portrait: monochrome sepia tone (warm brown gradients), aged photograph texture with subtle cracks, soft vignette darkening edges, Victorian or early 1900s styling, formal portrait composition with centered framing, studio lighting from window, dignified formal expression, antique photograph aesthetic, paper texture and aging effects, timeless historical portrait quality, elegant vintage dignity, museum-quality historical photograph',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Retro Magazine Cover',
        'Vintage fashion magazine aesthetic',
        'retro_aesthetic',
        'nano-banana/edit',
        'magazine.fill',
        'Transform into retro magazine cover: bold graphic layout with vintage typography space, saturated vintage color palette (teal/orange/red/cream), professional studio portrait lighting, glamorous styling and makeup, 1960s-70s fashion aesthetic, clean white or colored background, confident editorial expression, vintage Vogue aesthetic, high-quality editorial photography, timeless fashion photography composition, classic magazine cover elegance, professional editorial quality',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Faded Summer Memory',
        'Sun-bleached nostalgic summer photo',
        'retro_aesthetic',
        'nano-banana/edit',
        'sun.max.fill',
        'Transform into faded summer memory: sun-bleached washed out colors, hazy soft focus with dream-like quality, warm golden hour lighting, slight overexposure creating ethereal glow, vintage 70s summer fashion, beach or outdoor summer setting, nostalgic carefree smile, faded photograph aesthetic, gentle film grain texture, timeless summer nostalgia mood, warm peaceful atmosphere, bittersweet memory quality, golden age summer feeling',
        false,
        true,
        false,
        '{}'::jsonb
    )
ON CONFLICT (name, category) DO NOTHING;

-- =====================================================
-- Migration Complete!
-- =====================================================
-- 
-- Added:
--   - Category: "Retro Aesthetic" (display_order: 8)
--   - 10 retro transformation themes
--   - 2 featured themes (VHS 80s + Y2K)
--
-- Expected Impact: 🔥 HIGH ENGAGEMENT
--   - Nostalgia content performs exceptionally well
--   - Multiple era options (80s, 90s, Y2K, vintage)
--   - High shareability across age demographics
--
-- =====================================================

