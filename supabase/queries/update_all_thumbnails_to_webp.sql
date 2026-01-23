-- =====================================================
-- Update All Thumbnails to WebP Format
-- =====================================================
-- 
-- Purpose: Update all thumbnail_url values to use .webp extension
--          (some remain .jpg as they are already in that format)
--
-- Usage: Run this query in Supabase SQL Editor
-- =====================================================

-- Step 1: Update all .png to .webp
UPDATE themes
SET thumbnail_url = REPLACE(thumbnail_url, '.png', '.webp'),
    updated_at = now()
WHERE is_available = true
  AND thumbnail_url LIKE '%.png';

-- Step 2: Update ALL .jpg and .jpeg to .webp
UPDATE themes
SET thumbnail_url = REPLACE(REPLACE(thumbnail_url, '.jpg', '.webp'), '.jpeg', '.webp'),
    updated_at = now()
WHERE is_available = true
  AND (thumbnail_url LIKE '%.jpg' OR thumbnail_url LIKE '%.jpeg');

-- Step 3: Fix Christmas Card Portrait filename (should be christmas_, not thanksgiving_)
UPDATE themes
SET thumbnail_url = REPLACE(
    thumbnail_url,
    'thanksgiving_christmas_card_portrait',
    'christmas_christmas_card_portrait'
),
updated_at = now()
WHERE name = 'Christmas Card Portrait'
  AND category = 'seasonal'
  AND thumbnail_url LIKE '%thanksgiving_christmas_card_portrait%';

-- Step 4: Verify updates - Show summary by extension
SELECT 
    CASE 
        WHEN thumbnail_url LIKE '%.webp' THEN '.webp'
        WHEN thumbnail_url LIKE '%.jpg' THEN '.jpg'
        WHEN thumbnail_url LIKE '%.jpeg' THEN '.jpeg'
        WHEN thumbnail_url LIKE '%.png' THEN '.png'
        ELSE 'other'
    END as extension,
    COUNT(*) as count
FROM themes
WHERE is_available = true
  AND thumbnail_url IS NOT NULL
GROUP BY extension
ORDER BY count DESC;
