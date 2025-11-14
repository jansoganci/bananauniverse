-- =====================================================
-- Add "Toy Style" Category (3D Collectible Figures)
-- =====================================================
--
-- Purpose: Transform photos into collectible toy/action figure styles
--          Viral potential: People LOVE seeing themselves as toys
--
-- Category Details:
--   id: toy_style
--   name: Toy Style
--   display_order: 9
--   is_active: true
--
-- Themes: 10 toy transformation styles
--
-- Apple Safety:
--   ⚠️ CRITICAL: Use generic terms only!
--   ✅ "Collectible figure" NOT "Funko Pop"
--   ✅ "Building block character" NOT "LEGO"
--   ✅ "Fashion doll style" NOT "Barbie"
--
-- =====================================================

-- Step 1: Insert Category
INSERT INTO categories (id, name, display_order, is_active)
VALUES ('toy_style', 'Toy Style', 9, true)
ON CONFLICT (id) 
DO UPDATE SET
    name = EXCLUDED.name,
    display_order = EXCLUDED.display_order,
    is_active = EXCLUDED.is_active,
    updated_at = now();

-- Step 2: Insert 10 Toy Style Themes
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
        'Collectible Figure Style',
        'Transform into vinyl collectible figure',
        'toy_style',
        'nano-banana/edit',
        'cube.fill',
        'Transform into collectible vinyl figure style: oversized rectangular head (1.5x body proportion), large glossy black dot eyes with white highlights, minimal facial features, chibi proportions with small body, glossy vinyl toy texture, solid vibrant color blocks, bobblehead aesthetic, centered frontal pose on display base, studio lighting with soft shadows, white background for product display, cute simplified expression, vinyl collectible toy aesthetic, premium toy photography quality, shelf-ready collectible presentation',
        true,
        true,
        false,
        '{}'::jsonb
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
        '{}'::jsonb
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
        '{}'::jsonb
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
        '{}'::jsonb
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
        '{}'::jsonb
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
        '{}'::jsonb
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
        '{}'::jsonb
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
        '{}'::jsonb
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
        '{}'::jsonb
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
        '{}'::jsonb
    )
ON CONFLICT (name, category) DO NOTHING;

-- =====================================================
-- Migration Complete!
-- =====================================================
-- 
-- Added:
--   - Category: "Toy Style" (display_order: 9)
--   - 10 toy transformation themes
--   - 2 featured themes (Collectible Figure + Building Block)
--
-- Expected Impact: 🔥 VIRAL POTENTIAL
--   - People love seeing themselves as toys
--   - High shareability (fun, nostalgic, whimsical)
--   - Safe generic terms (no trademark issues)
--
-- =====================================================

