# Repository Restructuring - Migration Guide

**Date:** 2025-11-13
**Version:** 2.0
**Status:** ✅ Complete

## What Changed

The repository has been restructured to make it easier to pull Supabase specialists into your projects.

### Old Structure (v1.0)
```
awesome-claude-agents/
├── agents/                    # Mixed: Supabase specialists
├── .claude/                   # Generic Claude Code agents
├── docs/                      # Backend documentation
├── templates/                 # Code templates
└── CLAUDE.md                  # Generic instructions
```

**Problem**: Confusing to install, mixed purposes, unclear what to use.

### New Structure (v2.0)
```
awesome-claude-agents/
├── supabase-specialists/      ✨ NEW: Clear separation
│   ├── agents/                # 8 Supabase specialists
│   ├── docs/                  # Backend documentation
│   ├── templates/             # Code templates
│   └── CLAUDE.md              # Supabase-specific instructions
│
├── framework-agents/          ✨ NEW: Optional extras
│   └── .claude/               # 45 generic framework agents
│
└── install-supabase.sh       ✨ NEW: Smart installer
```

**Benefits:**
- ✅ Clear what to install (use `supabase-specialists/`)
- ✅ Smart installer handles everything
- ✅ Separate Supabase specialists from generic agents
- ✅ Easy to pull into projects
- ✅ No confusion about which agents to use

## Migration Steps

### If You Haven't Installed Yet
**You're good to go!** Just follow the new installation instructions in [README.md](README.md):

```bash
# Clone and install
git clone <repo-url>
cd awesome-claude-agents
./install-supabase.sh ~/your-project
```

### If You Already Have Old Version Installed

#### Option 1: Clean Install (Recommended)

1. **Remove old installation:**
```bash
# In your project
rm -rf .claude/agents/orchestrators/backend-tech-lead-orchestrator.md
rm -rf .claude/agents/specialized/supabase/
rm -rf docs/backend-architecture/
rm -rf templates/supabase-backend/
```

2. **Pull latest changes:**
```bash
cd /path/to/awesome-claude-agents
git pull origin main
```

3. **Run new installer:**
```bash
./install-supabase.sh ~/your-project
```

#### Option 2: Manual Update

1. **Update the repo:**
```bash
cd /path/to/awesome-claude-agents
git pull origin main
```

2. **Update agents in your project:**
```bash
cd ~/your-project
cp -r /path/to/awesome-claude-agents/supabase-specialists/agents/* .claude/agents/
```

3. **Update CLAUDE.md:**
```bash
# Backup first
cp CLAUDE.md CLAUDE.md.backup

# Replace with new version
cp /path/to/awesome-claude-agents/supabase-specialists/CLAUDE.md .
```

## What's Different

### 1. CLAUDE.md is Now Supabase-Focused

**Before:**
- Generic multi-framework instructions
- Mentioned Django, Rails, Laravel examples
- Unclear which orchestrator to use

**After:**
- Supabase-only instructions
- Clear examples with credit systems, IAP, Edge Functions
- Always use `backend-tech-lead-orchestrator`

### 2. Installation is Now Automated

**Before:**
- Manual copy commands
- Easy to miss files
- No conflict handling

**After:**
- One command: `./install-supabase.sh ~/your-project`
- Prompts before overwriting
- Handles conflicts smartly

### 3. Clear Separation of Concerns

**Before:**
- Mixed Supabase and generic agents in same directories
- Unclear what's needed vs optional

**After:**
- `supabase-specialists/` - Everything you need for Supabase
- `framework-agents/` - Optional extras (completely independent)

## Breaking Changes

### None! 🎉

The agents themselves haven't changed. Only the directory structure and installation method improved.

**Your existing projects will continue working** with the old installation. But we recommend updating to the new structure for easier maintenance.

## New Features

### Smart Installer (`install-supabase.sh`)

Features:
- ✅ Interactive prompts (overwrite existing files?)
- ✅ Colored output for clarity
- ✅ Handles CLAUDE.md merge or replace
- ✅ Updates .gitignore automatically
- ✅ Provides next steps after installation
- ✅ Validates target directory exists

### Improved Documentation

- README.md now shows clear repository structure
- Installation section completely rewritten
- Added "What You Can Build" examples
- Better links to documentation

## FAQ

### Q: Do I need to reinstall?
**A:** No, but recommended for easier future updates.

### Q: Will my existing projects break?
**A:** No, agents haven't changed - only how you install them.

### Q: What about the .claude/ folder with 45 agents?
**A:** That's now in `framework-agents/` and completely optional. Supabase specialists don't need it.

### Q: Can I still use symlinks?
**A:** Yes! The installer copies files, but you can symlink manually:
```bash
ln -sf /path/to/awesome-claude-agents/supabase-specialists/agents ~/.claude/agents/supabase
```

### Q: What if I want both Supabase + framework agents?
**A:** No problem:
```bash
# Install Supabase specialists to your project
./install-supabase.sh ~/your-project

# Optionally symlink framework agents globally
ln -sf "$(pwd)/framework-agents/.claude" ~/.claude-framework-agents
```

## Rollback (If Needed)

If you need to go back to the old structure:

```bash
cd awesome-claude-agents
git checkout v1.0  # Or specific old commit
```

But we don't recommend this - the new structure is much better!

## Support

If you encounter any issues:
1. Check [README.md](README.md) for updated instructions
2. Run `./install-supabase.sh --help` (if we add that)
3. Open an issue on GitHub
4. Review [CONTRIBUTING.md](CONTRIBUTING.md)

---

**Migration complete! Enjoy the cleaner structure and easier installation.** 🚀
