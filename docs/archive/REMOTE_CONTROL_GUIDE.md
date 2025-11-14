# 🎮 Remote Control Guide for Themes

Quick reference for managing themes remotely via Supabase Dashboard.

## 📍 Where to Run These Queries

**Supabase Dashboard → SQL Editor**
1. Go to https://supabase.com/dashboard
2. Select your project
3. Click "SQL Editor" in sidebar
4. Paste query and click "Run"

---

## 🎯 Common Operations

### ✨ Feature a Theme (Add to Carousel)

```sql
-- Feature a specific theme
UPDATE themes
SET is_featured = true
WHERE name = 'Christmas Magic Edit';

-- Or by ID
UPDATE themes
SET is_featured = true
WHERE id = 'your-theme-uuid';
```

**Result:** Theme appears in featured carousel on next app load

---

### 🚫 Unfeature a Theme (Remove from Carousel)

```sql
-- Unfeature a theme
UPDATE themes
SET is_featured = false
WHERE name = 'Thanksgiving Magic Edit';
```

**Result:** Theme moves to category section only

---

### 👁️ Hide a Theme (Make Invisible)

```sql
-- Temporarily hide a broken tool
UPDATE themes
SET is_available = false
WHERE name = 'Image Upscaler (2x-4x)';
```

**Result:** Theme disappears from all users' apps immediately

---

### ✅ Show a Hidden Theme

```sql
-- Re-enable a previously hidden theme
UPDATE themes
SET is_available = true
WHERE name = 'Image Upscaler (2x-4x)';
```

**Result:** Theme reappears in app

---

### ➕ Add a New Theme

```sql
INSERT INTO themes (
    name,
    description,
    category,
    model_name,
    placeholder_icon,
    prompt,
    is_featured,
    is_available,
    requires_pro
) VALUES (
    'Valentine Heart Frame',
    'Add romantic valentine heart frames',
    'seasonal',
    'nano-banana/edit',
    'heart.fill',
    'Add romantic valentine heart frames and soft pink lighting to this image',
    true,   -- Featured on launch
    true,   -- Visible
    false   -- Free for all users
);
```

**Result:** New theme appears in app on next load

---

### ✏️ Update Theme Details

```sql
-- Update prompt for better results
UPDATE themes
SET prompt = 'Create a professional LinkedIn headshot with studio lighting, natural skin tone, and confidence'
WHERE name = 'LinkedIn Headshot';

-- Update description
UPDATE themes
SET description = 'Enhanced AI-powered professional headshots'
WHERE name = 'LinkedIn Headshot';

-- Add thumbnail image
UPDATE themes
SET thumbnail_url = 'https://your-cdn.com/linkedin-headshot.jpg'
WHERE name = 'LinkedIn Headshot';
```

**Result:** Changes apply on next app load

---

## 🎄 Seasonal Campaign Examples

### Christmas Campaign (December)

```sql
-- Feature all Christmas tools
UPDATE themes
SET is_featured = true
WHERE name ILIKE '%christmas%' OR name ILIKE '%holiday%' OR name ILIKE '%winter%';

-- Hide non-seasonal tools from featured
UPDATE themes
SET is_featured = false
WHERE category != 'seasonal' AND name NOT IN ('Remove Background', 'Remove Object from Image');
```

---

### New Year Campaign (January)

```sql
-- Unfeature Christmas, feature New Year
UPDATE themes
SET is_featured = false
WHERE name ILIKE '%christmas%' OR name ILIKE '%holiday%';

UPDATE themes
SET is_featured = true
WHERE name ILIKE '%new year%' OR name = 'New Year Glamour' OR name = 'Confetti Celebration';
```

---

### Valentine's Day (February)

```sql
-- If you have valentine tools, feature them
UPDATE themes
SET is_featured = true
WHERE name ILIKE '%valentine%' OR name ILIKE '%heart%' OR name ILIKE '%love%';
```

---

### Back to Normal (End of Season)

```sql
-- Reset to default featured themes
UPDATE themes SET is_featured = false;  -- Clear all

-- Feature the original 5 defaults
UPDATE themes SET is_featured = true WHERE name IN (
    'Remove Object from Image',
    'Remove Background',
    'Christmas Magic Edit',
    'LinkedIn Headshot',
    'Image Upscaler (2x-4x)'
);
```

---

## 🔍 Useful Queries

### View Current Featured Themes

```sql
SELECT name, category, is_featured, is_available
FROM themes
WHERE is_featured = true
ORDER BY category;
```

---

### Count Themes by Category

```sql
SELECT
    category,
    COUNT(*) as total,
    COUNT(*) FILTER (WHERE is_featured = true) as featured,
    COUNT(*) FILTER (WHERE is_available = false) as hidden
FROM themes
GROUP BY category;
```

---

### Find Themes by Keyword

```sql
-- Find all seasonal themes
SELECT name, category, is_featured
FROM themes
WHERE category = 'seasonal'
ORDER BY name;

-- Find all themes with "portrait" in name
SELECT name, category, is_featured
FROM themes
WHERE name ILIKE '%portrait%';
```

---

### See What Users Currently See

```sql
-- This mimics the exact API call from iOS app
SELECT
    id,
    name,
    category,
    is_featured,
    placeholder_icon
FROM themes
WHERE is_available = true
ORDER BY is_featured DESC, name ASC;
```

---

## ⚠️ Safety Rules

### ✅ DO:
- Test queries on a single theme first
- Keep at least 5 featured themes
- Always set `is_available = true` for new themes
- Check results after running bulk updates

### ❌ DON'T:
- Delete themes (just set `is_available = false` instead)
- Feature more than 10 themes (carousel gets crowded)
- Make all themes `is_featured = true` (defeats the purpose)
- Remove all featured themes (carousel will be empty)

---

## 🧪 Testing Changes

After making changes, verify with:

```sql
-- Check what users will see
SELECT name, is_featured, is_available
FROM themes
WHERE is_available = true
ORDER BY is_featured DESC, name ASC
LIMIT 10;

-- Count featured themes
SELECT COUNT(*) as featured_count
FROM themes
WHERE is_featured = true AND is_available = true;
-- Should be 3-7 for good UX
```

---

## 🚨 Quick Fixes

### Too Many Featured Themes

```sql
-- Limit to top 5 featured
WITH ranked AS (
  SELECT id, ROW_NUMBER() OVER (ORDER BY created_at) as rn
  FROM themes
  WHERE is_featured = true
)
UPDATE themes
SET is_featured = false
WHERE id IN (SELECT id FROM ranked WHERE rn > 5);
```

---

### Accidentally Hid All Themes

```sql
-- Re-enable all themes
UPDATE themes
SET is_available = true;
```

---

### Need to Reset Everything

```sql
-- Reset to original state
UPDATE themes
SET
    is_featured = false,
    is_available = true;

-- Re-feature the original 5
UPDATE themes SET is_featured = true WHERE name IN (
    'Remove Object from Image',
    'Remove Background',
    'Christmas Magic Edit',
    'LinkedIn Headshot',
    'Image Upscaler (2x-4x)'
);
```

---

## 📊 Analytics Queries

### Most Popular Categories (by count)

```sql
SELECT
    category,
    COUNT(*) as theme_count
FROM themes
WHERE is_available = true
GROUP BY category
ORDER BY theme_count DESC;
```

---

### Recently Added Themes

```sql
SELECT
    name,
    category,
    created_at
FROM themes
ORDER BY created_at DESC
LIMIT 10;
```

---

## 🎯 Best Practices

1. **Feature 5-7 themes max** - Too many overwhelms users
2. **Rotate featured themes monthly** - Keep content fresh
3. **Hide broken tools immediately** - Better than letting users experience failures
4. **Test on one theme first** - Verify query works before bulk updates
5. **Keep seasonal content updated** - Feature relevant holidays
6. **Document why themes are hidden** - Add notes in description field

---

## 📞 Need Help?

If you accidentally break something:
1. Run the "Need to Reset Everything" query above
2. Or re-run migration `070_seed_themes_data.sql`
3. Contact your developer for complex fixes

---

**Last Updated:** Phase 1 Complete
**Next Steps:** Phase 2 - Create ThemeService.swift
