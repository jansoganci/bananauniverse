#!/bin/bash

# Supabase Backend Specialists Installer
# Installs agents, documentation, and templates to your project

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get project directory (default to current directory)
PROJECT_DIR="${1:-.}"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Supabase Backend Specialists Installer${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}📂 Target Directory:${NC} $PROJECT_DIR"
echo ""

# Check if target directory exists
if [ ! -d "$PROJECT_DIR" ]; then
    echo -e "${RED}❌ Error: Directory '$PROJECT_DIR' does not exist${NC}"
    echo ""
    echo "Usage: ./install-supabase.sh [project-directory]"
    echo "Example: ./install-supabase.sh ~/my-project"
    exit 1
fi

# Get absolute path
PROJECT_DIR=$(cd "$PROJECT_DIR" && pwd)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${YELLOW}⚠️  This will install:${NC}"
echo "  • 8 Supabase specialist agents"
echo "  • Backend architecture documentation"
echo "  • Code templates (iOS, Next.js, Supabase)"
echo "  • CLAUDE.md project instructions"
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Installation cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🚀 Starting installation...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Step 1: Create .claude directory if it doesn't exist
echo -e "${BLUE}[1/6]${NC} Creating .claude directory..."
mkdir -p "$PROJECT_DIR/.claude/agents"
echo -e "${GREEN}✓${NC} .claude directory ready"
echo ""

# Step 2: Copy agents
echo -e "${BLUE}[2/6]${NC} Installing Supabase specialist agents..."

if [ -d "$PROJECT_DIR/.claude/agents/orchestrators" ] || [ -d "$PROJECT_DIR/.claude/agents/specialized/supabase" ]; then
    echo -e "${YELLOW}⚠️  Existing Supabase agents found${NC}"
    read -p "Overwrite existing agents? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}⊘ Skipping agents installation${NC}"
    else
        cp -r "$SCRIPT_DIR/supabase-specialists/agents/"* "$PROJECT_DIR/.claude/agents/"
        echo -e "${GREEN}✓${NC} Agents installed (overwritten)"
    fi
else
    cp -r "$SCRIPT_DIR/supabase-specialists/agents/"* "$PROJECT_DIR/.claude/agents/"
    echo -e "${GREEN}✓${NC} 8 agents installed:"
    echo "  • backend-tech-lead-orchestrator"
    echo "  • supabase-database-architect"
    echo "  • credit-system-architect"
    echo "  • supabase-edge-function-developer"
    echo "  • provider-integration-specialist"
    echo "  • auth-security-specialist"
    echo "  • iap-verification-specialist"
    echo "  • backend-operations-engineer"
fi
echo ""

# Step 3: Copy documentation
echo -e "${BLUE}[3/6]${NC} Installing backend documentation..."

if [ -d "$PROJECT_DIR/docs/backend" ]; then
    echo -e "${YELLOW}⚠️  Existing backend docs found${NC}"
    read -p "Overwrite existing documentation? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}⊘ Skipping documentation${NC}"
    else
        rm -rf "$PROJECT_DIR/docs/backend"
        cp -r "$SCRIPT_DIR/supabase-specialists/docs" "$PROJECT_DIR/docs/backend-architecture"
        echo -e "${GREEN}✓${NC} Documentation installed (overwritten)"
    fi
else
    mkdir -p "$PROJECT_DIR/docs"
    cp -r "$SCRIPT_DIR/supabase-specialists/docs" "$PROJECT_DIR/docs/backend-architecture"
    echo -e "${GREEN}✓${NC} Documentation installed at: docs/backend-architecture/"
fi
echo ""

# Step 4: Copy templates
echo -e "${BLUE}[4/6]${NC} Installing code templates..."

if [ -d "$PROJECT_DIR/templates/supabase-backend" ]; then
    echo -e "${YELLOW}⚠️  Existing templates found${NC}"
    read -p "Overwrite existing templates? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}⊘ Skipping templates${NC}"
    else
        rm -rf "$PROJECT_DIR/templates/supabase-backend"
        cp -r "$SCRIPT_DIR/supabase-specialists/templates" "$PROJECT_DIR/templates/supabase-backend"
        echo -e "${GREEN}✓${NC} Templates installed (overwritten)"
    fi
else
    mkdir -p "$PROJECT_DIR/templates"
    cp -r "$SCRIPT_DIR/supabase-specialists/templates" "$PROJECT_DIR/templates/supabase-backend"
    echo -e "${GREEN}✓${NC} Templates installed at: templates/supabase-backend/"
fi
echo ""

# Step 5: Handle CLAUDE.md
echo -e "${BLUE}[5/6]${NC} Installing CLAUDE.md instructions..."

if [ -f "$PROJECT_DIR/CLAUDE.md" ]; then
    echo -e "${YELLOW}⚠️  Existing CLAUDE.md found${NC}"
    echo "Options:"
    echo "  1) Append Supabase instructions to existing file"
    echo "  2) Overwrite with Supabase-only instructions"
    echo "  3) Skip (keep existing CLAUDE.md)"
    read -p "Choose (1/2/3): " -n 1 -r
    echo ""

    case $REPLY in
        1)
            echo "" >> "$PROJECT_DIR/CLAUDE.md"
            echo "# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$PROJECT_DIR/CLAUDE.md"
            echo "# Supabase Backend Specialists" >> "$PROJECT_DIR/CLAUDE.md"
            echo "# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$PROJECT_DIR/CLAUDE.md"
            echo "" >> "$PROJECT_DIR/CLAUDE.md"
            cat "$SCRIPT_DIR/supabase-specialists/CLAUDE.md" >> "$PROJECT_DIR/CLAUDE.md"
            echo -e "${GREEN}✓${NC} Supabase instructions appended to CLAUDE.md"
            ;;
        2)
            cp "$SCRIPT_DIR/supabase-specialists/CLAUDE.md" "$PROJECT_DIR/CLAUDE.md"
            echo -e "${GREEN}✓${NC} CLAUDE.md replaced with Supabase instructions"
            ;;
        3)
            echo -e "${YELLOW}⊘ Keeping existing CLAUDE.md${NC}"
            ;;
        *)
            echo -e "${YELLOW}⊘ Invalid option, keeping existing CLAUDE.md${NC}"
            ;;
    esac
else
    cp "$SCRIPT_DIR/supabase-specialists/CLAUDE.md" "$PROJECT_DIR/CLAUDE.md"
    echo -e "${GREEN}✓${NC} CLAUDE.md created"
fi
echo ""

# Step 6: Create .gitignore entries
echo -e "${BLUE}[6/6]${NC} Updating .gitignore..."

if [ -f "$PROJECT_DIR/.gitignore" ]; then
    if ! grep -q "# Supabase Backend Specialists" "$PROJECT_DIR/.gitignore"; then
        echo "" >> "$PROJECT_DIR/.gitignore"
        echo "# Supabase Backend Specialists (optional - gitignore if you don't want to commit)" >> "$PROJECT_DIR/.gitignore"
        echo "# docs/backend-architecture/" >> "$PROJECT_DIR/.gitignore"
        echo "# templates/supabase-backend/" >> "$PROJECT_DIR/.gitignore"
        echo -e "${GREEN}✓${NC} .gitignore updated (entries commented out)"
    else
        echo -e "${YELLOW}⊘ .gitignore already has Supabase entries${NC}"
    fi
else
    echo -e "${YELLOW}⊘ No .gitignore found, skipping${NC}"
fi
echo ""

# Installation complete
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Installation complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}📦 Installed to:${NC} $PROJECT_DIR"
echo ""
echo -e "${YELLOW}📚 What's next?${NC}"
echo ""
echo "1. Navigate to your project:"
echo -e "   ${BLUE}cd $PROJECT_DIR${NC}"
echo ""
echo "2. Start Claude Code and use the orchestrator:"
echo -e "   ${BLUE}claude \"use @backend-tech-lead-orchestrator to build a credit system\"${NC}"
echo ""
echo "3. Explore the documentation:"
echo -e "   ${BLUE}docs/backend-architecture/backend-INDEX.md${NC}"
echo ""
echo "4. Check out templates:"
echo -e "   ${BLUE}templates/supabase-backend/${NC}"
echo ""
echo -e "${GREEN}Available agents:${NC}"
echo "  • backend-tech-lead-orchestrator (main orchestrator)"
echo "  • supabase-database-architect"
echo "  • credit-system-architect"
echo "  • supabase-edge-function-developer"
echo "  • provider-integration-specialist"
echo "  • auth-security-specialist"
echo "  • iap-verification-specialist"
echo "  • backend-operations-engineer"
echo ""
echo -e "${BLUE}Happy building! 🚀${NC}"
echo ""
