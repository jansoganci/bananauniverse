# CLAUDE.md

**Project:** BananaUniverse  
**Type:** iOS App (SwiftUI + Supabase)  
**Purpose:** Professional AI Image Processing Suite

## Tech Stack
- **Frontend:** SwiftUI, MVVM architecture
- **Backend:** Supabase Edge Functions (Deno/TypeScript)
- **AI:** fal.ai models (19+ tools)
- **Database:** Supabase PostgreSQL with RLS
- **Auth:** Supabase Auth (anonymous + email)

## Architecture
- Feature-based folder structure
- ObservableObject view models
- Centralized AppState management
- Reactive UI with @Published properties

## Key Services
- `HybridCreditManager`: Quota system (5/day free, 100/day premium)
- `AuthService`: User authentication
- `SeasonalManager`: Dynamic content
- Edge Function: `process-image` (AI processing pipeline)

## Development Rules
- Use existing design tokens from `DesignTokens.swift`
- Follow MVVM pattern with proper state management
- Test locally with `supabase start` before deploying
- Always use RLS policies for database security
- Handle async/await properly with error boundaries

## Common Commands
```bash
# iOS
cmd + R              # Run app
cmd + B              # Build
cmd + Shift + K      # Clean

# Supabase
supabase start       # Local dev
supabase db reset    # Reset with migrations
supabase functions deploy process-image
supabase functions logs process-image
```

## Current Focus
- Quota system optimization
- Image processing pipeline reliability
- Authentication flow improvements
- Performance monitoring

## File Locations
- Models: `Core/Models/`
- Services: `Core/Services/`
- Views: `Features/{Feature}/Views/`
- ViewModels: `Features/{Feature}/ViewModels/`
- Edge Functions: `supabase/functions/`
- Migrations: `supabase/migrations/`