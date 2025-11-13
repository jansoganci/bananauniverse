# BananaUniverse - ChatGPT Project Instructions

## 📋 Project Overview

**BananaUniverse** is a professional AI image processing iOS app that transforms photos using 27+ AI models. Built with SwiftUI and Supabase, it follows the "Steve Jobs philosophy" of simplicity and elegance.

### Key Characteristics
- **Platform**: iOS 15.0+ (SwiftUI + Swift 5.9+)
- **Backend**: Supabase (PostgreSQL + Edge Functions)
- **AI Provider**: fal.ai (27+ production models)
- **Architecture**: Feature-based MVVM with Combine
- **Payment**: StoreKit 2 (native Apple subscriptions)
- **Current Version**: 1.1.0

### Core Philosophy
> "Simplicity is the ultimate sophistication" - Steve Jobs
- Single edge function for all AI processing
- Direct processing (no polling)
- WhatsApp-style chat interface
- Clean separation: iOS handles UI, Edge Function handles AI

---

## 🏗️ Architecture Overview

### Frontend (iOS)
```
BananaUniverse/
├── App/                    # Entry point
│   ├── BananaUniverseApp.swift
│   ├── AppDelegate.swift
│   └── ContentView.swift   # Tab navigation
├── Core/                   # Shared components
│   ├── Components/         # Reusable UI components
│   ├── Config/            # App configuration
│   ├── Design/            # Design system & tokens
│   ├── Models/            # Data models
│   ├── Services/          # Business logic services
│   └── Utils/             # Utility functions
└── Features/              # Feature modules
    ├── Authentication/    # User auth flows
    ├── Chat/              # WhatsApp-style AI processing
    ├── Home/              # Dashboard with search & categories
    ├── Library/           # Image history
    ├── Profile/           # Settings & subscription
    └── Paywall/           # Premium subscription UI
```

### Backend (Supabase)
```
supabase/
├── functions/
│   └── process-image/     # Single edge function (Steve Jobs style)
└── migrations/            # Database migrations (51 files)
```

### Key Services (Singleton Pattern)
- `HybridAuthService.shared` - Authentication (anonymous + authenticated)
- `HybridCreditManager.shared` - Quota management
- `StoreKitService.shared` - Subscription management
- `SupabaseService.shared` - Database & storage
- `ThemeManager` - Theme system (Light/Dark/Auto)
- `AppState` - Global app state

---

## 🎯 Core Features

### 1. **27 AI Tools Across 4 Categories**

**Photo Editor (7 tools):**
- Remove Object, Remove Background, Put Items on Models
- Add Objects, Change Perspectives, Generate Series, Style Transfers

**Pro Photos (10 tools):**
- LinkedIn Headshot, Passport Photo, Twitter Avatar
- Gradient Headshot, Resume Photo, Slide Background
- Thumbnail Generator, CV Portrait, Profile Banner, Designer ID Photo

**Enhancer (2 tools):**
- Image Upscaler (2x-4x), Historical Photo Restore

**Seasonal (8 tools):**
- Thanksgiving (3), Christmas (4), New Year (2)

### 2. **Quota System**
- **Free Users**: 3 requests/day (resets at midnight UTC)
- **Premium Users**: Unlimited requests
- **Tracking**: `daily_quotas` table with idempotency protection
- **Cache**: Local cache for instant UI updates

### 3. **Subscription System**
- **Weekly Pro**: $4.99/week (3-day free trial)
- **Yearly Pro**: $79.99/year (3-day free trial, save 70%)
- **Integration**: StoreKit 2 + Supabase sync
- **Benefits**: Unlimited quota, all tools unlocked

### 4. **Authentication**
- **Anonymous**: Device-based (UUID stored in UserDefaults)
- **Authenticated**: Email/Password + Apple Sign-In
- **Hybrid**: Seamless transition between anonymous ↔ authenticated

---

## 📁 Code Structure Deep Dive

### Models (`Core/Models/`)

**Tool.swift** - AI tool definitions
```swift
struct Tool: Identifiable {
    let id: String
    let title: LocalizedStringKey
    let category: String
    let modelName: String
    let prompt: String
    // ...
}
```

**UserState.swift** - User authentication state
```swift
enum UserState {
    case anonymous(deviceId: String)
    case authenticated(user: User)
}
```

**QuotaInfo.swift** - Quota state
```swift
struct QuotaInfo {
    let quotaUsed: Int
    let quotaLimit: Int
    let quotaRemaining: Int
    let isPremium: Bool
}
```

### Services (`Core/Services/`)

**HybridCreditManager** - Quota orchestration
- Responsibilities: UI state management, orchestrates QuotaService + QuotaCache
- **DO NOT**: Make network calls directly (use QuotaService)
- **DO NOT**: Manage cache directly (use QuotaCache)

**HybridAuthService** - Authentication
- Handles anonymous + authenticated users
- Manages auth state transitions
- Updates HybridCreditManager on state changes

**StoreKitService** - Subscriptions
- Loads products from App Store
- Handles purchases & restorations
- Syncs to Supabase `subscriptions` table
- Updates premium status in HybridCreditManager

**SupabaseService** - Backend communication
- Database queries (RLS-protected)
- Storage uploads/downloads
- Edge function calls
- Quota consumption

**QuotaService** - Network layer for quota
- `getQuota()` - Fetches current quota
- `consumeQuota()` - Consumes one quota unit
- Returns `QuotaInfo` or throws `QuotaError`

**QuotaCache** - Local quota storage
- Persists quota to UserDefaults
- Provides instant UI updates
- Migrates from old cache versions

### ViewModels (`Features/*/ViewModels/`)

**ChatViewModel** - Image processing flow
- Manages chat messages (user/assistant/error)
- Handles image selection & processing
- Integrates with HybridCreditManager for quota
- Calls SupabaseService for AI processing

**LibraryViewModel** - Image history
- Fetches jobs from `jobs` table
- Groups by date
- Handles save/share actions

### Views (`Features/*/Views/`)

**ChatView** - WhatsApp-style interface
- Message bubbles with images
- Image picker integration
- Processing status indicators
- Full-screen image viewer

**HomeView** - Dashboard
- Featured carousel
- Category-based horizontal rows
- Real-time search (debounced)
- Quota warning banner

**LibraryView** - Image history
- Recent activity section
- Grouped by date
- Pull-to-refresh
- Save/share functionality

**ProfileView** - User settings
- Premium status display
- Theme selector
- Account management
- Support links

**PaywallView** - Subscription UI
- Product cards with pricing
- Trial badges
- Purchase flow
- Restore purchases

---

## 🗄️ Database Schema

### Core Tables

**`daily_quotas`** - Daily quota tracking
```sql
- id (UUID)
- user_id (UUID, nullable) - For authenticated users
- device_id (TEXT, nullable) - For anonymous users
- date (DATE) - Quota date
- used (INTEGER) - Quota used today
- limit_value (INTEGER) - Daily limit (default: 3)
- UNIQUE(user_id, device_id, date)
```

**`subscriptions`** - Premium subscriptions
```sql
- id (UUID)
- user_id (UUID, nullable)
- device_id (TEXT, nullable)
- status (TEXT) - 'active', 'expired', 'cancelled'
- product_id (TEXT) - 'banana_weekly' or 'banana_yearly'
- expires_at (TIMESTAMPTZ)
- original_transaction_id (TEXT, UNIQUE) - StoreKit ID
```

**`jobs`** - Processing history
```sql
- id (UUID)
- user_id (UUID, nullable)
- device_id (TEXT, nullable)
- model (TEXT) - AI model used
- status (TEXT) - 'pending', 'processing', 'completed', 'failed'
- input_url (TEXT) - Original image URL
- output_url (TEXT) - Processed image path
- options (JSONB) - Processing options
- created_at, completed_at, updated_at
```

**`quota_consumption_log`** - Audit log
```sql
- id (UUID)
- request_id (UUID, UNIQUE) - For idempotency
- user_id (UUID, nullable)
- device_id (TEXT, nullable)
- consumed_at (TIMESTAMPTZ)
- quota_used, quota_limit (INTEGER)
- success (BOOLEAN)
- error_message (TEXT)
```

### Key Functions (RPC)

**`get_quota(p_user_id, p_device_id)`**
- Returns current quota state
- Creates quota record if doesn't exist
- Checks premium status from `subscriptions` table

**`consume_quota(p_user_id, p_device_id, p_client_request_id)`**
- Consumes one quota unit
- Idempotent (uses `p_client_request_id`)
- Returns early if duplicate request
- Checks premium status (premium users bypass quota)

**`refund_quota(p_user_id, p_device_id, p_client_request_id)`**
- Refunds quota if AI processing fails
- Idempotent (uses same `p_client_request_id`)

**`sync_subscription(...)`**
- Syncs StoreKit subscription to database
- Called after successful purchase

### Row Level Security (RLS)
- All tables have RLS enabled
- Users can only access their own data
- Anonymous users use `device_id` session variable
- Service role has full access (for edge functions)

---

## 🔧 Development Guidelines

### 1. **Code Style**
- Follow existing SwiftUI patterns
- Use `@MainActor` for UI-related classes
- Use `actor` for thread-safe services
- Prefer `async/await` over callbacks
- Use `ObservableObject` for view models

### 2. **Error Handling**
- Use typed errors (`QuotaError`, `AppError`, etc.)
- Provide user-friendly error messages
- Log errors with context (#if DEBUG)
- Don't crash on recoverable errors

### 3. **State Management**
- Use `@Published` for UI state
- Use `@StateObject` for view models
- Use `@EnvironmentObject` for shared services
- Keep state minimal and focused

### 4. **Network Calls**
- Always check network connectivity first
- Show loading states during async operations
- Handle offline scenarios gracefully
- Cache responses when appropriate

### 5. **Quota Management**
- **NEVER** modify quota directly in UI
- Always use `HybridCreditManager.shared`
- Check quota before processing: `canProcessImage()`
- Consume quota during processing: `consumeQuota()`
- Handle quota errors gracefully (show paywall)

### 6. **Subscription Management**
- Use `StoreKitService.shared` for all subscription operations
- Sync to Supabase after purchase
- Update premium status in `HybridCreditManager`
- Handle purchase errors gracefully

### 7. **Image Processing Flow**
```
1. User selects image → ChatViewModel
2. Check quota → HybridCreditManager.canProcessImage()
3. Upload image → SupabaseService.uploadImageToStorage()
4. Process image → SupabaseService.processImageSteveJobsStyle()
5. Consume quota → HybridCreditManager.consumeQuota()
6. Download result → Display in chat
7. Save to library → Jobs table
```

### 8. **Design System**
- Use `DesignTokens` for all colors, spacing, typography
- Support Light/Dark themes
- Use semantic colors (success, error, warning)
- Follow 8pt grid system

---

## 🚀 Common Tasks & Patterns

### Adding a New AI Tool

1. **Add tool definition** (`Core/Models/Tool.swift`):
```swift
Tool(
    id: "new_tool_id",
    title: "New Tool Name",
    category: "main_tools", // or "pro_looks", "seasonal", "restoration"
    modelName: "fal-ai-model-name",
    prompt: "Tool-specific prompt",
    // ...
)
```

2. **Add to appropriate category array**:
```swift
static let mainTools: [Tool] = [
    // ... existing tools
    Tool(id: "new_tool_id", ...)
]
```

3. **Update featured mapping** (`Core/Utils/CategoryFeaturedMapping.swift`) if needed

### Modifying Quota System

1. **Backend changes** (migrations):
   - Modify `daily_quotas` table structure
   - Update `get_quota()` or `consume_quota()` functions
   - Test idempotency protection

2. **Frontend changes**:
   - Update `QuotaService` if RPC signature changes
   - Update `QuotaInfo` model if response structure changes
   - Update `HybridCreditManager` if business logic changes

### Adding a New Subscription Product

1. **App Store Connect**:
   - Create new product (weekly/yearly)
   - Configure pricing & trial period

2. **iOS Code** (`StoreKitService.swift`):
```swift
private let productIds = [
    "banana_weekly",
    "banana_yearly",
    "new_product_id" // Add here
]
```

3. **Backend** (if needed):
   - Update `subscriptions` table policies
   - Update premium check logic in `consume_quota()`

### Debugging Quota Issues

1. **Check cache**:
   - `QuotaCache.shared.load()` - Local cached values
   - Clear cache: Delete UserDefaults key

2. **Check backend**:
   - Query `daily_quotas` table directly
   - Check `quota_consumption_log` for audit trail
   - Verify RLS policies allow access

3. **Check premium status**:
   - `StoreKitService.shared.isPremiumUser`
   - Query `subscriptions` table
   - Verify subscription sync

### Testing Image Processing

1. **Local testing**:
   - Use debug builds
   - Check network connectivity
   - Verify Supabase credentials in `Config.swift`

2. **Edge function testing**:
   - Check edge function logs in Supabase dashboard
   - Verify `FAL_AI_API_KEY` is set
   - Test with different image sizes

3. **Quota testing**:
   - Test free user limit (3/day)
   - Test premium user (unlimited)
   - Test quota reset (midnight UTC)

---

## ⚠️ Important Notes

### Critical Rules

1. **NEVER modify quota directly**
   - Always use `HybridCreditManager.shared`
   - Don't bypass quota checks

2. **NEVER make network calls in ViewModels**
   - Use services (QuotaService, SupabaseService)
   - Keep ViewModels focused on UI state

3. **ALWAYS check premium status from StoreKit**
   - Don't trust client-provided premium status
   - Server validates premium in `consume_quota()`

4. **ALWAYS handle idempotency**
   - Use `p_client_request_id` for quota operations
   - Prevent duplicate quota consumption

5. **ALWAYS use RLS policies**
   - Don't bypass RLS with service role in frontend
   - Use proper user/device identification

### Configuration

**iOS App** (`Core/Config/Config.swift`):
- `SUPABASE_URL` - From Info.plist
- `SUPABASE_ANON_KEY` - From Info.plist
- `supabaseBucket` - "noname-banana-images-prod"

**Edge Function** (Environment Variables):
- `FAL_AI_API_KEY` - fal.ai API key
- `SUPABASE_URL` - Supabase project URL
- `SUPABASE_SERVICE_ROLE_KEY` - Service role key

### Migration Notes

- **Migration 050**: Robust quota system (latest)
- **Migration 051**: Rollback (if needed)
- Always test migrations in development first
- Check for breaking changes in RPC functions

### Performance Considerations

- **Image compression**: Max 1024px dimension, 0.8 quality
- **Image size limit**: 10MB
- **Processing time**: < 35 seconds target
- **Quota cache**: Instant UI updates, syncs in background

### Security Considerations

- **RLS policies**: All tables protected
- **JWT validation**: Edge function validates tokens
- **Device ID**: Stored securely in UserDefaults
- **Subscription sync**: Server-side validation only

---

## 📚 Key Files Reference

### Frontend
- `BananaUniverseApp.swift` - App entry point
- `ContentView.swift` - Tab navigation
- `HybridCreditManager.swift` - Quota orchestration
- `HybridAuthService.swift` - Authentication
- `StoreKitService.swift` - Subscriptions
- `ChatViewModel.swift` - Image processing
- `Config.swift` - Configuration

### Backend
- `supabase/functions/process-image/index.ts` - Edge function
- `supabase/migrations/050_robust_quota_system.sql` - Latest quota system
- `supabase/migrations/034_create_subscriptions.sql` - Subscription table

### Models
- `Tool.swift` - AI tool definitions
- `UserState.swift` - Auth state
- `QuotaInfo.swift` - Quota state
- `QuotaError.swift` - Quota errors

---

## 🎯 Quick Reference

### Check Quota
```swift
let creditManager = HybridCreditManager.shared
let canProcess = creditManager.canProcessImage()
let remaining = creditManager.remainingQuota
```

### Process Image
```swift
let viewModel = ChatViewModel()
await viewModel.processSelectedImage()
```

### Check Premium
```swift
let storeKit = StoreKitService.shared
let isPremium = storeKit.isPremiumUser
```

### Load Quota
```swift
await HybridCreditManager.shared.loadQuota()
```

### Purchase Subscription
```swift
let product = StoreKitService.shared.weeklyProduct
try await StoreKitService.shared.purchase(product)
```

---

## 🔍 Troubleshooting

### Quota Not Updating
1. Check `QuotaCache` - may be stale
2. Call `HybridCreditManager.shared.loadQuota()`
3. Check backend `daily_quotas` table
4. Verify RLS policies

### Subscription Not Working
1. Check `StoreKitService.shared.isPremiumUser`
2. Verify subscription in App Store Connect
3. Check `subscriptions` table in Supabase
4. Call `StoreKitService.shared.restorePurchases()`

### Image Processing Fails
1. Check network connectivity
2. Verify `FAL_AI_API_KEY` in edge function
3. Check image size (< 10MB)
4. Review edge function logs

### Authentication Issues
1. Check `HybridAuthService.shared.userState`
2. Verify Supabase credentials
3. Check RLS policies for anonymous users
4. Verify device ID is set

---

## 📝 Additional Resources

- **README.md** - Project overview & setup
- **CHANGELOG.md** - Version history
- **Design System** - `Core/Design/DesignTokens.swift`
- **Supabase Docs** - https://supabase.com/docs
- **StoreKit 2 Docs** - https://developer.apple.com/documentation/storekit

---

**Last Updated**: November 2025
**Version**: 1.1.0

