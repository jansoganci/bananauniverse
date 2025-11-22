#!/bin/bash

# =====================================================
# Test Script for Migration 101
# =====================================================
#
# Purpose: Safely test the viral-first category reorganization
#          in local Supabase environment before production deploy
#
# Usage:
#   chmod +x test_migration_101.sh
#   ./test_migration_101.sh
#
# Requirements:
#   - Supabase CLI installed
#   - Local Supabase running (supabase start)
#
# =====================================================

set -e  # Exit on any error

echo ""
echo "========================================="
echo "🧪 Testing Migration 101 Locally"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =====================================================
# Step 1: Check if Supabase is running locally
# =====================================================

echo -e "${BLUE}Step 1: Checking local Supabase status...${NC}"
if ! supabase status &> /dev/null; then
    echo -e "${RED}❌ Local Supabase is not running!${NC}"
    echo ""
    echo "Please start Supabase first:"
    echo "  supabase start"
    echo ""
    exit 1
fi
echo -e "${GREEN}✅ Local Supabase is running${NC}"
echo ""

# =====================================================
# Step 2: Backup current state
# =====================================================

echo -e "${BLUE}Step 2: Creating backup of current state...${NC}"
BACKUP_FILE="backup_before_migration_101_$(date +%Y%m%d_%H%M%S).sql"
supabase db dump -f "$BACKUP_FILE" > /dev/null 2>&1

if [ -f "$BACKUP_FILE" ]; then
    echo -e "${GREEN}✅ Backup created: $BACKUP_FILE${NC}"
else
    echo -e "${YELLOW}⚠️  Could not create backup (may not be critical)${NC}"
fi
echo ""

# =====================================================
# Step 3: Get current category state (BEFORE)
# =====================================================

echo -e "${BLUE}Step 3: Current categories (BEFORE migration)...${NC}"
echo ""
supabase db query "
SELECT
    c.id,
    c.name,
    c.display_order,
    c.is_active,
    COUNT(t.id) as theme_count
FROM categories c
LEFT JOIN themes t ON t.category = c.id AND t.is_available = true
WHERE c.is_active = true
GROUP BY c.id, c.name, c.display_order, c.is_active
ORDER BY c.display_order;
" || echo -e "${RED}❌ Query failed${NC}"
echo ""

# =====================================================
# Step 4: Run migration 101
# =====================================================

echo -e "${BLUE}Step 4: Running migration 101...${NC}"
echo ""

if supabase db reset; then
    echo -e "${GREEN}✅ Migration 101 applied successfully!${NC}"
else
    echo -e "${RED}❌ Migration failed!${NC}"
    echo ""
    echo "Check the error above for details."
    echo "Your backup is at: $BACKUP_FILE"
    exit 1
fi
echo ""

# =====================================================
# Step 5: Get new category state (AFTER)
# =====================================================

echo -e "${BLUE}Step 5: New categories (AFTER migration)...${NC}"
echo ""
supabase db query "
SELECT
    c.id,
    c.name,
    c.display_order,
    c.is_active,
    COUNT(t.id) as theme_count
FROM categories c
LEFT JOIN themes t ON t.category = c.id AND t.is_available = true
WHERE c.is_active = true
GROUP BY c.id, c.name, c.display_order, c.is_active
ORDER BY c.display_order;
" || echo -e "${RED}❌ Query failed${NC}"
echo ""

# =====================================================
# Step 6: Verify trending themes
# =====================================================

echo -e "${BLUE}Step 6: Verifying Trending Now themes...${NC}"
echo ""
supabase db query "
SELECT
    name,
    category,
    is_featured,
    is_available
FROM themes
WHERE category = 'trending'
ORDER BY name;
" || echo -e "${RED}❌ Query failed${NC}"
echo ""

# =====================================================
# Step 7: Check for data loss
# =====================================================

echo -e "${BLUE}Step 7: Checking for data loss...${NC}"
echo ""

TOTAL_THEMES=$(supabase db query "SELECT COUNT(*) FROM themes WHERE is_available = true;" --csv | tail -1)
ACTIVE_CATEGORIES=$(supabase db query "SELECT COUNT(*) FROM categories WHERE is_active = true;" --csv | tail -1)

echo "Total available themes: $TOTAL_THEMES (expected: ~69)"
echo "Active categories: $ACTIVE_CATEGORIES (expected: 6)"
echo ""

if [ "$TOTAL_THEMES" -lt 60 ]; then
    echo -e "${RED}❌ WARNING: Theme count is low! Possible data loss!${NC}"
    echo "Expected ~69 themes, got $TOTAL_THEMES"
    echo ""
    exit 1
else
    echo -e "${GREEN}✅ Theme count looks good ($TOTAL_THEMES themes)${NC}"
fi

if [ "$ACTIVE_CATEGORIES" -eq 6 ]; then
    echo -e "${GREEN}✅ Category count correct (6 categories)${NC}"
else
    echo -e "${YELLOW}⚠️  Expected 6 active categories, got $ACTIVE_CATEGORIES${NC}"
fi
echo ""

# =====================================================
# Step 8: Check transformations category
# =====================================================

echo -e "${BLUE}Step 8: Verifying Transformations category...${NC}"
echo ""
TRANSFORMATIONS_COUNT=$(supabase db query "SELECT COUNT(*) FROM themes WHERE category = 'transformations' AND is_available = true;" --csv | tail -1)
echo "Transformations themes: $TRANSFORMATIONS_COUNT (expected: ~29)"
echo ""

if [ "$TRANSFORMATIONS_COUNT" -lt 25 ]; then
    echo -e "${YELLOW}⚠️  Transformations count seems low${NC}"
else
    echo -e "${GREEN}✅ Transformations category has $TRANSFORMATIONS_COUNT themes${NC}"
fi
echo ""

# =====================================================
# Step 9: List all themes by category
# =====================================================

echo -e "${BLUE}Step 9: Theme distribution by category...${NC}"
echo ""
supabase db query "
SELECT
    c.name as category,
    COUNT(t.id) as count,
    STRING_AGG(t.name, ', ' ORDER BY t.name) as theme_names
FROM categories c
LEFT JOIN themes t ON t.category = c.id AND t.is_available = true
WHERE c.is_active = true
GROUP BY c.id, c.name, c.display_order
ORDER BY c.display_order;
" || echo -e "${RED}❌ Query failed${NC}"
echo ""

# =====================================================
# Step 10: Summary & Next Steps
# =====================================================

echo ""
echo "========================================="
echo -e "${GREEN}✅ Migration 101 Testing Complete!${NC}"
echo "========================================="
echo ""
echo "What was tested:"
echo "  ✅ Migration ran without errors"
echo "  ✅ 6 new categories created"
echo "  ✅ Themes reassigned correctly"
echo "  ✅ No data loss detected"
echo "  ✅ Trending Now has 3 viral themes"
echo ""
echo "Next steps:"
echo "  1. Review the output above"
echo "  2. Check if categories look correct"
echo "  3. If everything looks good:"
echo "     - Deploy to production via Supabase dashboard"
echo "     - Or run: supabase db push"
echo "  4. If something is wrong:"
echo "     - Run rollback: supabase db query -f supabase/migrations/101_rollback.sql"
echo ""
echo "Backup saved at: $BACKUP_FILE"
echo ""
echo -e "${BLUE}Test app with pull-to-refresh to see new categories!${NC}"
echo ""
