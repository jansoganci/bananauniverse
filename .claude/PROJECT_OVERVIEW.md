# BananaUniverse Project Overview

**Complete guide for AI assistants to understand and work with this project.**

## Quick Start

This is an iOS app built with SwiftUI + Supabase that provides AI-powered image processing using 27+ AI models. The app follows a "Steve Jobs" philosophy: simplicity, speed, and reliability.

### Key Facts

- **Platform:** iOS 15.0+ (SwiftUI)
- **Backend:** Supabase (PostgreSQL + Edge Functions)
- **AI Provider:** fal.ai (27+ models)
- **Architecture:** MVVM with feature-based structure
- **Database:** PostgreSQL with Row Level Security (RLS)
- **Authentication:** Supabase Auth (anonymous + email)

---

## Documentation Structure

### Core Documentation (Start Here)

1. **CLAUDE.md** - Quick reference for developers
2. **ARCHITECTURE.md** - Code structure and patterns
3. **DESIGN_SYSTEM.md** - UI/UX guidelines
4. **WORKFLOWS.md** - Development workflows

### Detailed Reference (For Deep Dives)

5. **API_REFERENCE.md** - All API endpoints and integrations
6. **DATA_MODELS.md** - All data models and relationships
7. **SERVICES_REFERENCE.md** - All services and their methods
8. **DATABASE_SCHEMA.md** - Database tables, functions, RLS
9. **SETUP_GUIDE.md** - Complete setup instructions

### Commands (For Common Tasks)

10. **commands/debug-edge-function.md** - Debug Edge Functions
11. **commands/deploy-function.md** - Deploy functions
12. **commands/new-feature.md** - Create new features
13. **commands/new-migration.md** - Create database migrations
14. **commands/test-quota.md** - Test quota system

---

## Project Structure

```
BananaUniverse/
├── App/                    # App entry point
│   ├── BananaUniverseApp.swift
│   └── ContentView.swift
├── Core/                   # Shared components
│   ├── Components/         # Reusable UI
│   ├── Config/             # Configuration
│   ├── Design/             # Design system
│   ├── Models/             # Data models
│   ├── Services/           # Business logic
│   └── Utils/              # Utilities
├── Features/               # Feature modules
│   ├── Authentication/     # Auth flows
│   ├── Chat/               # AI processing UI
│   ├── Home/               # Main dashboard
│   ├── Library/            # Image history
│   ├── Profile/            # Settings
│   └── Paywall/            # Subscriptions
└── supabase/               # Backend
    ├── functions/          # Edge Functions
    └── migrations/         # Database migrations
```

---

## Key Concepts

### 1. Quota System

- **Free users:** 5 requests/day
- **Premium users:** 3 requests/day (temporary)
- **Reset:** Midnight UTC
- **Tracking:** `daily_quota` table
- **Idempotency:** Request IDs prevent duplicate consumption

### 2. Authentication

- **Anonymous:** Uses `device_id` for tracking
- **Authenticated:** Uses Supabase Auth with JWT tokens
- **Unified:** Both use same quota system and database tables

### 3. Image Processing Flow

1. User uploads image
2. Image uploaded to Supabase Storage
3. Edge Function called with image URL
4. fal.ai processes image
5. Result uploaded to Storage
6. Database record created
7. Quota consumed
8. UI updates with result

### 4. Subscription System

- **StoreKit 2:** Native iOS subscriptions
- **Adapty:** Analytics and webhook sync
- **Server-side:** Subscription validation in database
- **Products:** Weekly ($4.99) and Yearly ($79.99)

---

## Common Tasks

### Adding a New Feature

1. Read `commands/new-feature.md`
2. Create feature folder in `Features/`
3. Follow MVVM pattern
4. Use design tokens from `DesignTokens.swift`
5. Update navigation in `ContentView.swift`

### Debugging Edge Function

1. Read `commands/debug-edge-function.md`
2. Check logs: `supabase functions logs process-image`
3. Test locally: `supabase functions serve process-image`
4. Verify environment variables: `supabase secrets list`

### Creating Database Migration

1. Read `commands/new-migration.md`
2. Create migration: `supabase migration new feature_name`
3. Write SQL in migration file
4. Test locally: `supabase db reset`
5. Deploy: `supabase db push`

### Fixing Quota Issues

1. Read `commands/test-quota.md`
2. Check `daily_quota` table
3. Verify RLS policies
4. Test `consume_quota` function
5. Check Edge Function logs

---

## Development Rules

### Must Follow

1. **Use design tokens** - Never hardcode colors/spacing
2. **Follow MVVM** - Views are dumb, ViewModels are smart
3. **Test locally first** - Always test with `supabase start`
4. **RLS policies** - All tables must have RLS enabled
5. **Error handling** - Use proper async/await error handling

### Code Style

- **Swift:** Follow SwiftUI best practices
- **TypeScript:** Follow Deno best practices
- **SQL:** Use migrations, never direct SQL
- **Comments:** Document complex logic, not obvious code

### File Naming

- **Views:** `FeatureView.swift`
- **ViewModels:** `FeatureViewModel.swift`
- **Services:** `FeatureService.swift`
- **Models:** `FeatureModel.swift`

---

## Architecture Principles

### Steve Jobs Philosophy

> "Simplicity is the ultimate sophistication"

- **Single Edge Function:** One function handles all AI processing
- **Direct Processing:** No polling, immediate results
- **Clean Separation:** iOS handles UI, Edge Function handles AI
- **Fast & Reliable:** < 35 seconds processing time, 99%+ success rate

### MVVM Pattern

```
View (SwiftUI)
  ↓
ViewModel (@ObservableObject)
  ↓
Service (Business Logic)
  ↓
Supabase/API
```

### Feature-Based Structure

Each feature is self-contained:
- Views in `Features/FeatureName/Views/`
- ViewModels in `Features/FeatureName/ViewModels/`
- Models in `Core/Models/` (shared)
- Services in `Core/Services/` (shared)

---

## Database Architecture

### Key Tables

- `daily_quota` - Tracks daily quota usage
- `processed_images` - Image processing history
- `subscriptions` - Server-side subscription validation
- `refunds` - Quota refund tracking

### RLS Policies

- Users can only access their own data
- Anonymous users tracked by `device_id`
- Service role has admin access

### Functions

- `get_quota()` - Get current quota status
- `consume_quota()` - Consume quota (idempotent)
- `refund_quota()` - Refund quota (idempotent)
- `sync_subscription()` - Sync subscription from Adapty

---

## API Integration

### Edge Functions

- `process-image` - Main AI processing endpoint
- `sync-subscription` - Subscription webhook handler
- `cleanup-db` - Maintenance tasks
- `cleanup-images` - Storage cleanup

### External APIs

- **fal.ai:** AI model processing
- **Adapty:** Subscription analytics
- **StoreKit 2:** Native iOS subscriptions

---

## Testing Checklist

### Before Committing

- [ ] Code compiles without warnings
- [ ] All features work locally
- [ ] Edge Functions tested locally
- [ ] Database migrations tested
- [ ] RLS policies verified
- [ ] Quota system works correctly
- [ ] Error handling implemented

### Before Deploying

- [ ] All migrations applied
- [ ] Edge Functions deployed
- [ ] Environment variables set
- [ ] Storage bucket configured
- [ ] RLS policies enabled
- [ ] Production API keys configured

---

## Troubleshooting Guide

### Common Issues

**Problem:** App crashes on launch
- **Solution:** Check Info.plist has Supabase credentials

**Problem:** Edge Function timeout
- **Solution:** Check fal.ai API key, verify network

**Problem:** Quota not updating
- **Solution:** Check RLS policies, verify `consume_quota` function

**Problem:** Images not displaying
- **Solution:** Check storage bucket permissions, verify URLs

**Problem:** Subscriptions not working
- **Solution:** Verify StoreKit configuration, check product IDs

### Debug Commands

```bash
# Check Supabase status
supabase status

# View Edge Function logs
supabase functions logs process-image --follow

# Test database query
supabase db execute "SELECT * FROM daily_quota LIMIT 5;"

# Check migrations
supabase migration list
```

---

## Quick Reference

### Important Files

- `Config.swift` - App configuration
- `AppState.swift` - Global state
- `process-image/index.ts` - Main Edge Function
- `ContentView.swift` - Main navigation

### Important Commands

```bash
# iOS
cmd + R              # Run app
cmd + B              # Build
cmd + Shift + K      # Clean

# Supabase
supabase start       # Local dev
supabase db reset    # Reset database
supabase functions deploy process-image  # Deploy function
```

### Important URLs

- Supabase Dashboard: `https://supabase.com/dashboard`
- fal.ai Dashboard: `https://fal.ai/dashboard`
- Adapty Dashboard: `https://adapty.io/dashboard`

---

## Getting Help

### Documentation

1. Start with `CLAUDE.md` for quick reference
2. Check `ARCHITECTURE.md` for code structure
3. Read `API_REFERENCE.md` for API details
4. Review `SETUP_GUIDE.md` for setup issues

### Debugging

1. Check logs: `supabase functions logs`
2. Review migrations: `supabase/migrations/`
3. Test locally: `supabase start`
4. Verify configuration: `Config.swift`

---

## Summary

This project is a **professional iOS app** for AI image processing with:
- **27+ AI tools** across 4 categories
- **Quota system** (5/day free, 3/day premium)
- **WhatsApp-style chat** interface
- **Serverless backend** (Supabase Edge Functions)
- **Native subscriptions** (StoreKit 2)

**Architecture:** MVVM with feature-based structure
**Database:** PostgreSQL with RLS
**Backend:** Supabase Edge Functions (Deno/TypeScript)
**Frontend:** SwiftUI (iOS)

**Key Principle:** Simplicity, speed, and reliability above all else.

---

## Next Steps

1. **New to project?** → Read `SETUP_GUIDE.md`
2. **Adding features?** → Read `ARCHITECTURE.md` + `commands/new-feature.md`
3. **Debugging?** → Read `commands/debug-edge-function.md`
4. **API questions?** → Read `API_REFERENCE.md`
5. **Database questions?** → Read `DATABASE_SCHEMA.md`

---

**Last Updated:** 2024-11-01
**Version:** 1.0.1

