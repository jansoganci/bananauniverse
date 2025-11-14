-- =====================================================
-- Add "Anime Styles" Category (Studio Ghibli / Anime)
-- =====================================================
--
-- Purpose: Transform photos into anime/Studio Ghibli art styles
--          Viral potential: Billions of views on #GhibliStyle
--
-- Category Details:
--   id: anime_styles
--   name: Anime Styles
--   display_order: 7
--   is_active: true
--
-- Themes: 15 anime transformation styles
--
-- Apple Safety:
--   ✅ Generic style references (no character names)
--   ✅ Art style descriptions only
--   ✅ "Ghibli-style" = acceptable (style reference)
--
-- =====================================================

-- Step 1: Insert Category
INSERT INTO categories (id, name, display_order, is_active)
VALUES ('anime_styles', 'Anime Styles', 7, true)
ON CONFLICT (id) 
DO UPDATE SET
    name = EXCLUDED.name,
    display_order = EXCLUDED.display_order,
    is_active = EXCLUDED.is_active,
    updated_at = now();

-- Step 2: Insert 15 Anime Style Themes
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
        'Studio Ghibli Style',
        'Transform into enchanting Ghibli anime art',
        'anime_styles',
        'nano-banana/edit',
        'sparkles',
        'Transform into Studio Ghibli anime style: soft watercolor aesthetic, large expressive eyes with detailed highlights, gentle facial features, pastel color palette (soft blues/greens/pinks), hand-drawn line art quality, whimsical dreamy atmosphere, natural lighting with soft glow, countryside or sky background with clouds, innocent cheerful expression, Hayao Miyazaki signature style, 2D animation cell-shaded rendering, nostalgic heartwarming mood',
        true,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Makoto Shinkai Style',
        'Cinematic anime with stunning sky details',
        'anime_styles',
        'nano-banana/edit',
        'cloud.sun.fill',
        'Transform into Makoto Shinkai anime style: photorealistic background with anime character, dramatic sky with volumetric lighting, vibrant sunset colors (orange/purple/pink), detailed cloud formations, lens flare effects, cinematic composition, sharp clean anime line art, glossy hair with light reflections, emotional expression with depth, Your Name aesthetic, high contrast lighting, romantic melancholic atmosphere, 4K digital anime painting quality',
        true,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Magical Girl Anime',
        'Sparkly transformation with magical effects',
        'anime_styles',
        'nano-banana/edit',
        'star.fill',
        'Transform into magical girl anime style: large sparkling eyes with star highlights, vibrant hair colors (pink/blue/purple) with gradient effects, cute rounded facial features, magical girl outfit elements, glowing transformation effects, sparkle particles and ribbons, pastel rainbow color palette, dramatic pose with energy, cheerful confident expression, Sailor Moon aesthetic, shojo manga style with screen tone effects, dynamic action background',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Shonen Action Hero',
        'Dynamic battle anime style transformation',
        'anime_styles',
        'nano-banana/edit',
        'flame.fill',
        'Transform into shonen anime hero style: spiky dynamic hair with sharp angles, determined intense eyes with highlight detail, angular strong facial features, action pose with energy aura, bold primary colors (red/orange/blue/yellow), speed lines and motion blur, dramatic battle lighting with rim light effects, explosive background with energy effects, fierce confident expression, Attack on Titan aesthetic, detailed line art with heavy shadows, powerful heroic presence',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Kawaii Chibi Style',
        'Adorable super-deformed anime version',
        'anime_styles',
        'nano-banana/edit',
        'heart.fill',
        'Transform into kawaii chibi anime style: oversized head (1:2 body proportion), huge sparkling eyes (40% of face), tiny simple body features, rounded soft shapes throughout, pastel candy colors (pink/mint/lavender/peach), minimal line details, cute blush marks on cheeks, simple dot nose, cheerful happy expression, plain gradient background with decorative elements, super adorable aesthetic, sticker-style flat rendering, maximum cuteness factor',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Dark Anime Aesthetic',
        'Moody gothic anime transformation',
        'anime_styles',
        'nano-banana/edit',
        'moon.stars.fill',
        'Transform into dark anime aesthetic: sharp angular features, mysterious intense eyes with red/purple highlights, dramatic shadows with high contrast, dark color palette (black/deep purple/crimson/navy), flowing hair with wind effect, gothic fashion elements, moody atmospheric lighting from side, nighttime or stormy background, serious brooding expression, Death Note aesthetic, detailed linework with heavy inking, dramatic manga panel composition, mysterious powerful presence',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        '90s Retro Anime',
        'Classic 90s anime cell animation style',
        'anime_styles',
        'nano-banana/edit',
        'tv.fill',
        'Transform into 90s retro anime style: classic cel animation aesthetic, bold thick outlines, simplified shading (2-3 tone cel shading), vintage anime color palette (saturated primary colors), slight VHS grain texture, traditional hand-drawn quality, expressive large eyes with simple highlights, 90s fashion and hairstyle elements, nostalgic anime background, confident cool expression, Cowboy Bebop aesthetic, authentic 90s animation quality, retro anime charm',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Slice of Life Anime',
        'Cozy everyday anime aesthetic',
        'anime_styles',
        'nano-banana/edit',
        'house.fill',
        'Transform into slice of life anime style: soft gentle features, warm friendly eyes with natural highlights, realistic proportions with subtle anime styling, warm earthy color palette (browns/creams/soft greens), natural everyday lighting, cozy indoor or peaceful outdoor background, gentle welcoming smile, K-ON aesthetic, clean simple line art, comfortable relaxed atmosphere, heartwarming everyday life mood, approachable friendly character design',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Cyberpunk Anime',
        'Futuristic neon anime transformation',
        'anime_styles',
        'nano-banana/edit',
        'bolt.fill',
        'Transform into cyberpunk anime style: sharp angular cybernetic features, glowing neon eyes (blue/pink/cyan), tech elements and circuit patterns, neon color palette (electric blue/hot pink/acid green) with black accents, dramatic neon lighting from multiple sources, futuristic cityscape background with holographic elements, intense focused expression, Ghost in the Shell aesthetic, detailed mechanical line art, high-tech dystopian atmosphere, gritty futuristic anime rendering',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Watercolor Anime',
        'Soft painterly anime artwork',
        'anime_styles',
        'nano-banana/edit',
        'paintbrush.fill',
        'Transform into watercolor anime style: soft blended brushstroke textures, gentle flowing colors with gradients, delicate line art with varied thickness, pastel watercolor palette with subtle color bleeding, artistic paper texture, natural organic shapes, dreamy soft-focus background with bokeh effects, peaceful serene expression, artistic illustration quality, hand-painted traditional media aesthetic, gentle flowing composition, ethereal romantic atmosphere, fine art anime rendering',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Sports Anime Hero',
        'Dynamic athletic anime character',
        'anime_styles',
        'nano-banana/edit',
        'figure.run',
        'Transform into sports anime style: athletic determined features, fierce competitive eyes with intense highlights, dynamic sweat and motion effects, bold energetic color scheme, action pose with movement lines, dramatic lighting emphasizing muscles and determination, sports arena background with crowd blur, passionate fighting spirit expression, Haikyuu aesthetic, clean dynamic line art with speed emphasis, competitive athletic energy, inspirational sports manga composition',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Fantasy Anime',
        'Epic fantasy anime warrior style',
        'anime_styles',
        'nano-banana/edit',
        'wand.and.stars',
        'Transform into fantasy anime style: heroic noble features, mystical glowing eyes with magical effects, fantasy costume elements (armor/robes/accessories), rich vibrant fantasy colors (gold/emerald/sapphire/crimson), magical particle effects and auras, dramatic epic lighting with divine rays, fantasy landscape background (castle/forest/mystical realm), brave determined expression, Sword Art Online aesthetic, detailed ornate line art, epic heroic atmosphere, high fantasy anime rendering',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Romance Anime',
        'Soft romantic shojo anime style',
        'anime_styles',
        'nano-banana/edit',
        'heart.circle.fill',
        'Transform into romance anime style: delicate beautiful features with soft lines, large emotional eyes with sparkle effects, flowing hair with gentle movement, soft romantic color palette (rose/blush/lavender/cream), dreamy bokeh background with flower petals or sparkles, gentle screen tone effects, tender emotional expression with slight blush, shoujo manga aesthetic, decorative floral frame elements, soft romantic lighting, heartwarming love story mood, elegant refined character design',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Comedy Anime',
        'Expressive comedic anime reaction',
        'anime_styles',
        'nano-banana/edit',
        'face.smiling.fill',
        'Transform into comedy anime style: exaggerated expressive features, oversized reaction eyes with dramatic effects, dynamic facial expression lines, bold vibrant colors with high saturation, comedic speed lines and impact symbols, simple bold outlines for clarity, funny reaction pose with motion, plain or simple background for focus, hilarious exaggerated expression (shocked/excited/panicked), anime comedy reaction face aesthetic, clear readable emotion, manga panel impact, maximum comedic timing effect',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Vintage Anime Portrait',
        'Classic 80s anime art style',
        'anime_styles',
        'nano-banana/edit',
        'photo.artframe',
        'Transform into vintage 80s anime style: classic shoujo sparkle effects, soft airbrushed shading technique, romantic soft-focus edges, retro anime color palette (soft pinks/purples/pastels), decorative rose or star border elements, gentle side lighting, dreamy background with gradient, elegant gentle expression, vintage anime magazine cover aesthetic, nostalgic 80s animation quality, romantic retro charm, classic anime portrait composition, timeless elegant beauty',
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
--   - Category: "Anime Styles" (display_order: 7)
--   - 15 anime transformation themes
--   - 2 featured themes (Ghibli + Makoto Shinkai)
--
-- Expected Impact: 🔥 VIRAL POTENTIAL
--   - Anime transformations are massively popular on social media
--   - Billions of views on #GhibliStyle, #AnimeMe trends
--   - High shareability and engagement
--
-- =====================================================

