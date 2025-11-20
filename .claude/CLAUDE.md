# CLAUDE.md

**Project:** BananaUniverse
**Type:** iOS App (SwiftUI + Supabase)
**Purpose:** Professional AI Image Processing Suite with 19+ AI-powered tools

## Tech Stack
- **Frontend:** SwiftUI, MVVM architecture
- **Backend:** Supabase Edge Functions (Deno/TypeScript)
- **AI:** fal.ai models (19+ tools)
- **Database:** Supabase PostgreSQL with RLS
- **Auth:** Supabase Auth (anonymous + email + Apple Sign-In)
- **Payments:** StoreKit 2 (IAP for credit purchases)

## Architecture Overview

### Design Pattern
- Feature-based folder structure
- MVVM with ObservableObject view models
- Centralized AppState management
- Reactive UI with @Published properties
- Protocol-oriented services (enables testing/mocking)

### Credit System (Persistent Model)
- **Default:** 10 credits per user (persistent, not daily)
- **Consumption:** 1 credit per image generation
- **Purchasing:** Credit packs via StoreKit IAP (10, 25, 50, 100)
- **Storage:** Device-local cache + backend sync
- **Architecture:**
  - `CreditManager` - UI state orchestration (@MainActor)
  - `QuotaService` - Network calls (actor)
  - `QuotaCache` - Persistent storage (UserDefaults)

### Database-Driven Content
- **Themes Table:** All 19+ tools stored in Supabase
- **Categories Table:** Dynamic category system with display ordering
- **Benefits:** Remote content management, no app updates for new tools
- **Services:** `ThemeService`, `CategoryService` with 5-minute caching

## Key Services

### Core Services
- `CreditManager` - Credit state management, UI orchestration
- `HybridAuthService` - Authentication (anonymous/email/Apple)
- `SupabaseService` - Supabase client wrapper
- `ThemeService` - Fetches tools from database
- `CategoryService` - Fetches categories from database
- `StoreKitService` - IAP purchase handling
- `QuotaService` - Credit network operations
- `QuotaCache` - Credit persistence layer
- `ThemeManager` - App theming (light/dark/auto)
- `SeasonalManager` - Dynamic seasonal content
- `StorageService` - User data persistence
- `NetworkMonitor` - Connectivity monitoring

### Edge Functions (12 Total)
**Core Processing:**
- `submit-job` - Submits AI generation jobs, consumes credits
- `get-result` - Fetches generation results
- `webhook-handler` - Handles fal.ai webhooks

**IAP & Payments:**
- `verify-iap-purchase` - Verifies App Store receipts
- `iap-webhook` - Handles Apple server notifications

**Maintenance:**
- `cleanup-db` - Database cleanup tasks
- `cleanup-images` - Storage cleanup
- `cleanup-logs` - Log rotation

**Monitoring:**
- `health-check` - System health
- `log-alert` - Alert notifications
- `log-monitor` - Log monitoring

## Database Schema (Key Tables)

### User & Credits
- `user_credits` - Persistent credit balances (user_id or device_id)
- `credit_transactions` - Audit log of all credit changes
- `iap_transactions` - Purchase history with Apple transaction IDs

### Content Management
- `themes` - AI tools/effects (19+ entries, database-driven)
- `categories` - Tool categories with display ordering
- `iap_products` - StoreKit product definitions

### Processing
- `processed_images` - Generation job tracking
- `image_storage` - Storage bucket references

### Monitoring
- `rate_limits` - API rate limiting
- `error_logs` - Error tracking

## Development Rules

### Code Quality
- Use existing design tokens from `DesignTokens.swift`
- Follow MVVM pattern with proper state management
- Use protocol-oriented design for testability
- Handle async/await properly with error boundaries
- All @MainActor services should be marked explicitly

### Testing & Deployment
- Test locally with `supabase start` before deploying
- Always use RLS policies for database security
- Run migrations before deploying functions
- Test IAP in sandbox environment first

### Security
- Never commit Supabase keys (use Config.swift)
- Always validate purchases server-side
- Use RLS policies for all tables
- Sanitize user input (search queries, etc.)

## Common Commands

### iOS Development
```bash
cmd + R              # Run app
cmd + B              # Build
cmd + Shift + K      # Clean build folder
cmd + U              # Run tests
```

### Supabase Local Development
```bash
supabase start       # Start local dev
supabase db reset    # Reset with migrations
supabase stop        # Stop local instance
```

### Edge Functions
```bash
# Deploy specific function
supabase functions deploy submit-job
supabase functions deploy get-result
supabase functions deploy verify-iap-purchase

# View logs
supabase functions logs submit-job
supabase functions logs get-result --tail
```

### Database
```bash
# Create new migration
supabase migration new <migration_name>

# Apply migrations
supabase db push

# View database
supabase db diff
```

## Project Structure

```
BananaUniverse/
├── App/
│   ├── BananaUniverseApp.swift    # App entry point
│   ├── ContentView.swift          # Main tab navigation
│   └── AppDelegate.swift          # App lifecycle
├── Core/
│   ├── Models/                    # Data models (Theme, Category, CreditInfo, etc.)
│   ├── Services/                  # Business logic services
│   ├── Components/                # Reusable UI components
│   ├── Design/                    # Design system (tokens, colors, extensions)
│   ├── Config/                    # Configuration (Supabase keys, etc.)
│   └── Extensions/                # Swift extensions
├── Features/
│   ├── Home/                      # Home screen (tool browsing)
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   └── Previews/
│   ├── Chat/                      # AI generation interface
│   ├── Library/                   # History & saved images
│   ├── Profile/                   # User profile & settings
│   ├── Paywall/                   # Credit purchase flow
│   └── Authentication/            # Login/signup views
└── supabase/
    ├── functions/                 # Edge Functions (TypeScript/Deno)
    └── migrations/                # SQL migrations (85+)
```

## File Locations (Detailed)
- **Models:** `Core/Models/` (Theme.swift, Category.swift, CreditInfo.swift, UserState.swift)
- **Services:** `Core/Services/` (CreditManager, ThemeService, StoreKitService, etc.)
- **Views:** `Features/{Feature}/Views/`
- **ViewModels:** `Features/{Feature}/ViewModels/`
- **Components:** `Core/Components/` (QuotaDisplayView, FeaturedCarousel, etc.)
- **Design System:** `Core/Design/` (DesignTokens.swift, Color+DesignSystem.swift)
- **Edge Functions:** `supabase/functions/`
- **Migrations:** `supabase/migrations/`

## Current Features

### AI Tools (19+, Database-Driven)
- Object removal (lama-cleaner)
- Background removal
- Image upscaling
- Style transfers (anime, retro, toy style)
- Seasonal themes (Christmas, Thanksgiving)
- Professional headshots
- Meme generation
- Animated vehicle transformations
- And more...

### User Features
- Anonymous browsing (device-based credits)
- Email/Apple Sign-In authentication
- Credit-based usage model
- Purchase history tracking
- Image library with job status
- Real-time generation progress
- Dark/light mode support

## Recent Updates (Nov 2025)
- ✅ Converted to persistent credit system (Nov 13-14)
- ✅ Database-driven tools/categories (Nov 14)
- ✅ Seasonal expansion (Thanksgiving, Christmas)
- ✅ StoreKit 2 IAP integration
- ✅ Category display ordering improvements (Nov 15)
- ✅ Credit transaction logging
- ✅ Theme thumbnail support

## Known Patterns

### Credit Flow
1. User starts with 10 credits (cached locally + backend)
2. Submit job → `submit-job` function deducts 1 credit atomically
3. Backend returns updated balance in response
4. `CreditManager` updates UI state + cache
5. Low credit warning at ≤1 credits
6. Purchase flow via StoreKit → `verify-iap-purchase` → credits added

### Tool Loading Flow
1. `HomeViewModel` calls `ThemeService.fetchThemes()`
2. ThemeService checks 5-minute cache
3. If expired, fetches from Supabase `themes` table
4. Themes filtered by `is_available=true`
5. Sorted by `is_featured` and `name`
6. UI updates reactively via @Published

### Authentication Flow
1. App starts → `HybridAuthService` checks session
2. If no session → anonymous mode (device UUID)
3. User signs in → `CreditManager.initializeNewUser()`
4. Backend merges anonymous credits if applicable
5. Auth state listener updates `userState` @Published property

## Troubleshooting

### Common Issues
- **Credits not updating:** Check `QuotaCache` migration, restart app
- **Tools not loading:** Verify Supabase connection, check `themes` table RLS
- **IAP not working:** Ensure StoreKit testing in sandbox, check `verify-iap-purchase` logs
- **Build errors:** Clean build folder (cmd+shift+K), delete DerivedData

### Debug Flags
- All services have `#if DEBUG` print statements
- CreditManager logs: `📊 [CREDITS]`
- ThemeService logs: `🌐 ThemeService:`
- Auth logs: `🔄 [AUTH]`

## Performance Notes
- ThemeService: 5-minute cache (reduces API calls)
- CategoryService: 5-minute cache
- CreditManager: Single-flight loading (prevents concurrent calls)
- Images: Lazy loading with thumbnail support
- Background refresh: Credits update on app foreground

## Security Considerations
- RLS policies on all user tables
- Server-side IAP verification (never trust client)
- Device UUID for anonymous tracking (privacy-friendly)
- Credit consumption is atomic (database-level)
- Search input sanitization (100 char limit, alphanumeric only)

---

**Last Updated:** November 15, 2025
**Migration Count:** 85+
**Tools Available:** 19+
**Edge Functions:** 12

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Supabase Backend Specialists - Agent Orchestration Rules
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the **AI Team of Jans - Supabase Backend Specialists** repository. It contains a specialized collection of 8 AI agents focused exclusively on building production-ready Supabase backends with:

- **Credit/Quota Systems** - Atomic operations, audit trails, rollback logic
- **In-App Purchase (IAP) Verification** - Apple App Store Server API, subscriptions, refunds
- **Authentication** - Apple Sign-In, DeviceCheck, Email/Password, guest accounts
- **External API Integration** - Video generation (FalAI, Runway, Pika), retry logic, webhooks
- **Operations** - Error tracking (Sentry), Telegram alerts, rate limiting, testing

**Important**: This is NOT a multi-framework agent collection. These agents are **laser-focused on Supabase backends** using PostgreSQL, Edge Functions (Deno), and Row-Level Security.

## When to Use This Project

**✅ Use these agents if you're building:**
- Video generation apps with credit-based systems
- AI-powered applications with quota management
- Mobile apps with IAP verification (Apple)
- SaaS products with Supabase backends
- Apps requiring atomic financial operations

**❌ Do NOT use these agents if you're building:**
- Django/Rails/Laravel backends (different stack)
- Non-Supabase backends
- Apps without credit/payment systems
- General web development projects

## Orchestration Pattern

Since sub-agents in Claude Code cannot directly invoke other sub-agents, orchestration follows this strict pattern:

### CRITICAL: Agent Routing Protocol

**When handling Supabase backend tasks, you MUST:**

1. **ALWAYS start with backend-tech-lead-orchestrator** for any multi-step backend task
2. **FOLLOW the agent routing map** returned by tech-lead EXACTLY
3. **USE ONLY the Supabase specialists** explicitly recommended by tech-lead
4. **NEVER select agents independently** - tech-lead knows which specialists exist

### Example: Building a Credit System with IAP

```
User: "Build a credit system with Apple IAP verification"

Main Claude Agent:
1. First, I'll use the backend-tech-lead-orchestrator to analyze and get routing
   → Tech lead returns Agent Routing Map with SPECIFIC Supabase agents

2. I MUST use ONLY the agents listed in the routing map:
   - If tech-lead says "use credit-system-architect" → Use that EXACT agent
   - If tech-lead says "use iap-verification-specialist" → Use that EXACT agent
   - DO NOT substitute with generic agents unless specified as fallback

3. Execute tasks in the order specified by tech-lead using TodoWrite
```

### Key Orchestration Rules

1. **Backend Tech-Lead is Routing Authority**: Tech-lead determines which Supabase specialist handles each task
2. **Strict Agent Selection**: Use ONLY agents from tech-lead's "Available Agents" list
3. **No Improvisation**: Do NOT select agents based on your own judgment
4. **Maximum 2 Parallel Agents**: Control context usage by limiting parallel execution
5. **Structured Handoffs**: Extract and pass information between specialist invocations

### Agent Selection Flow

```
CORRECT FLOW:
User Request → Backend Tech-Lead Analysis → Agent Routing Map → Execute with Supabase Specialists

INCORRECT FLOW:
User Request → Main Agent Guesses → Wrong Agent Selected → Task Fails
```

### Example Tech-Lead Response You Must Follow

When backend-tech-lead returns:
```
## Available Agents for This Project
- supabase-database-architect: PostgreSQL schemas, RLS, stored procedures
- credit-system-architect: Atomic credit operations
- iap-verification-specialist: Apple IAP verification
- auth-security-specialist: Apple Sign-In, DeviceCheck
```

You MUST use these specific Supabase specialists, NOT generic alternatives like "backend-developer"

## Agent Organization

### 1. Orchestrator (`agents/orchestrators/`)

**backend-tech-lead-orchestrator** (uses Opus model)
- Analyzes Supabase backend requirements
- Coordinates all 7 Supabase specialists
- Returns structured Agent Routing Map
- Ensures proper layer separation (Database → API → Security → Operations)

### 2. Supabase Backend Specialists (`agents/specialized/supabase/`)

The 7 specialized agents that execute backend tasks:

**Database Layer:**
1. **supabase-database-architect**
   - PostgreSQL schemas, RLS policies, indexes
   - Database migrations
   - Stored procedures design
   - Query optimization

2. **credit-system-architect**
   - Atomic credit operations with `FOR UPDATE` locking
   - Stored procedures: `add_credits()`, `deduct_credits()`
   - Audit trails with balance snapshots
   - Rollback logic for failed operations
   - Prevents race conditions and duplicate charges

**API Layer:**
3. **supabase-edge-function-developer**
   - Deno Edge Functions
   - REST API endpoints
   - Error handling
   - Request validation

4. **provider-integration-specialist**
   - External API integration (FalAI, Runway, Pika, StabilityAI)
   - Idempotency patterns (HTTP + database)
   - Webhook systems
   - Retry logic with exponential backoff
   - Multi-provider abstraction with health monitoring

**Security Layer:**
5. **auth-security-specialist**
   - Apple Sign-In + DeviceCheck
   - Email/Password authentication (Supabase Auth)
   - JWT token management
   - Guest account patterns
   - Account merging (guest → authenticated)

6. **iap-verification-specialist**
   - Server-side Apple IAP verification
   - App Store Server API integration
   - Subscription lifecycle (7 states: active → grace → expired)
   - Refund processing with fraud detection
   - Products database patterns

**Operations Layer:**
7. **backend-operations-engineer**
   - Sentry error tracking setup
   - Telegram alert configuration
   - Rate limiting implementation
   - Testing infrastructure (API tests, load tests)
   - Metrics collection and monitoring

## Orchestration Workflow

The main Claude agent implements this workflow using the backend-tech-lead-orchestrator:

1. **Analysis Phase**: Backend tech-lead analyzes Supabase requirements and returns routing map
2. **Planning Phase**: Main agent creates tasks with TodoWrite based on tech-lead's recommendations
3. **Execution Phase**: Main agent invokes Supabase specialists sequentially (max 2 in parallel)
4. **Coordination**: Main agent extracts findings and passes context between specialists

### Agent Communication Protocol

Since sub-agents cannot directly communicate:
- **Structured Returns**: Each specialist returns findings in parseable format
- **Context Passing**: Main agent extracts relevant information from returns
- **Sequential Coordination**: Main agent manages execution flow
- **Handoff Information**: Specialists include what next specialist needs

Example return format:
```
## Task Completed: Credit System Database Schema

### Created Tables
- users (credits_remaining, credits_total)
- quota_log (audit trail with balance snapshots)
- products (IAP product configurations)

### Created Stored Procedures
- add_credits(user_id, amount, reason, transaction_id)
- deduct_credits(user_id, amount, reason)

### Next Specialist Needs
- Table names: users, quota_log, products
- Stored procedure signatures for Edge Function calls
- RLS policies are configured (authenticated users can read their own data)

Handoff to: credit-system-architect for atomic credit operations implementation
```

## Complete Orchestration Example

Here's a full example showing proper Supabase backend orchestration:

### User Request:
"Build a credit-based video generation backend with Apple IAP"

### Step 1: Backend Tech-Lead Analysis
```
Main Agent: "I'll use the backend-tech-lead-orchestrator to analyze this Supabase backend requirement."

[Invokes backend-tech-lead-orchestrator]
```

### Step 2: Backend Tech-Lead Returns Routing Map
```
## Task Analysis
- Need video generation API with credit system
- Supabase backend: PostgreSQL + Edge Functions (Deno)
- Apple Sign-In, IAP for credits, FalAI for video generation
- Key patterns: atomic credit deduction, idempotency, rollback on failure

## SubAgent Assignments
Task 1: Design database schema (users, models, video_jobs, quota_log) → AGENT: supabase-database-architect
Task 2: Create RLS policies for data isolation → AGENT: supabase-database-architect
Task 3: Build credit system stored procedures (deduct/add credits atomically) → AGENT: credit-system-architect
Task 4: Create device-check endpoint (guest onboarding) → AGENT: supabase-edge-function-developer
Task 5: Build generate-video endpoint with idempotency → AGENT: supabase-edge-function-developer
Task 6: Integrate FalAI provider with rollback logic → AGENT: provider-integration-specialist
Task 7: Add Apple Sign-In and DeviceCheck verification → AGENT: auth-security-specialist
Task 8: Implement IAP verification for credit purchases → AGENT: iap-verification-specialist
Task 9: Set up Sentry error tracking and Telegram alerts → AGENT: backend-operations-engineer

## Execution Order
- **Sequential**: Task 1 → Task 2 → Task 3 (database foundation)
- **Parallel**: Tasks 4, 5 after Task 3 (Edge Functions)
- **Sequential**: Task 6 after Task 5 (provider integration)
- **Parallel**: Tasks 7, 8 after Task 6 (security layer)
- **Sequential**: Task 9 after all (operations last)

## Available Agents for This Project
- supabase-database-architect: PostgreSQL schema, RLS, indexes
- credit-system-architect: Atomic credit operations with stored procedures
- supabase-edge-function-developer: Deno Edge Functions, REST APIs
- provider-integration-specialist: FalAI integration, idempotency, webhooks
- auth-security-specialist: Apple Sign-In, DeviceCheck, JWT
- iap-verification-specialist: Server-side IAP verification
- backend-operations-engineer: Sentry, Telegram alerts, monitoring

## Instructions to Main Agent
- Delegate task 1 to supabase-database-architect (database schema)
- After task 1, delegate task 2 to supabase-database-architect (RLS)
- After task 2, delegate task 3 to credit-system-architect (stored procedures)
- After task 3, run tasks 4 and 5 in parallel using supabase-edge-function-developer
- After task 5, delegate task 6 to provider-integration-specialist
- After task 6, run tasks 7 and 8 in parallel (auth and IAP)
- After all tasks complete, delegate task 9 to backend-operations-engineer
```

### Step 3: Main Agent Executes Plan
```
Main Agent: "Based on the backend tech-lead's routing, I'll coordinate the Supabase backend implementation:"

1. ✓ Using supabase-database-architect for database schema
2. ✓ Using supabase-database-architect for RLS policies
3. ✓ Using credit-system-architect for atomic stored procedures
4. ✓ Using supabase-edge-function-developer for Edge Functions (parallel)
5. ✓ Using provider-integration-specialist for FalAI integration
6. ✓ Using auth-security-specialist for Apple Sign-In (parallel with IAP)
7. ✓ Using iap-verification-specialist for IAP verification (parallel with auth)
8. ✓ Using backend-operations-engineer for monitoring setup

[Executes each step with the EXACT Supabase specialists specified]
```

### What NOT to Do:
```
❌ "I'll use backend-developer" (when tech-lead specified supabase-database-architect)
❌ "I'll use django-api-developer" (wrong stack - this is Supabase/Deno, not Django)
❌ "I'll skip the tech-lead and choose agents myself" (bypasses routing)
❌ "I'll run all tasks in parallel" (violates max 2 parallel rule)
```

## Key Backend Principles

These Supabase specialists follow strict principles:

1. **Database First**: Always start with schema, RLS policies, and stored procedures
2. **Atomic Operations**: Use stored procedures with `FOR UPDATE` for financial operations
3. **Idempotency**: All state-changing operations must be idempotent (HTTP + DB level)
4. **Rollback Logic**: Every credit deduction must have a refund path
5. **Security by Default**: RLS policies, server-side verification, never trust client
6. **Audit Trail**: Log all transactions with balance snapshots
7. **Error Tracking**: Set up Sentry and Telegram alerts before launching

## Documentation Reference

Comprehensive backend documentation is now available in your project:

### Backend Architecture (`docs/backend-architecture/backend/`)
- `backend-INDEX.md` - Overview of all backend documentation (6 comprehensive guides)
- `backend-1-overview-database.md` - System architecture, database schemas, RLS policies (17KB)
- `backend-2-core-apis.md` - API endpoints, request/response patterns (16KB)
- `backend-3-generation-workflow.md` - Video generation, provider integration, webhooks (19KB)
- `backend-4-auth-security.md` - Authentication flows, security best practices (13KB)
- `backend-5-credit-system.md` - Credit management, atomic operations, audit trails (13KB)
- `backend-6-operations-testing.md` - Monitoring, error tracking, deployment (18KB)

**Total Backend Architecture Docs: ~100KB of production-tested patterns**

### Implementation Guides (`docs/backend-architecture/`)
- `IAP-IMPLEMENTATION-STRATEGY.md` - Complete IAP guide (products, subscriptions, refunds, fraud detection) (35KB)
- `EXTERNAL-API-STRATEGY.md` - Multi-provider integration, retry logic, failover, webhooks (32KB)
- `AUTH-DECISION-FRAMEWORK.md` - Authentication strategy decision framework (18KB)
- `EMAIL-PASSWORD-AUTH.md` - Supabase Auth setup with email/password (15KB)
- `EMAIL-SERVICE-INTEGRATION.md` - Resend + Supabase for transactional emails (9KB)
- `OPERATIONS-MONITORING-CHECKLIST.md` - Production readiness (7 checklists: Sentry, Telegram, Rate Limiting) (20KB)
- `FRONTEND-SUPABASE-INTEGRATION.md` - Next.js + Supabase client patterns (15KB)
- `FRONTEND-AUTH-PATTERNS.md` - Frontend authentication patterns and best practices (16KB)

**Total Implementation Guides: ~160KB of detailed strategies**

### Templates (Available in `.ai-team/templates/`)
Templates are available in the `.ai-team/` directory and can be copied when needed:
- `ios/Services/` - Swift services (SupabaseAuth, CreditSystem, IAPManager)
- `ios-testing-suite/` - Complete iOS testing framework with mocks and examples
- `nextjs/` - Next.js auth pages, components, middleware, Supabase client setup
- `supabase/functions/` - Edge Function examples with shared utilities
- `supabase/migrations/` - Database migration templates (credit system, IAP, async jobs)

**Note**: Copy templates to your project when starting new features

## Agent Definition Format

```yaml
---
name: agent-name
description: |
  Supabase-specific expertise description
  Examples:
  - <example>
    Context: Supabase backend scenario
    user: "Build credit system"
    assistant: "I'll use credit-system-architect"
    <commentary>Atomic operations required</commentary>
  </example>
# tools: omit for all tools (recommended for Supabase specialists)
model: opus  # backend-tech-lead-orchestrator uses opus for complex reasoning
---

# Agent Name - Supabase Specialist

System prompt focused on Supabase/PostgreSQL/Edge Functions...
```

## Development Guidelines

1. **Creating New Supabase Specialists**:
   - Focus on single Supabase domain (database, API, auth, IAP, provider, operations)
   - Include 2-3 XML examples with Supabase scenarios
   - Define structured return format with handoff information
   - Reference relevant documentation in `docs/backend/`

2. **Agent Return Patterns**:
   - Always return findings in structured format
   - Include "Next Specialist Needs" section
   - List created resources (tables, functions, endpoints)
   - Specify handoff to next Supabase specialist

3. **Testing Agents**:
   - Test with real Supabase backend scenarios
   - Verify atomic operations work correctly
   - Ensure RLS policies are properly configured
   - Test idempotency patterns

## Critical Reminders

- **ALWAYS use backend-tech-lead-orchestrator** for multi-step Supabase backend tasks
- **FOLLOW the agent routing map exactly** - use only listed Supabase specialists
- **MAXIMUM 2 agents in parallel** - control context usage
- **Database layer first** - schema, RLS, stored procedures before APIs
- **Never trust client** - all financial operations server-side
- **Atomic operations** - use stored procedures with `FOR UPDATE`
- **Idempotency everywhere** - both HTTP and database level
- **Audit trails** - log every credit transaction with balance snapshots
- **Rollback logic** - every deduction needs a refund path
- **Error tracking** - Sentry + Telegram alerts are mandatory

## Anti-Patterns to Avoid

❌ Building API before database schema
❌ Trusting client-sent credit amounts
❌ Skipping idempotency for payment operations
❌ Forgetting rollback logic on failures
❌ Missing RLS policies on tables
❌ No error tracking in production
❌ Hardcoding product configurations (use products database)
❌ Using generic "backend-developer" instead of Supabase specialists
❌ Running more than 2 agents in parallel

---

**This project is specialized for Supabase backends with credit systems, IAP verification, and external API integration. For other backend stacks (Django, Rails, Laravel), use different agent collections.**

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# iOS Agent System - SwiftUI Development & Architecture
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## iOS Agent Overview

BananaUniverse now has **5 specialized iOS agents** for SwiftUI development:

1. **ios-tech-lead-orchestrator** - Routes iOS tasks to specialists
2. **swiftui-developer** - SwiftUI views, components, UI
3. **ios-architect** - MVVM architecture, refactoring
4. **storekit-specialist** - StoreKit 2, IAP implementation
5. **ios-testing-specialist** - XCTest, mocking, coverage

## When to Use iOS Agents

### Use @ios-tech-lead-orchestrator for:
- New SwiftUI features
- Refactoring ViewModels
- Adding IAP products
- Architecture decisions
- Multi-step iOS tasks

### Example Usage:
```
User: "Add a new onboarding screen with 3 steps"
Assistant: I'll use @ios-tech-lead-orchestrator to coordinate this task
```

## iOS Development Rules (CRITICAL)

### ✅ ALWAYS DO THIS

1. **Use DesignTokens.swift** - NEVER hardcode colors/spacing
   ```swift
   // ✅ Correct
   .background(DesignTokens.Background.primary(colorScheme))
   .padding(DesignTokens.Spacing.md)
   
   // ❌ Wrong
   .background(Color.black)
   .padding(16)
   ```

2. **Follow MVVM Pattern** - View/ViewModel separation
   ```swift
   // ✅ Correct
   struct MyView: View {
       @StateObject private var viewModel = MyViewModel()
   }
   
   @MainActor
   class MyViewModel: ObservableObject {
       @Published var state: String
   }
   ```

3. **Keep Files Small**
   - ViewModel: Max 200 lines
   - Service: Max 300 lines
   - View: Max 200 lines
   - If larger → split into multiple files

4. **Use @MainActor** - For all ViewModels
   ```swift
   @MainActor
   class MyViewModel: ObservableObject { }
   ```

5. **Service Integration** - Use singletons correctly
   ```swift
   private let creditManager = CreditManager.shared
   private let supabaseService = SupabaseService.shared
   ```

### ❌ NEVER DO THIS

1. **Hardcode values** - Use DesignTokens!
2. **Put logic in Views** - Use ViewModels!
3. **Skip @MainActor** - Causes thread crashes!
4. **Create files > 300 lines** - Refactor!
5. **Empty catch blocks** - Always log errors!
6. **Magic numbers** - Use constants!

## Reference Code (Good Patterns)

### Excellent Examples to Follow:
- `CreditManager.swift` - Service orchestration, @MainActor usage
- `DesignTokens.swift` - Design system organization
- `Config.swift` - Centralized configuration

### Anti-Patterns to Avoid:
- `ChatViewModel.swift` - Too large (549 lines → should be 3 ViewModels)
- `SupabaseService.swift` - Too many responsibilities (should be 3 services)

## iOS Agent Orchestration

### Pattern: Use Orchestrator First
```
1. User requests iOS feature
2. Main agent calls @ios-tech-lead-orchestrator
3. Orchestrator analyzes task
4. Orchestrator routes to specialists:
   - @swiftui-developer for UI
   - @ios-architect for architecture
   - @storekit-specialist for IAP
   - @ios-testing-specialist for tests
5. Main agent coordinates execution
```

### Maximum 2 Agents in Parallel
```
✅ Correct: Run swiftui-developer + ios-testing-specialist in parallel
❌ Wrong: Run 3+ agents simultaneously (context overflow)
```

## Code Quality Checklist

Before completing any iOS task, verify:

- [ ] DesignTokens used (no hardcoded values)
- [ ] MVVM pattern followed
- [ ] @MainActor on ViewModel
- [ ] File size < 300 lines
- [ ] No magic numbers
- [ ] Error handling present
- [ ] DEBUG logging added
- [ ] Dark/light mode supported
- [ ] Accessibility labels added
- [ ] No empty catch blocks

## Common iOS Tasks

### Task 1: New SwiftUI View
```
Agent: @swiftui-developer
Steps:
1. Read similar views for pattern
2. Create View + ViewModel
3. Use DesignTokens for styling
4. Add accessibility
5. Add preview
```

### Task 2: Refactor Large ViewModel
```
Agent: @ios-architect
Steps:
1. Analyze responsibilities
2. Split into smaller ViewModels
3. Update View bindings
4. Ensure state syncs
```

### Task 3: Add IAP Product
```
Agent: @storekit-specialist
Steps:
1. Add to App Store Connect
2. Update StoreKitService
3. Add to paywall UI
4. Test in sandbox
```

### Task 4: Add Unit Tests
```
Agent: @ios-testing-specialist
Steps:
1. Create mock services
2. Write test cases
3. Verify coverage > 80%
4. Ensure tests pass
```

## Integration with Backend Agents

### iOS + Backend Workflow
```
iOS agents handle:
- SwiftUI views
- ViewModels
- IAP client code
- Testing

Backend agents handle:
- Edge Functions
- Database schemas
- API endpoints
- Server-side verification
```

### Example: Add New Feature
```
1. @ios-tech-lead-orchestrator analyzes requirement
2. @backend-tech-lead-orchestrator analyzes backend needs
3. Parallel execution:
   - iOS agents build UI + ViewModel
   - Backend agents build API + database
4. Integration testing
5. Deploy
```

## iOS Agent Priorities

### High Priority (Use Agent)
- New features (> 100 lines)
- Refactoring large files
- IAP implementation
- Architecture decisions

### Low Priority (Direct Implementation)
- Small bug fixes (< 20 lines)
- Simple UI tweaks
- Single-line changes

## Quality Metrics

Track these for iOS development:

| Metric | Target | Tool |
|--------|--------|------|
| Test Coverage | > 80% | XCTest |
| File Size | < 300 lines | Manual |
| Build Time | < 30s | Xcode |
| Warnings | 0 | Xcode |
| SwiftLint Issues | 0 | SwiftLint |

---

**Last Updated:** November 15, 2025
**iOS Agents:** 5 (1 orchestrator + 4 specialists)
**Backend Agents:** 8 (1 orchestrator + 7 specialists)
**Total Agents:** 13

