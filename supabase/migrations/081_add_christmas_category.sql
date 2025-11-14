-- =====================================================
-- Add "Christmas" Category
-- =====================================================
--
-- Purpose: Dedicated Christmas category for Dec 2025
--          Separate from generic "Seasonal" for better organization
--
-- Category Details:
--   id: christmas
--   name: Christmas
--   display_order: 12
--   is_active: true
--
-- Themes: 10 Christmas transformation styles
--
-- Timing: December 25, 2025 (41 days)
--
-- =====================================================

-- Step 1: Insert Category
INSERT INTO categories (id, name, display_order, is_active)
VALUES ('christmas', 'Christmas', 12, true)
ON CONFLICT (id) 
DO UPDATE SET
    name = EXCLUDED.name,
    display_order = EXCLUDED.display_order,
    is_active = EXCLUDED.is_active,
    updated_at = now();

-- Step 2: Insert 10 Christmas Themes
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
        'Christmas Card Portrait',
        'Perfect holiday greeting card photo',
        'christmas',
        'nano-banana/edit',
        'envelope.fill',
        'Transform into Christmas card portrait: professional holiday card photography style, festive but elegant composition, classic Christmas colors (deep red/forest green/gold/ivory), soft studio lighting with subtle sparkle bokeh, decorative holiday border frame, winter wonderland or festive indoor background, warm welcoming smile, timeless holiday card aesthetic, premium greeting card quality, family photo tradition style, professional holiday portrait composition, heartwarming seasonal greetings mood',
        true,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Christmas Magic Sparkle',
        'Enchanted holiday wonderland style',
        'christmas',
        'nano-banana/edit',
        'sparkles',
        'Transform into Christmas magic sparkle: enchanted winter wonderland with magical sparkle effects, rich vibrant Christmas colors (red/green/gold/white), glowing magical particles and fairy lights, snow and festive elements, dreamy magical lighting with bokeh, cheerful delighted expression, magical holiday fantasy style, ethereal enchanting rendering, wonder-filled Christmas magic mood, fairy tale holiday quality, enchanting festive sparkle atmosphere',
        true,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Gingerbread Delight',
        'Sweet gingerbread house aesthetic',
        'christmas',
        'nano-banana/edit',
        'house.lodge.fill',
        'Transform into gingerbread delight style: whimsical candy-colored aesthetic with frosting details, sweet treat color palette (gingerbread brown/white icing/candy colors/peppermint red), cookie texture with decorative icing patterns, sugary sparkle effects and candy cane accents, candy land background with gingerbread houses, cheerful sweet expression, storybook illustration style, playful confectionery rendering, sweet holiday magic mood, charming bakery window quality, delightful Christmas candy aesthetic',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'North Pole Elf Magic',
        'Santa''s workshop elf transformation',
        'christmas',
        'nano-banana/edit',
        'gift.circle.fill',
        'Transform into North Pole elf magic: playful elf aesthetic with pointed ears and festive hat, bright cheerful colors (red/green/gold with white trim), workshop helper costume details with bells, toy workshop background with presents and tools, energetic playful expression, whimsical Christmas illustration style, cartoon character rendering with personality, magical workshop atmosphere, busy holiday helper mood, enchanting Santa''s workshop quality, festive elf charm',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Frosty Winter Wonderland',
        'Magical snowman-inspired style',
        'christmas',
        'nano-banana/edit',
        'snowflake.circle.fill',
        'Transform into frosty winter wonderland: icy blue-white color palette with crystalline sparkles, magical frozen aesthetic with snowflake details and frost patterns, winter wonderland background with fresh pristine snow, soft diffused winter light with cool tones, frosted edges and icy textures, cheerful frosty expression, magical winter fairytale style, crisp clean winter rendering, enchanted snow day mood, pristine winter wonderland quality, magical snowman charm',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Christmas Lights Glow',
        'Magical holiday bokeh lights',
        'christmas',
        'nano-banana/edit',
        'light.beacon.max.fill',
        'Transform into Christmas lights glow: magical bokeh background with colorful string lights (red/green/blue/gold/white), warm festive lighting creating halo effect around subject, soft dreamy atmosphere with twinkling lights, rich holiday colors with luminous quality, evening or night setting with light bokeh, peaceful happy expression, romantic holiday photography aesthetic, professional bokeh lighting technique, magical Christmas evening mood, enchanting holiday lights quality, warm festive glow atmosphere',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Santa''s Workshop Style',
        'North Pole toy maker aesthetic',
        'christmas',
        'nano-banana/edit',
        'hammer.fill',
        'Transform into Santa''s workshop style: toy maker aesthetic with workshop elements, festive red and green color scheme with wood tones, busy workshop background with toys and tools, warm indoor lighting with magical atmosphere, friendly helpful expression, vintage Christmas illustration style, detailed craftsmanship rendering, busy productive holiday mood, authentic workshop quality, heartwarming toy-making tradition aesthetic',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Snowy Christmas Eve',
        'Peaceful silent night atmosphere',
        'christmas',
        'nano-banana/edit',
        'moon.stars.fill',
        'Transform into snowy Christmas Eve: peaceful nighttime winter scene with falling snow, soft moonlight illumination with blue-white tones, quiet snowy landscape background, gentle snowfall effects and crystalline details, serene peaceful expression, romantic winter night photography, soft ethereal night lighting, calm silent night mood, tranquil Christmas Eve quality, magical peaceful winter night atmosphere',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Candy Cane Cheer',
        'Peppermint and sweets theme',
        'christmas',
        'nano-banana/edit',
        'wand.and.stars.inverse',
        'Transform into candy cane cheer: peppermint stripe patterns and candy elements, bright festive colors (red/white/green/gold), sweet confectionery aesthetic with candy cane details, playful sugar-coated texture effects, candy shop background with Christmas treats, cheerful sweet expression, whimsical holiday illustration style, vibrant candy-colored rendering, sweet festive joy mood, delightful Christmas candy quality, playful peppermint charm',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Vintage Christmas Nostalgia',
        'Classic retro holiday aesthetic',
        'christmas',
        'nano-banana/edit',
        'photo.on.rectangle.angled',
        'Transform into vintage Christmas nostalgia: retro 1950s holiday aesthetic with classic styling, muted vintage color palette (faded red/green/cream/sepia tones), antique Christmas decorations and vintage elements, soft aged photograph texture with grain, nostalgic indoor holiday setting, warm genuine smile, classic family photo aesthetic, authentic vintage photography quality, timeless Christmas memory mood, heartwarming retro holiday quality, nostalgic traditional Christmas charm',
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
--   - Category: "Christmas" (display_order: 12)
--   - 10 Christmas themes
--   - 2 featured themes (Christmas Card + Christmas Magic)
--
-- Timing: Launch Dec 1 for Dec 25, 2025!
--
-- Expected Impact: 🔥 5-10x usage spike Christmas season
--
-- =====================================================

