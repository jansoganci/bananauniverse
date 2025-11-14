-- =====================================================
-- Create Themes Table for Remote Content Management
-- =====================================================
--
-- Purpose: Store tools/themes dynamically to enable remote
--          content updates without app store releases
--
-- Key Features:
-- - Dynamic visibility control (is_available flag)
-- - Featured/promotion control (is_featured flag)
-- - Category-based organization
-- - Flexible JSONB settings field
-- - RLS security for read-only public access
--
-- =====================================================

-- 1. Create themes table
CREATE TABLE IF NOT EXISTS themes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    thumbnail_url TEXT,
    category TEXT NOT NULL CHECK (category IN ('main_tools', 'seasonal', 'pro_looks', 'restoration')),
    model_name TEXT NOT NULL,
    placeholder_icon TEXT NOT NULL,
    prompt TEXT NOT NULL,
    is_featured BOOLEAN DEFAULT false,
    is_available BOOLEAN DEFAULT true,
    requires_pro BOOLEAN DEFAULT false,
    default_settings JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_themes_featured
ON themes(is_featured)
WHERE is_featured = true;

CREATE INDEX IF NOT EXISTS idx_themes_available
ON themes(is_available)
WHERE is_available = true;

CREATE INDEX IF NOT EXISTS idx_themes_category
ON themes(category);

CREATE INDEX IF NOT EXISTS idx_themes_created_at
ON themes(created_at DESC);

-- 3. Enable RLS
ALTER TABLE themes ENABLE ROW LEVEL SECURITY;

-- 4. Create RLS policy - Anyone can view available themes
DROP POLICY IF EXISTS "Anyone can view available themes" ON themes;
CREATE POLICY "Anyone can view available themes"
ON themes FOR SELECT
USING (is_available = true);

-- 5. Create trigger for updated_at timestamp
DROP TRIGGER IF EXISTS update_themes_updated_at ON themes;
CREATE TRIGGER update_themes_updated_at
  BEFORE UPDATE ON themes
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- 6. Grant permissions
GRANT SELECT ON themes TO authenticated;
GRANT SELECT ON themes TO anon;

-- Done! Themes table is ready for seeding.
