-- =====================================================
-- Create Categories Table for Dynamic Category Management
-- =====================================================
--
-- Purpose: Enable dynamic category management without app updates
--          Categories can be added, renamed, reordered, and hidden
--          via database updates
--
-- Key Features:
-- - Dynamic category creation (no app update needed)
-- - Display order control
-- - Category visibility toggle (is_active)
-- - Category images/icons support
-- - Foreign key relationship with themes
--
-- =====================================================

-- 1. Create categories table
CREATE TABLE IF NOT EXISTS categories (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    display_order INTEGER DEFAULT 0,
    icon_url TEXT,
    thumbnail_url TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_categories_active
ON categories(is_active)
WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_categories_display_order
ON categories(display_order);

-- 3. Seed with existing hardcoded categories
INSERT INTO categories (id, name, display_order, is_active) VALUES
    ('main_tools', 'Photo Editor', 1, true),
    ('seasonal', 'Seasonal', 2, true),
    ('pro_looks', 'Pro Photos', 3, true),
    ('restoration', 'Enhancer', 4, true)
ON CONFLICT (id) DO NOTHING;

-- 4. Enable RLS
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;

-- 5. Create RLS policy - Anyone can view active categories
DROP POLICY IF EXISTS "Anyone can view active categories" ON categories;
CREATE POLICY "Anyone can view active categories"
ON categories FOR SELECT
USING (is_active = true);

-- 6. Create trigger for updated_at timestamp
DROP TRIGGER IF EXISTS update_categories_updated_at ON categories;
CREATE TRIGGER update_categories_updated_at
  BEFORE UPDATE ON categories
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- 7. Grant permissions
GRANT SELECT ON categories TO authenticated;
GRANT SELECT ON categories TO anon;

-- 8. Update themes table: Remove CHECK constraint
ALTER TABLE themes DROP CONSTRAINT IF EXISTS themes_category_check;

-- 9. Update themes table: Add foreign key to categories
-- First, ensure all existing theme categories exist in categories table
-- (This should already be true from step 3, but adding safety check)
DO $$
BEGIN
    -- Insert any missing categories from themes that aren't in categories
    INSERT INTO categories (id, name, display_order, is_active)
    SELECT DISTINCT 
        category,
        INITCAP(REPLACE(category, '_', ' ')),
        COALESCE((SELECT MAX(display_order) FROM categories), 0) + ROW_NUMBER() OVER (),
        true
    FROM themes
    WHERE category NOT IN (SELECT id FROM categories)
    ON CONFLICT (id) DO NOTHING;
END $$;

-- 10. Add foreign key constraint
ALTER TABLE themes 
ADD CONSTRAINT fk_theme_category 
FOREIGN KEY (category) REFERENCES categories(id) ON DELETE CASCADE;

-- 11. Create index on themes.category for foreign key performance
CREATE INDEX IF NOT EXISTS idx_themes_category_fk
ON themes(category);

-- Verify migration
DO $$
DECLARE
    category_count INTEGER;
    theme_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO category_count FROM categories;
    SELECT COUNT(*) INTO theme_count FROM themes;
    
    RAISE NOTICE '✅ Categories migration complete!';
    RAISE NOTICE '   Categories: %', category_count;
    RAISE NOTICE '   Themes: %', theme_count;
    RAISE NOTICE '   Foreign key constraint added successfully';
END $$;

