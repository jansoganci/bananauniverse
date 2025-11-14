-- =====================================================
-- Add "Meme Magic" Category (Surreal & Comedy)
-- =====================================================
--
-- Purpose: Transform photos into viral meme and surreal art styles
--          Viral potential: VERY HIGH - Memes = shares = growth
--
-- Category Details:
--   id: meme_magic
--   name: Meme Magic
--   display_order: 10
--   is_active: true
--
-- Themes: 12 meme and surreal transformation styles
--
-- Apple Safety:
--   ⚠️ CRITICAL: NO character names!
--   ✅ "Green ogre style" NOT "Shrek"
--   ✅ "Yellow animated family style" NOT "Simpsons"
--   ✅ "Renaissance portrait" OK (art style)
--
-- =====================================================

-- Step 1: Insert Category
INSERT INTO categories (id, name, display_order, is_active)
VALUES ('meme_magic', 'Meme Magic', 10, true)
ON CONFLICT (id) 
DO UPDATE SET
    name = EXCLUDED.name,
    display_order = EXCLUDED.display_order,
    is_active = EXCLUDED.is_active,
    updated_at = now();

-- Step 2: Insert 12 Meme & Surreal Themes
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
        'Renaissance Portrait',
        'Transform into classical Renaissance painting',
        'meme_magic',
        'nano-banana/edit',
        'paintbrush.pointed.fill',
        'Transform into Renaissance portrait painting: classical oil painting technique with visible brush strokes, rich deep colors (burgundy/emerald/gold/deep blue), dramatic chiaroscuro lighting from side, ornate period costume details (ruffled collar, velvet, jewelry), golden frame border visible, museum painting background (dark neutral), dignified noble expression, 16th century master painting aesthetic, authentic oil painting texture, historical portrait composition, old master quality rendering, timeless classical art beauty',
        true,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Medieval Painting',
        'Transform into medieval manuscript art',
        'meme_magic',
        'nano-banana/edit',
        'scroll.fill',
        'Transform into medieval manuscript painting: flat stylized medieval art style, gold leaf illumination effects, rich jewel-tone colors (deep blue/crimson/gold), simplified iconic features, ornate decorative border with gold patterns, parchment aged paper texture, religious icon composition, frontal symmetrical pose, medieval manuscript aesthetic, authentic medieval painting technique, illuminated manuscript quality, historical religious art style, Byzantine icon influence',
        true,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Pop Art Style',
        'Bold Warhol-inspired pop art transformation',
        'meme_magic',
        'nano-banana/edit',
        'square.grid.2x2.fill',
        'Transform into pop art style: bold flat colors with high contrast, thick black outlines and contours, halftone dot pattern texture, vibrant primary colors (red/yellow/blue) with complementary accents, multiple repeated panels (2x2 or 4-panel grid), screen print texture effect, simplified graphic shapes, bold graphic composition, confident expression, 1960s pop art aesthetic, Andy Warhol style rendering, commercial art influence, iconic bold graphic impact',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Comic Book Hero',
        'Dynamic superhero comic book style',
        'meme_magic',
        'nano-banana/edit',
        'book.fill',
        'Transform into comic book style: bold black ink outlines with dynamic line weight, flat vibrant colors with cel shading, Ben-Day dots halftone texture, action lines and speed effects, dramatic hero lighting, comic panel frame visible, speech bubble space, heroic powerful expression, vintage comic book aesthetic, hand-drawn ink quality, classic superhero comic rendering, dynamic graphic novel composition, pow-bam comic energy',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Pixel Art Retro',
        'Classic 8-bit video game character',
        'meme_magic',
        'nano-banana/edit',
        'gamecontroller.fill',
        'Transform into 8-bit pixel art: blocky pixelated squares visible, limited color palette (16 colors), retro video game sprite aesthetic, simplified geometric features, pixel-perfect edges and outlines, dithering pattern effects, classic game character proportions, solid background color or simple pixel background, game character expression, 1980s video game aesthetic, authentic pixel art rendering, Nintendo/arcade game quality, nostalgic retro gaming charm',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Yellow Animated Family',
        'Springfield-style animated character',
        'meme_magic',
        'nano-banana/edit',
        'person.2.fill',
        'Transform into yellow animated sitcom style: bright yellow skin tone, oversized white eyes with black dot pupils, simplified cartoon features with rounded shapes, thick black outlines throughout, bold flat colors, casual everyday clothing, simple background setting (home/couch), expressive cartoon face, American animated sitcom aesthetic, hand-drawn animation quality, family comedy show style, iconic yellow character design, classic animated series rendering',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Green Ogre Fantasy',
        'Fairytale ogre character style',
        'meme_magic',
        'nano-banana/edit',
        'leaf.fill',
        'Transform into green ogre fantasy style: bright green skin with texture, large round ogre ears, friendly but grumpy features, vest and medieval fantasy clothing, swamp or forest background, 3D CGI animation quality, expressive character face with personality, DreamWorks animation aesthetic, detailed skin texture and lighting, fantasy comedy character, approachable ogre charm, animated fairytale quality, lovable ogre character rendering',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Impressionist Painting',
        'Dreamy impressionist artwork',
        'meme_magic',
        'nano-banana/edit',
        'cloud.fill',
        'Transform into impressionist painting: visible loose brushstrokes with texture, soft blended colors (pastels and muted tones), dappled light effects with color dabs, outdoor natural lighting, slightly blurred soft focus, garden or outdoor setting, peaceful contemplative expression, Monet-style impressionism aesthetic, authentic oil painting technique, plein air painting quality, French impressionist composition, dreamy atmospheric light rendering',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Surreal Dream Art',
        'Bizarre surrealist transformation',
        'meme_magic',
        'nano-banana/edit',
        'eye.fill',
        'Transform into surreal dream art: unexpected juxtapositions and impossible elements, melting or distorted features, dreamlike bizarre composition, unusual color combinations (unexpected palettes), multiple perspectives merged, symbolic surreal background elements, mysterious enigmatic expression, Dali-inspired surrealism aesthetic, oil painting dreamlike quality, subconscious mind visualization, artistic surreal rendering, thought-provoking bizarre beauty',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Vaporwave Aesthetic',
        'Retro futuristic internet aesthetic',
        'meme_magic',
        'nano-banana/edit',
        'globe',
        'Transform into vaporwave aesthetic: pastel gradient colors (pink/cyan/purple), Greek statue or bust integration, glitch art effects and digital artifacts, Windows 95 UI elements, geometric shapes and grids, palm tree or sunset motifs, Japanese text elements, nostalgic digital collage, chill aesthetic expression, internet culture aesthetic, surreal digital art rendering, 90s internet nostalgia vibe, A E S T H E T I C mood',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Cubist Portrait',
        'Geometric cubism art style',
        'meme_magic',
        'nano-banana/edit',
        'cube.transparent',
        'Transform into cubist portrait: geometric fragmented shapes, multiple perspectives shown simultaneously, angular faceted planes, muted earth tone palette (ochre/brown/grey/blue), abstract facial deconstruction, collage-like layered composition, flat two-dimensional space, analytical cubism aesthetic, Picasso-style rendering, modernist art movement quality, intellectual abstract composition, revolutionary geometric art style',
        false,
        true,
        false,
        '{}'::jsonb
    ),
    (
        'Lowbrow Pop Surrealism',
        'Underground comic art meets surrealism',
        'meme_magic',
        'nano-banana/edit',
        'paintbrush.fill',
        'Transform into lowbrow pop surrealism: cartoon characters with slightly dark twist, big expressive eyes with surreal elements, vibrant saturated colors with high contrast, underground comic book influence, cute but slightly creepy aesthetic, detailed painted texture, quirky imaginative background, playful mysterious expression, Mark Ryden style aesthetic, contemporary surreal pop art quality, gallery exhibition rendering, modern pop surrealism movement',
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
--   - Category: "Meme Magic" (display_order: 10)
--   - 12 meme and surreal transformation themes
--   - 2 featured themes (Renaissance + Medieval)
--
-- Expected Impact: 🔥 VERY HIGH ENGAGEMENT
--   - Memes and surreal content = maximum shareability
--   - Multiple viral formats (Renaissance, Pop Art, Pixel Art)
--   - Safe generic terms (no character/brand issues)
--   - High social media virality potential
--
-- =====================================================

