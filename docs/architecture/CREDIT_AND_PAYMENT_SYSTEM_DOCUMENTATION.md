# Credit & Payment System - Complete Documentation

This document provides a comprehensive guide to the credit and in-app purchase (IAP) system implemented in BananaUniverse. It covers both iOS (Swift/SwiftUI) and backend (Supabase Edge Functions) components, their interactions, and the complete data flow.

---

## Table of Contents

1. [System Architecture Overview](#system-architecture-overview)
2. [iOS Components (Frontend)](#ios-components-frontend)
3. [Backend Components](#backend-components)
4. [Data Flow Diagrams](#data-flow-diagrams)
5. [Payment Flow](#payment-flow)
6. [Credit Management Flow](#credit-management-flow)
7. [Test Mode](#test-mode)
8. [File Reference](#file-reference)
9. [Integration Guide](#integration-guide)

---

## System Architecture Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    iOS Application (SwiftUI)                  │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ StoreKit     │  │ Credit       │  │ Supabase     │      │
│  │ Service      │  │ Manager      │  │ Service      │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                  │                  │              │
│         └──────────────────┴──────────────────┘              │
│                            │                                  │
└────────────────────────────┼──────────────────────────────────┘
                             │
                             │ HTTPS/REST API
                             │
┌────────────────────────────┼──────────────────────────────────┐
│                    Supabase Backend                            │
├────────────────────────────┼──────────────────────────────────┤
│  ┌──────────────────────────┴──────────────────────────┐     │
│  │         verify-iap-purchase Edge Function            │     │
│  │  (TypeScript/Deno - Apple IAP Verification)         │     │
│  └──────────────────────────┬──────────────────────────┘     │
│                             │                                  │
│  ┌──────────────────────────┴──────────────────────────┐     │
│  │              PostgreSQL Database                     │     │
│  │  - credits table (user balances)                    │     │
│  │  - products table (IAP product definitions)         │     │
│  │  - iap_transactions table (purchase history)         │     │
│  │  - idempotency_keys table (duplicate prevention)    │     │
│  └──────────────────────────────────────────────────────┘     │
└────────────────────────────────────────────────────────────────┘
                             │
                             │ Apple StoreKit API
                             │
┌────────────────────────────┼──────────────────────────────────┐
│                    Apple Servers                               │
│  - App Store Connect API                                      │
│  - Transaction Verification                                    │
└────────────────────────────────────────────────────────────────┘
```

### Key Design Principles

1. **Separation of Concerns**: Each component has a single responsibility
2. **Hybrid Authentication**: Supports both authenticated users and anonymous (device-based) users
3. **Idempotency**: All operations are idempotent to prevent duplicate credit grants
4. **Offline Support**: Cached credit balances for offline usage
5. **StoreKit 2 Compatibility**: Uses modern StoreKit 2 API with transaction ID-based verification

---

## iOS Components (Frontend)

### 1. CreditManager.swift
**Location:** `BananaUniverse/Core/Services/CreditManager.swift`

**Purpose:** Central orchestrator for credit state management. Coordinates between network layer (QuotaService), cache layer (QuotaCache), and UI layer.

**Key Responsibilities:**
- Manages `@Published` state for SwiftUI reactive updates
- Orchestrates credit loading from backend
- Handles offline/online state transitions
- Provides computed properties for UI consumption
- Debounces rapid successive load requests (2-second minimum interval)

**Key Properties:**
```swift
@Published private(set) var creditsRemaining: Int = 10  // Default: 10 credits
@Published private(set) var creditsTotal: Int = 10
@Published private(set) var isLoading = true
@Published private(set) var isOffline = false
```

**Key Methods:**
- `loadQuota()` - Fetches credit balance from backend (idempotent, single-flight)
- `initializeNewUser()` - Initializes credits for new users
- `updateFromBackendResponse(creditsRemaining:)` - Updates credits from backend response
- `updateFromRecovery(credits:)` - Updates from StableID recovery
- `canProcessImage()` - Checks if user has credits available

**Dependencies:**
- `QuotaService.shared` - Network layer
- `QuotaCache.shared` - Cache layer
- `HybridAuthService.shared` - User authentication state
- `NetworkMonitor.shared` - Network connectivity

---

### 2. QuotaService.swift
**Location:** `BananaUniverse/Core/Services/QuotaService.swift`

**Purpose:** Network layer for credit operations. Handles all RPC calls to Supabase backend.

**Key Responsibilities:**
- Makes RPC calls to `get_credits` function
- Handles network errors and decoding
- Supports both authenticated and anonymous users

**Key Methods:**
```swift
func getQuota(userId: String?, deviceId: String?) async throws -> CreditInfo
```

**RPC Call:**
- Function: `get_credits`
- Parameters:
  - `p_user_id` (String?): Authenticated user ID (null for anonymous)
  - `p_device_id` (String?): Device ID (null for authenticated users)
- Returns: `CreditInfo` with `credits_remaining`, `credits_total`, `initial_grant_claimed`

**Error Handling:**
- Throws `QuotaError.network(error)` on network failures
- Throws `QuotaError` for backend errors

---

### 3. QuotaCache.swift
**Location:** `BananaUniverse/Core/Services/QuotaCache.swift`

**Purpose:** Persistence layer for credit data. Stores credit balance in UserDefaults for offline access.

**Key Responsibilities:**
- Saves credit balance to UserDefaults
- Loads cached credit balance
- Migrates from old cache versions (v1, v2 → v3)
- Marks cache as stale after 5 minutes

**Storage Keys:**
- `credits_remaining_v3` - Current credit balance
- `credits_last_update_v3` - Last update timestamp

**Key Methods:**
- `save(creditsRemaining:)` - Saves credit balance
- `load()` - Loads cached balance (returns `CachedQuota?`)
- `clear()` - Clears all cached data
- `migrateFromV1IfNeeded()` - Migrates from old cache versions

---

### 4. StoreKitService.swift
**Location:** `BananaUniverse/Core/Services/StoreKitService.swift`

**Purpose:** Handles all StoreKit 2 integration for in-app purchases.

**Key Responsibilities:**
- Loads products from App Store Connect
- Processes purchase transactions
- Verifies purchases with backend
- Handles test mode (bypasses StoreKit for testing)
- Manages transaction listener for StoreKit 2 compliance

**Key Properties:**
```swift
@Published var creditProducts: [Product] = []
@Published var isLoading = false
@Published var errorMessage: String?
@Published var shouldShowSuccessAlert = false
```

**Product IDs:**
- `credits_10` - 10 credits pack
- `credits_25` - 25 credits pack
- `credits_50` - 50 credits pack
- `credits_100` - 100 credits pack

**Key Methods:**
- `loadProducts()` - Loads products from App Store
- `purchase(_ product:)` - Initiates purchase flow
- `verifyPurchaseWithBackend(transaction:productId:)` - Verifies purchase with backend
- `restorePurchases()` - Restores previous purchases
- `simulateTestPurchase(product:)` - Simulates purchase in test mode

**Purchase Flow:**
1. User initiates purchase → `product.purchase()`
2. Apple processes payment → Returns `Transaction`
3. Extract `transaction.id` (String)
4. Call `SupabaseService.verifyIAPPurchase(transactionId:productId:)`
5. Backend verifies with Apple and grants credits
6. Update `CreditManager` with new balance
7. Finish transaction → `transaction.finish()`

**Test Mode:**
- Controlled by `Config.enablePaymentTestMode`
- When enabled: Bypasses StoreKit, directly grants credits
- When disabled: Uses real StoreKit transactions

---

### 5. SupabaseService.swift
**Location:** `BananaUniverse/Core/Services/SupabaseService.swift`

**Purpose:** Main service for Supabase client operations. Handles authentication, storage, and Edge Function calls.

**Key Method for IAP:**
```swift
func verifyIAPPurchase(transactionId: String, productId: String) async throws -> IAPVerificationResponse
```

**Request Details:**
- **Endpoint:** `{supabaseURL}/functions/v1/verify-iap-purchase`
- **Method:** POST
- **Headers:**
  - `Authorization: Bearer {session.accessToken}` (authenticated) or `Bearer {anonKey}` (anonymous)
  - `Content-Type: application/json`
  - `device-id: {deviceId}` (for anonymous users)
- **Body:**
  ```json
  {
    "transaction_id": "1234567890",
    "product_id": "credits_10",
    "device_id": "device-uuid" // Only for anonymous users
  }
  ```

**Response Model:**
```swift
struct IAPVerificationResponse: Codable {
    let success: Bool
    let credits_granted: Int
    let balance_after: Int
    let transaction_id: String
    let original_transaction_id: String
}
```

---

### 6. Config.swift
**Location:** `BananaUniverse/Core/Config/Config.swift`

**Purpose:** Central configuration file for app settings.

**Key Payment Configuration:**
```swift
static let enablePaymentTestMode: Bool = {
    #if DEBUG
    return false  // Set to true for test mode
    #else
    return false  // Always false in production
    #endif
}()
```

**Supabase Configuration:**
- `supabaseURL` - Supabase project URL
- `supabaseAnonKey` - Supabase anonymous key
- `edgeFunctionURL` - Base URL for Edge Functions

---

### 7. QuotaDisplayView.swift
**Location:** `BananaUniverse/Core/Components/QuotaDisplayView.swift`

**Purpose:** Reusable SwiftUI component for displaying credit balance in UI.

**Usage:**
```swift
QuotaDisplayView(
    creditManager: CreditManager.shared,
    style: .compact,  // or .detailed, .badge
    action: { /* Optional tap action */ }
)
```

**Features:**
- Shows loading state while syncing
- Displays credit balance
- Shows warning when credits are low (≤1)
- Multiple display styles (compact, detailed, badge)

**Observable Pattern:**
- Uses `@ObservedObject` or `@EnvironmentObject` to observe `CreditManager`
- Automatically updates when `creditsRemaining` changes

---

### 8. BananaUniverseApp.swift
**Location:** `BananaUniverse/App/BananaUniverseApp.swift`

**Purpose:** Main app entry point. Initializes credit system on app launch.

**Key Initialization:**
```swift
.task {
    await CreditManager.shared.initializeNewUser()
}
```

**Background Refresh:**
```swift
.onChange(of: scenePhase) { newPhase in
    if newPhase == .active && hasInitialized {
        await CreditManager.shared.loadQuota()
    }
}
```

---

## Backend Components

### verify-iap-purchase Edge Function
**Location:** `supabase/functions/verify-iap-purchase/index.ts`

**Purpose:** Verifies in-app purchases with Apple and grants credits to users.

**Architecture:**
- Written in TypeScript/Deno
- Uses Supabase Edge Functions runtime
- Integrates with Apple App Store Server API
- Supports both StoreKit 1 (JWT) and StoreKit 2 (Transaction ID)

**Request Flow:**

1. **Authentication** (Lines 24-71)
   - Validates `Authorization` header
   - Extracts user ID (if authenticated) or device ID (if anonymous)
   - Sets device ID session for RLS (Row Level Security)

2. **Request Parsing** (Lines 73-97)
   - Parses request body (handles double-parsing bug fix)
   - Extracts `transaction_id` or `transaction_jwt`
   - Extracts `product_id`

3. **Apple Verification** (Lines 99-150)
   - If `transaction_jwt` provided → Uses `verifyAppleTransaction()`
   - If `transaction_id` provided → Uses `verifyAppleTransactionById()`
   - Validates product ID matches
   - Ensures `original_transaction_id` exists

4. **Idempotency Check** (Lines 152-189)
   - Creates idempotency key: `purchase-{original_transaction_id}`
   - Checks if purchase already processed
   - Returns cached result if duplicate

5. **Product Lookup** (Lines 191-223)
   - Queries `products` table for product details
   - Calculates total credits (base + bonus)
   - Validates product is active

6. **Credit Granting** (Lines 225-254)
   - Calls `add_credits` RPC function
   - Grants credits atomically
   - Returns new balance

7. **Transaction Logging** (Lines 256-280)
   - Inserts record into `iap_transactions` table
   - Handles null values safely (user_id/device_id)
   - Stores truncated JWT (if available)

8. **Telegram Notification** (Lines 282-307)
   - Sends purchase notification to Telegram (if configured)
   - Includes user info, product details, credits granted

9. **Success Response** (Lines 309-331)
   - Returns success response with credits granted and new balance

**Helper Functions:**

- `verifyAppleTransactionById(transactionId)` - Verifies using StoreKit 2 transaction ID
- `verifyAppleTransaction(transactionJWT)` - Verifies using StoreKit 1 JWT
- `sendTelegramPurchaseNotification(data)` - Sends Telegram notification

**Critical Fixes Applied:**
1. ✅ **Double Body Parsing Fix** - Stores body in variable to avoid reading twice
2. ✅ **Undefined JWT Fix** - Checks if `transaction_jwt` exists before using
3. ✅ **Missing Null Checks** - Validates `original_transaction_id` and `product_id` exist
4. ✅ **Database Null Safety** - Uses `|| null` for user_id/device_id

**Environment Variables Required:**
- `SUPABASE_URL` - Supabase project URL
- `SUPABASE_SERVICE_ROLE_KEY` - Service role key for admin operations
- `APPLE_PRIVATE_KEY` - Apple private key for API authentication
- `APPLE_KEY_ID` - Apple key ID
- `APPLE_ISSUER_ID` - Apple issuer ID
- `APPLE_BUNDLE_ID` - App bundle identifier
- `TELEGRAM_BOT_TOKEN` - (Optional) Telegram bot token
- `TELEGRAM_CHAT_ID` - (Optional) Telegram chat ID

---

## Data Flow Diagrams

### Credit Loading Flow

```
App Launch
    │
    ├─> BananaUniverseApp.task
    │       │
    │       └─> CreditManager.initializeNewUser()
    │               │
    │               └─> CreditManager.loadQuota()
    │                       │
    │                       ├─> Check Network (NetworkMonitor)
    │                       │       │
    │                       │       ├─> Offline → Use Cache (QuotaCache)
    │                       │       │
    │                       │       └─> Online → Continue
    │                       │
    │                       ├─> Debounce Check (2-second minimum)
    │                       │
    │                       └─> QuotaService.getQuota()
    │                               │
    │                               └─> Supabase RPC: get_credits
    │                                       │
    │                                       └─> Database Query
    │                                               │
    │                                               └─> Returns CreditInfo
    │                                                       │
    │                                                       └─> CreditManager.updateCredits()
    │                                                               │
    │                                                               ├─> QuotaCache.save()
    │                                                               │
    │                                                               └─> @Published creditsRemaining
    │                                                                       │
    │                                                                       └─> UI Updates (QuotaDisplayView)
```

### Payment Flow

```
User Taps "Buy Credits"
    │
    ├─> StoreKitService.purchase(product)
    │       │
    │       ├─> Test Mode?
    │       │       │
    │       │       ├─> YES → simulateTestPurchase()
    │       │       │       │
    │       │       │       └─> CreditManager.updateFromBackendResponse()
    │       │       │
    │       │       └─> NO → Continue
    │       │
    │       ├─> product.purchase() (Apple StoreKit)
    │       │       │
    │       │       └─> Apple Payment Dialog
    │       │               │
    │       │               └─> User Confirms
    │       │                       │
    │       │                       └─> Returns Transaction
    │       │
    │       ├─> Extract transaction.id
    │       │
    │       └─> StoreKitService.verifyPurchaseWithBackend()
    │               │
    │               └─> SupabaseService.verifyIAPPurchase()
    │                       │
    │                       └─> POST /functions/v1/verify-iap-purchase
    │                               │
    │                               └─> Backend (verify-iap-purchase/index.ts)
    │                                       │
    │                                       ├─> Authenticate Request
    │                                       ├─> Parse Body
    │                                       ├─> Verify with Apple API
    │                                       ├─> Check Idempotency
    │                                       ├─> Lookup Product
    │                                       ├─> Grant Credits (add_credits RPC)
    │                                       ├─> Log Transaction
    │                                       ├─> Send Telegram (optional)
    │                                       └─> Return Success Response
    │                                               │
    │                                               └─> SupabaseService receives response
    │                                                       │
    │                                                       └─> CreditManager.updateFromBackendResponse()
    │                                                               │
    │                                                               └─> UI Updates
    │
    └─> transaction.finish() (Complete Apple transaction)
```

---

## Payment Flow

### Complete Payment Sequence

1. **User Initiates Purchase**
   - User taps "Buy Credits" button
   - `StoreKitService.purchase(product)` is called

2. **Apple StoreKit Processing**
   - Apple shows payment dialog
   - User authenticates (Face ID/Touch ID/Password)
   - Apple processes payment
   - Returns `Transaction` object with `id`

3. **Backend Verification**
   - iOS extracts `transaction.id` (String)
   - Calls `SupabaseService.verifyIAPPurchase(transactionId:productId:)`
   - Backend receives request at `/functions/v1/verify-iap-purchase`

4. **Backend Processing**
   - Authenticates request (user_id or device_id)
   - Calls Apple App Store Server API to verify transaction
   - Checks idempotency (prevents duplicate grants)
   - Looks up product in database
   - Grants credits via `add_credits` RPC
   - Logs transaction to `iap_transactions` table
   - Sends Telegram notification (if configured)

5. **Response & Update**
   - Backend returns success with `balance_after`
   - iOS updates `CreditManager` with new balance
   - UI automatically updates (reactive SwiftUI)

6. **Transaction Completion**
   - iOS calls `transaction.finish()` to complete Apple transaction

### Error Handling

- **Network Errors**: Cached balance is used, user sees offline indicator
- **Backend Verification Fails**: Purchase is still valid, but credits may not be granted (user can restore)
- **Duplicate Purchase**: Idempotency check returns cached result (no duplicate credits)
- **Invalid Transaction**: Backend rejects, returns error, purchase is not completed

---

## Credit Management Flow

### Credit Loading

1. **App Launch**
   - `BananaUniverseApp.task` calls `CreditManager.initializeNewUser()`
   - `CreditManager.loadQuota()` is called
   - Checks network connectivity
   - If offline → Uses cached balance
   - If online → Fetches from backend

2. **Backend Query**
   - Calls `QuotaService.getQuota(userId:deviceId:)`
   - Makes RPC call to `get_credits` function
   - Database returns current balance

3. **State Update**
   - `CreditManager.updateCredits()` is called
   - Saves to cache (`QuotaCache`)
   - Updates `@Published creditsRemaining`
   - UI automatically updates

### Credit Consumption

Credits are consumed when user processes an image:
- `submit-job` Edge Function deducts credits atomically
- Frontend is notified via 402 status code if insufficient credits
- `CreditManager` is updated with actual balance from error response

### Credit Granting

Credits are granted in two scenarios:

1. **Initial Grant** (New User)
   - `get_credits` RPC automatically grants initial 10 credits
   - `initial_grant_claimed` flag prevents duplicate grants

2. **Purchase Grant** (IAP)
   - User purchases credits via StoreKit
   - Backend verifies purchase and grants credits
   - Balance is updated immediately

---

## Test Mode

### Configuration

Test mode is controlled by `Config.enablePaymentTestMode`:

```swift
static let enablePaymentTestMode: Bool = {
    #if DEBUG
    return false  // Change to true for test mode
    #else
    return false  // Always false in production
    #endif
}()
```

### Test Mode Behavior

**When Enabled (`true`):**
- Bypasses Apple StoreKit completely
- No real payment processing
- Directly grants credits to `CreditManager`
- Shows "Test Mode" in success message
- No backend verification needed

**When Disabled (`false`):**
- Uses real StoreKit transactions
- Requires Apple sandbox/testing setup
- Backend verification is required
- Real payment flow

### Testing Recommendations

1. **Development Testing**: Use test mode (`enablePaymentTestMode = true`)
2. **Sandbox Testing**: Use real StoreKit with sandbox account
3. **Production**: Always `false` in production builds

---

## File Reference

### iOS Files

| File | Location | Purpose |
|------|----------|---------|
| `CreditManager.swift` | `Core/Services/` | Central credit state orchestrator |
| `QuotaService.swift` | `Core/Services/` | Network layer for credit operations |
| `QuotaCache.swift` | `Core/Services/` | Cache layer for offline support |
| `StoreKitService.swift` | `Core/Services/` | StoreKit 2 integration |
| `SupabaseService.swift` | `Core/Services/` | Supabase client operations |
| `Config.swift` | `Core/Config/` | App configuration |
| `QuotaDisplayView.swift` | `Core/Components/` | UI component for credit display |
| `BananaUniverseApp.swift` | `App/` | App entry point, initialization |

### Backend Files

| File | Location | Purpose |
|------|----------|---------|
| `verify-iap-purchase/index.ts` | `supabase/functions/` | IAP verification Edge Function |

### Database Tables

| Table | Purpose |
|-------|---------|
| `credits` | Stores user credit balances |
| `products` | IAP product definitions |
| `iap_transactions` | Purchase history |
| `idempotency_keys` | Prevents duplicate credit grants |

### Database Functions (RPC)

| Function | Purpose |
|----------|---------|
| `get_credits` | Fetches current credit balance |
| `add_credits` | Grants credits atomically |
| `consume_credits` | Deducts credits (used by submit-job) |
| `set_device_id_session` | Sets device ID for RLS |

---

## Integration Guide

### Step 1: Backend Setup

1. **Deploy Edge Function**
   ```bash
   supabase functions deploy verify-iap-purchase
   ```

2. **Set Environment Variables**
   - `APPLE_PRIVATE_KEY` - Apple private key (PEM format)
   - `APPLE_KEY_ID` - Apple key ID
   - `APPLE_ISSUER_ID` - Apple issuer ID
   - `APPLE_BUNDLE_ID` - Your app bundle ID
   - `TELEGRAM_BOT_TOKEN` - (Optional) Telegram bot token
   - `TELEGRAM_CHAT_ID` - (Optional) Telegram chat ID

3. **Database Setup**
   - Ensure `products` table exists with product definitions
   - Ensure `credits` table exists for user balances
   - Ensure `iap_transactions` table exists for logging
   - Ensure `idempotency_keys` table exists for duplicate prevention

### Step 2: iOS Setup

1. **Add Files to Project**
   - Copy all service files to your project
   - Ensure `StableID` dependency is added
   - Ensure `Supabase` Swift SDK is added

2. **Configure Config.swift**
   - Set `supabaseURL` and `supabaseAnonKey`
   - Configure `enablePaymentTestMode` for testing

3. **Initialize in App**
   ```swift
   .task {
       await CreditManager.shared.initializeNewUser()
   }
   ```

4. **Add UI Component**
   ```swift
   QuotaDisplayView(
       creditManager: CreditManager.shared,
       style: .compact
   )
   ```

### Step 3: App Store Connect Setup

1. **Create In-App Purchase Products**
   - Product IDs: `credits_10`, `credits_25`, `credits_50`, `credits_100`
   - Set prices and descriptions
   - Submit for review

2. **Configure StoreKit Configuration File** (For Testing)
   - Create `.storekit` file in Xcode
   - Add products
   - Select in Scheme > Run > Options > StoreKit Configuration

### Step 4: Testing

1. **Test Mode Testing**
   - Set `enablePaymentTestMode = true`
   - Test purchase flow
   - Verify credits are granted

2. **Sandbox Testing**
   - Set `enablePaymentTestMode = false`
   - Use sandbox tester account
   - Test real purchase flow
   - Verify backend verification works

3. **Production Deployment**
   - Ensure `enablePaymentTestMode = false` in production
   - Test with real purchases (small amount)
   - Monitor backend logs
   - Verify Telegram notifications (if configured)

---

## Key Design Patterns

### 1. Singleton Pattern
- `CreditManager.shared` - Single instance for app-wide state
- `QuotaService.shared` - Single instance for network operations
- `QuotaCache.shared` - Single instance for cache operations
- `StoreKitService.shared` - Single instance for StoreKit operations

### 2. Observable Pattern (SwiftUI)
- `CreditManager` conforms to `ObservableObject`
- `@Published` properties trigger UI updates automatically
- UI components observe via `@ObservedObject` or `@EnvironmentObject`

### 3. Actor Pattern (Concurrency)
- `QuotaService` is an `actor` for thread-safe network operations
- Prevents race conditions in concurrent access

### 4. Idempotency Pattern
- All credit operations are idempotent
- Duplicate requests return cached result
- Prevents double-spending or double-granting

### 5. Cache-Aside Pattern
- Cache is updated after successful backend fetch
- Cache is used when offline or during errors
- Cache is marked stale after 5 minutes

---

## Security Considerations

1. **Backend Verification**: All purchases are verified server-side with Apple
2. **Idempotency**: Prevents duplicate credit grants
3. **RLS (Row Level Security)**: Database enforces user/device access control
4. **Transaction Logging**: All purchases are logged for audit
5. **Error Handling**: Graceful degradation on network errors

---

## Troubleshooting

### Credits Not Updating
- Check network connectivity
- Verify `CreditManager.loadQuota()` is being called
- Check backend logs for errors
- Verify `@Published` properties are being observed in UI

### Payment Verification Fails
- Check Apple credentials (private key, key ID, issuer ID)
- Verify bundle ID matches App Store Connect
- Check backend logs for Apple API errors
- Ensure transaction ID is valid (not "0" in test environment)

### Test Mode Not Working
- Verify `Config.enablePaymentTestMode = true`
- Check that you're running DEBUG build
- Verify test mode logs appear in console

---

## Conclusion

This credit and payment system provides a robust, scalable solution for in-app purchases with:
- ✅ Full StoreKit 2 integration
- ✅ Backend verification for security
- ✅ Offline support with caching
- ✅ Hybrid authentication (users + anonymous)
- ✅ Idempotency for reliability
- ✅ Comprehensive error handling
- ✅ Test mode for development

All components are modular and can be easily integrated into other applications by following this documentation.

---

**Last Updated:** December 2, 2025  
**Version:** 1.0  
**Author:** AI Assistant (Based on BananaUniverse Implementation)

