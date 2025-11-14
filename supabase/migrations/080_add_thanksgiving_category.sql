-- =====================================================
-- Add "Thanksgiving" Category
-- =====================================================
--
-- Purpose: Dedicated Thanksgiving category for Nov 2025
--          Separate from generic "Seasonal" for better organization
--
-- Category Details:
--   id: thanksgiving
--   name: Thanksgiving
--   display_order: 11
--   is_active: true
--
-- Themes: 8 Thanksgiving transformation styles
--
-- Timing: November 27, 2025 (13 days away!)
--
-- =====================================================

-- Step 1: Insert Category
INSERT INTO categories (id, name, display_order, is_active)
VALUES ('thanksgiving', 'Thanksgiving', 11, true)
ON CONFLICT (id) 
DO UPDATE SET
    name = EXCLUDED.name,
    display_order = EXCLUDED.display_order,
    is_active = EXCLUDED.is_active,
    updated_at = now();

-- Step 2: Insert 8 Thanksgiving Themes
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
        'Thanksgiving Feast Portrait',
        'Warm harvest table celebration style',
        'thanksgiving',
        'nano-banana/edit',
        'fork.knife',
        'Transform into Thanksgiving feast portrait: warm candlelit ambiance with golden hour lighting, rich harvest colors (burnt orange/deep red/golden yellow/russet brown), bountiful table setting with autumn florals and seasonal elements, soft bokeh background with warm autumn tones, grateful welcoming expression, Norman Rockwell painting aesthetic, oil painting texture with warm brushstrokes, family gathering warmth, traditional Thanksgiving celebration mood, heartwarming holiday portrait quality',
        true,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Autumn Harvest Magic',
        'Colorful fall foliage transformation',
        'thanksgiving',
        'nano-banana/edit',
        'leaf.fill',
        'Transform into autumn harvest magic: vibrant fall foliage colors (crimson/amber/gold/burnt orange), falling leaves and harvest elements, warm golden hour lighting through trees, rich autumn color palette with natural tones, outdoor autumn landscape background, peaceful grateful expression, impressionist autumn painting style, soft painterly brushwork texture, magical autumn atmosphere, enchanting fall season quality, nostalgic autumn beauty rendering',
        true,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Pilgrim Heritage Portrait',
        'Historical Thanksgiving settler aesthetic',
        'thanksgiving',
        'nano-banana/edit',
        'building.columns.fill',
        'Transform into Pilgrim heritage portrait: 1620s colonial era aesthetic with period clothing (pilgrim hat, white collar, dark vest), muted earth tone palette (black/brown/cream/gray), historical oil painting technique with classical brushwork, soft natural window lighting, rustic wooden interior or autumn landscape background, dignified formal expression, American colonial art style, authentic historical painting quality, vintage portrait composition, respectful heritage aesthetic, museum-quality historical rendering',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Harvest Festival Joy',
        'Rustic farm celebration style',
        'thanksgiving',
        'nano-banana/edit',
        'tractor.fill',
        'Transform into harvest festival style: rustic farm aesthetic with hay bales and pumpkin patch, warm golden sunset lighting across fields, rich autumn harvest colors (pumpkin orange/corn yellow/wheat gold/apple red), rural countryside background with rolling fields, cornucopia and harvest bounty decorations, cheerful festive expression, country lifestyle photography aesthetic, natural outdoor lighting with sun flare, wholesome farm harvest mood, rustic authentic countryside quality',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Turkey Day Fun',
        'Playful Thanksgiving turkey theme',
        'thanksgiving',
        'nano-banana/edit',
        'bird.fill',
        'Transform into playful Turkey Day style: whimsical turkey-inspired elements with feather accents, fun cartoonish aesthetic with friendly vibe, vibrant autumn color palette (orange/red/brown/yellow/gold), playful family-friendly composition, festive Thanksgiving background with harvest decorations, cheerful humorous expression, lighthearted holiday illustration style, cute approachable rendering, fun family holiday mood, entertaining Thanksgiving personality, kid-friendly festive quality',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Cozy Autumn Hearth',
        'Warm fireside comfort and gratitude',
        'thanksgiving',
        'nano-banana/edit',
        'flame.fill',
        'Transform into cozy autumn hearth style: warm fireplace glow lighting with soft amber tones, comfortable home interior with autumn decorations (pumpkins, leaves, candles), rich cozy color palette (burgundy/rust/amber/cream), soft blanket and knit textures, intimate indoor fall setting, gentle warm expression with contentment, hygge lifestyle aesthetic, soft warm lighting with fire glow, peaceful gratitude mood, comfortable homey autumn quality, intimate family gathering warmth',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Grateful Heart Portrait',
        'Warm thankful emotion portrait',
        'thanksgiving',
        'nano-banana/edit',
        'heart.fill',
        'Transform into grateful heart portrait: soft warm lighting emphasizing emotion, golden autumn color grading (warm amber/honey/gold tones), gentle peaceful expression of gratitude, simple elegant autumn background, heartfelt emotional atmosphere, fine art portrait photography style, natural warm lighting with soft shadows, thankful serene mood, touching emotional quality, authentic gratitude expression, timeless thanksgiving spirit rendering',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Pumpkin Patch Charm',
        'Autumn pumpkin farm aesthetic',
        'thanksgiving',
        'nano-banana/edit',
        'circle.hexagongrid.fill',
        'Transform into pumpkin patch charm: vibrant pumpkin orange and autumn colors (orange/green/brown/yellow), rustic farm setting with pumpkins and hay, warm afternoon autumn sunlight, outdoor harvest scene with pumpkin patch background, playful cheerful expression, country farm photography aesthetic, natural outdoor lighting with warm tones, fun autumn harvest mood, charming countryside quality, wholesome farm harvest beauty',
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
--   - Category: "Thanksgiving" (display_order: 11)
--   - 8 Thanksgiving themes
--   - 2 featured themes (Thanksgiving Feast + Autumn Harvest)
--
-- Timing: Launch NOW for Nov 27, 2025!
--
-- Expected Impact: 🔥 3-5x usage spike Thanksgiving week
--
-- =====================================================

