-- =====================================================
-- Add "Animated Vehicles" Category and 10 Themes
-- =====================================================
--
-- Purpose: Add new dynamic category for animated vehicle transformations
--          All themes are Apple-safe (generic style terms only)
--
-- Category Details:
--   id: animated_vehicles
--   name: Animated Vehicles
--   display_order: 6
--   is_active: true
--
-- Themes: 10 animated vehicle transformation themes
--
-- Apple Safety:
--   ✅ Generic style terms (no brand/character names)
--   ✅ "Cartoon car", "toon truck" - style descriptions
--   ✅ "Pixar-style" - acceptable style reference
--   ❌ No character names (Lightning McQueen, etc.)
--   ❌ No brand names (Cars movie, etc.)
--
-- =====================================================

-- Step 1: Insert Category (with conflict handling)
INSERT INTO categories (id, name, display_order, is_active)
VALUES ('animated_vehicles', 'Animated Vehicles', 6, true)
ON CONFLICT (id) 
DO UPDATE SET
    name = EXCLUDED.name,
    display_order = EXCLUDED.display_order,
    is_active = EXCLUDED.is_active,
    updated_at = now();

-- Step 2: Insert 10 Animated Vehicle Themes
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
        'Friendly Car Eyes',
        'Add expressive cartoon eyes to your car',
        'animated_vehicles',
        'nano-banana/edit',
        'car.fill',
        '3D Pixar-style animated car: oversized glossy eyes on windshield (40% of front surface, white catch-lights), curved smile bumper grille, rounded body panels, vibrant solid-color paint (red/blue/yellow options), chrome trim with mirror reflections, centered frontal view, studio lighting with soft drop shadow, white-to-blue gradient background, cheerful friendly expression, photorealistic CGI render quality, 4K detail',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Racing Champion',
        'Turn car into racing hero style',
        'animated_vehicles',
        'nano-banana/edit',
        'flag.checkered',
        '3D animated racing car: dynamic 3/4 angle view, bold racing stripes (white/red/blue), sponsor decal stickers on sides, checkered flag pattern accents, victory expression with determined eyes, aerodynamic spoiler, low-profile racing wheels, metallic paint with speed streaks, dramatic side lighting with motion blur trails, racetrack background with blurred crowd, competitive champion personality, high-speed action pose, professional CGI animation quality',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Vintage Cartoon Car',
        'Classic toon car transformation',
        'animated_vehicles',
        'nano-banana/edit',
        'car.2.fill',
        '3D Pixar-style vintage car: 1950s design with rounded curves and chrome bumpers, large circular headlights as expressive eyes, toothy grille smile, two-tone paint (cream/teal or pink/white), whitewall tires, chrome hubcaps with reflections, side profile view showing classic proportions, warm studio lighting with soft shadows, pastel gradient background, cheerful nostalgic personality, retro-futuristic 3D rendering, detailed material textures',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Monster Truck Toon',
        'Animated monster truck style',
        'animated_vehicles',
        'nano-banana/edit',
        'flame.fill',
        '3D animated monster truck: exaggerated proportions with oversized wheels (2x body height), bold primary colors (red/yellow/blue), powerful determined expression with wide eyes, raised suspension showing massive tires, chrome exhaust pipes, flame decals on sides, 3/4 angle view emphasizing scale, dramatic low-angle lighting creating heroic silhouette, dirt track background with dust clouds, powerful confident personality, comic book style 3D rendering, dynamic action pose',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Friendly Bus',
        'Cheerful animated bus',
        'animated_vehicles',
        'nano-banana/edit',
        'bus.fill',
        '3D Pixar-style animated bus: large rectangular windows forming friendly eyes (white highlights), curved smile grille, rounded corners throughout, warm color palette (yellow/orange/red), community transport design, centered frontal view, soft studio lighting with gentle shadows, sunny sky gradient background, welcoming cheerful expression, approachable friendly personality, glossy paint finish, photorealistic 3D animation, detailed surface reflections',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Sports Car Hero',
        'Sleek animated sports car',
        'animated_vehicles',
        'nano-banana/edit',
        'bolt.car.fill',
        '3D animated sports car: sleek aerodynamic body with low profile, confident expression through aggressive headlight design (narrow focused eyes), metallic paint (silver/red/blue) with speed lines, carbon fiber accents, large alloy wheels, side view emphasizing length and curves, dramatic side lighting with rim light, urban street background with motion blur, confident heroic personality, speed-focused attitude, premium CGI rendering quality, detailed material shaders',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Cartoon Truck',
        'Hardworking toon truck',
        'animated_vehicles',
        'nano-banana/edit',
        'truck.box.fill',
        '3D Pixar-style animated truck: sturdy boxy design with rounded edges, determined expression through rectangular headlight eyes, working-class color scheme (blue/white or red/white), utility details (tool boxes, cargo straps), chrome grille with character, side profile view showing strength, warm practical lighting, industrial background with subtle details, hardworking determined personality, reliable trustworthy vibe, friendly cartoon proportions, professional 3D animation quality',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Off-Road Explorer',
        'Adventurous vehicle style',
        'animated_vehicles',
        'nano-banana/edit',
        'mountain.2.fill',
        '3D animated off-road vehicle: rugged design with raised suspension, adventurous expression through round protective headlight eyes, mud-splattered paint (earth tones: brown/green/beige), all-terrain tires with deep treads, roof rack with gear, dirt and dust particles on surfaces, 3/4 angle view showing off-road capability, natural outdoor lighting with sun rays, mountain trail background with rocks and vegetation, adventurous explorer personality, ready-for-anything attitude, detailed environmental 3D rendering',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Classic Roadster',
        'Elegant vintage roadster',
        'animated_vehicles',
        'nano-banana/edit',
        'crown.fill',
        '3D Pixar-style elegant roadster: refined vintage design with flowing curves, sophisticated expression through elegant headlight eyes (narrow and refined), luxury color palette (deep burgundy/royal blue/forest green), chrome details with mirror polish, wire-spoke wheels, convertible top design, side profile view emphasizing elegance, soft dramatic lighting with rim highlights, upscale environment background (cityscape or countryside), sophisticated refined personality, premium luxury aesthetic, high-end CGI rendering with material realism',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Rally Racer',
        'Competitive rally style',
        'animated_vehicles',
        'nano-banana/edit',
        'checkmark.seal.fill',
        '3D animated rally car: competition-ready design with rally livery, determined expression through focused headlight eyes, bold sponsor graphics (white/red/yellow/blue), mud guards and protective equipment, aggressive off-road tires, roof-mounted light bar, dynamic 3/4 angle view, dramatic action lighting with dust particles, dirt track background with splash effects, competitive determined personality, race-ready attitude, motion blur effects, professional motorsport 3D animation quality',
        false,
        true,
        false,
        '{}'::jsonb
    )
ON CONFLICT (name, category) DO NOTHING;

-- Step 3: Verification (optional - can be run separately)
-- Uncomment these to verify the migration:

-- Verify category exists
-- SELECT 
--     id, 
--     name, 
--     display_order, 
--     is_active,
--     created_at
-- FROM categories 
-- WHERE id = 'animated_vehicles';

-- Count themes in new category
-- SELECT 
--     COUNT(*) as theme_count,
--     category
-- FROM themes 
-- WHERE category = 'animated_vehicles'
-- GROUP BY category;

-- List all themes in category
-- SELECT 
--     name,
--     description,
--     is_featured,
--     is_available
-- FROM themes 
-- WHERE category = 'animated_vehicles'
-- ORDER BY name;

-- Verify category appears in correct order
-- SELECT 
--     id,
--     name,
--     display_order
-- FROM categories
-- WHERE is_active = true
-- ORDER BY display_order;

-- =====================================================
-- Migration Complete!
-- =====================================================
-- 
-- Next Steps:
-- 1. Run this migration in Supabase SQL Editor or via CLI
-- 2. Pull-to-refresh in your app
-- 3. "Animated Vehicles" category should appear as 6th category
-- 4. All 10 themes should be visible in that category
--
-- Expected Result:
--   - Category: "Animated Vehicles" (display_order: 6)
--   - Themes: 10 animated vehicle transformation themes
--   - All themes: is_available = true, is_featured = false
--
-- =====================================================

