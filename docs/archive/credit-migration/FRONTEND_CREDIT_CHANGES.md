# Frontend Credit System Changes

This document details all iOS/SwiftUI/MVVM changes required to migrate from the quota system to the credit system.

---

## Overview

The frontend migration involves:
1. **New Core Services**: Replace quota logic with credit logic
2. **New Models**: Define credit-specific data structures
3. **ViewModel Updates**: Change quota checks to credit checks
4. **UI Updates**: Change wording from "Daily Quota" to "Credits"

**Key Principle**: Server-authoritative credits. The iOS app **displays** credit balance but the server **enforces** credit deduction.

---

## 1. New Core Services

### 1.1 `CreditManager.swift` (REPLACES `HybridCreditManager.swift`)

**File Path**: `BananaUniverse/Core/Services/CreditManager.swift`
**Status**: **NEW** (rewrite of HybridCreditManager)

#### Purpose
Orchestrates credit state between network (CreditService), cache (CreditCache), and UI (@Published properties).

#### Key Properties
```swift
@Published private(set) var creditBalance: Int = 0
@Published private(set) var lifetimePurchased: Int = 0
@Published private(set) var lifetimeSpent: Int = 0
@Published private(set) var isPremiumUser: Bool = false
@Published private(set) var isLoading: Bool = false
```

#### Key Methods
- `loadCredits() async` → Fetches credit balance from backend via CreditService
- `deductCredits(amount: Int) async throws -> CreditTransaction` → Calls backend to deduct credits (for manual operations, not used during image processing)
- `canProcessImage(cost: Int = 1) -> Bool` → Returns true if user has enough credits OR is premium
- `refreshPremiumStatus() async` → Syncs with StoreKitService to update isPremiumUser
- `updateFromBackendResponse(balance: Int, premium: Bool) async` → Called by SupabaseService after image processing

#### Computed Properties
- `creditDisplayText: String` → "X credits" or "Unlimited"
- `shouldShowLowCreditWarning: Bool` → true if balance < 5 and not premium
- `lowCreditWarningMessage: String` → "⚠️ Low credit balance! Only X credits remaining."

#### Reusable Patterns from HybridCreditManager
- **Cache integration** (lines 76-82, 275-291): Load cached balance on init, save to cache on update
- **Background refresh** (lines 293-312): Re-fetch credits on app foreground
- **StoreKit premium sync** (lines 197-219): Refresh premium status when subscription changes

#### Breaking Changes
- **REMOVED**: `dailyQuotaUsed`, `dailyQuotaLimit`, `remainingQuota` properties
- **REMOVED**: `consumeQuota()` method (credit deduction now happens server-side during image processing)
- **ADDED**: `creditBalance`, `lifetimePurchased`, `lifetimeSpent` properties
- **ADDED**: `canProcessImage(cost:)` method for pre-flight checks

---

### 1.2 `CreditService.swift` (REPLACES `QuotaService.swift`)

**File Path**: `BananaUniverse/Core/Services/CreditService.swift`
**Status**: **NEW** (rewrite of QuotaService)

#### Purpose
Network layer for credit-related RPC calls to Supabase backend.

#### Key Methods
- `getCredits(userId: String?, deviceId: String?) async throws -> CreditBalance` → RPC call to `get_credits`
- `deductCredits(amount: Int, userId: String?, deviceId: String?, requestId: String) async throws -> CreditTransaction` → RPC call to `deduct_credits` (not used in image processing flow)

#### RPC Parameters
```swift
// get_credits
params = [
  "p_user_id": userId ?? nil,
  "p_device_id": deviceId ?? nil
]

// deduct_credits (manual operations only)
params = [
  "p_user_id": userId ?? nil,
  "p_device_id": deviceId ?? nil,
  "p_amount": amount,
  "p_request_id": requestId,
  "p_reason": "manual_deduction"
]
```

#### Error Handling
- Throws `CreditError.insufficientCredits` if balance < amount
- Throws `CreditError.network` for RPC failures
- Throws `CreditError.invalidResponse` for malformed JSON

---

### 1.3 `CreditCache.swift` (REPLACES `QuotaCache.swift`)

**File Path**: `BananaUniverse/Core/Services/CreditCache.swift`
**Status**: **NEW** (adapted from QuotaCache)

#### Purpose
Local persistent storage for credit balance (UserDefaults-based).

#### Key Methods
- `save(balance: Int, premium: Bool)`
- `load() -> CachedCredits?` → Returns cached balance + timestamp
- `clear()` → Removes cached data
- `migrateFromV1IfNeeded()` → Migrates old quota cache keys to credit keys

#### Cache Structure
```swift
struct CachedCredits: Codable {
    let balance: Int
    let premium: Bool
    let timestamp: Date
}
```

#### Cache Key
- `credit_balance_cache_v1` (versioned for future migrations)

---

## 2. New Models

### 2.1 `CreditBalance.swift` (REPLACES `QuotaInfo.swift`)

**File Path**: `BananaUniverse/Core/Models/CreditBalance.swift`
**Status**: **NEW**

#### Structure
```swift
struct CreditBalance: Codable {
    let balance: Int
    let lifetimePurchased: Int
    let lifetimeSpent: Int
    let isPremium: Bool

    enum CodingKeys: String, CodingKey {
        case balance
        case lifetimePurchased = "lifetime_purchased"
        case lifetimeSpent = "lifetime_spent"
        case isPremium = "is_premium"
    }
}
```

#### Usage
- Returned by `CreditService.getCredits()`
- Used to update `CreditManager` state

---

### 2.2 `CreditTransaction.swift`

**File Path**: `BananaUniverse/Core/Models/CreditTransaction.swift`
**Status**: **NEW**

#### Structure
```swift
struct CreditTransaction: Codable {
    let id: String
    let amount: Int
    let balanceAfter: Int
    let reason: String
    let timestamp: Date
    let idempotent: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case amount
        case balanceAfter = "balance_after"
        case reason
        case timestamp = "created_at"
        case idempotent
    }
}
```

#### Usage
- Returned by `CreditService.deductCredits()` (manual operations)
- Can be used for transaction history UI (future feature)

---

### 2.3 `CreditError.swift` (REPLACES `QuotaError.swift`)

**File Path**: `BananaUniverse/Core/Models/CreditError.swift`
**Status**: **NEW**

#### Error Cases
```swift
enum CreditError: LocalizedError {
    case insufficientCredits
    case network(Error)
    case invalidResponse(String)
    case decode(String)

    var errorDescription: String? {
        switch self {
        case .insufficientCredits:
            return "Insufficient credits. Please purchase more or upgrade to Premium."
        case .network(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        case .decode(let message):
            return "Failed to decode: \(message)"
        }
    }
}
```

---

## 3. ViewModel Updates

### 3.1 `ChatViewModel.swift`

**File Path**: `BananaUniverse/Features/Chat/ViewModels/ChatViewModel.swift`
**Status**: **UPDATED**

#### Changes Required

**Lines 67-73**: Replace quota properties
```swift
// BEFORE
var dailyQuotaUsed: Int {
    return creditManager.dailyQuotaUsed
}
var dailyQuotaLimit: Int {
    return creditManager.dailyQuotaLimit
}

// AFTER
var creditBalance: Int {
    return creditManager.creditBalance
}
```

**Lines 84-90**: Update computed properties
```swift
// BEFORE
var remainingQuota: Int {
    return creditManager.remainingQuota
}

// AFTER
var remainingCredits: Int {
    return creditManager.creditBalance
}
```

**Lines 193-198**: Update quota check
```swift
// BEFORE
if !authService.isAuthenticated {
    if dailyQuotaUsed >= dailyQuotaLimit {
        showingPaywall = true
        return
    }
}

// AFTER
if !authService.isAuthenticated {
    if !creditManager.canProcessImage() {
        showingPaywall = true
        return
    }
}
```

**Error Messages**: Update text
- "Daily limit reached" → "Insufficient credits. Purchase more or upgrade to Premium."

---

### 3.2 `LibraryViewModel.swift`

**File Path**: `BananaUniverse/Features/Library/ViewModels/LibraryViewModel.swift`
**Status**: **UPDATED** (if it references quota)

#### Changes Required
- Replace any `creditManager.dailyQuotaUsed` with `creditManager.creditBalance`
- Update error messages to reference "credits" not "quota"

---

### 3.3 Other ViewModels

Search codebase for:
- `dailyQuota`
- `remainingQuota`
- `QuotaInfo`
- `consumeQuota`

Update all references to use credit equivalents.

---

## 4. UI Component Updates

### 4.1 `CreditDisplayView.swift` (REPLACES `QuotaDisplayView.swift`)

**File Path**: `BananaUniverse/Core/Components/CreditDisplayView.swift`
**Status**: **RENAMED + UPDATED**

#### Changes Required

**Line 111**: Update title text
```swift
// BEFORE
Text(creditManager.isPremiumUser ? "Credits" : "Daily Credits")

// AFTER
Text("Credits")
```

**Line 117**: Update value text
```swift
// BEFORE
Text(creditManager.isPremiumUser ? "Unlimited" : "\(creditManager.dailyQuotaUsed) / \(creditManager.dailyQuotaLimit)")

// AFTER
Text(creditManager.isPremiumUser ? "Unlimited" : "\(creditManager.creditBalance) credits")
```

**Line 131**: Update compact text
```swift
// BEFORE
Text(creditManager.isPremiumUser ? "∞" : "Daily Credits: \(creditManager.remainingQuota) / \(creditManager.dailyQuotaLimit)")

// AFTER
Text(creditManager.isPremiumUser ? "∞" : "\(creditManager.creditBalance) credits")
```

**Low Credit Warning** (Line 125-129)
- Keep warning icon logic: `creditManager.shouldShowLowCreditWarning`
- Update threshold: Show warning when `creditBalance < 5` (not based on daily limit)

---

### 4.2 `UnifiedHeaderBar.swift`

**File Path**: `BananaUniverse/Core/Components/UnifiedHeaderBar.swift`
**Status**: **UPDATED**

#### Changes Required
- Replace `QuotaDisplayView` import with `CreditDisplayView`
- Update view instantiation: `QuotaDisplayView()` → `CreditDisplayView()`

---

### 4.3 Paywall Screens

**Files**:
- `BananaUniverse/Features/Paywall/Views/PreviewPaywallView.swift`
- `BananaUniverse/Features/Paywall/Views/PaywallPreview.swift`

#### Changes Required
- Update messaging:
  - "Upgrade for unlimited daily generations" → "Upgrade for unlimited credits"
  - "5 free generations per day" → "10 free credits to start" (or whatever initial grant)
- Update feature list:
  - "Daily quota resets at midnight" → "Credits never expire"

---

### 4.4 Profile View

**File Path**: `BananaUniverse/Features/Profile/Views/ProfileView.swift`
**Status**: **UPDATED**

#### Changes Required
- Update quota section to show credits:
  - "Daily Quota: X / Y" → "Credits: X" or "Unlimited"
- Update info text:
  - "Resets daily at midnight UTC" → "Credits never expire"

---

## 5. Premium User Handling

### Client-Side Logic

**Premium Bypass**:
- `CreditManager.isPremiumUser` is synced from `StoreKitService.isPremiumUser`
- When `isPremiumUser == true`:
  - `canProcessImage()` returns `true` (no credit check)
  - UI shows "Unlimited" or "∞" instead of credit count
  - No credit deduction happens (server also bypasses)

**Premium Status Refresh**:
- On app foreground: `CreditManager.refreshPremiumStatus()` → syncs with StoreKit
- After subscription purchase: `StoreKitService` triggers `CreditManager.refreshPremiumStatus()`
- Backend validates premium status via `subscriptions` table (server-authoritative)

**UI States**:
- Free user with credits: "X credits"
- Free user without credits: "0 credits" + paywall gate
- Premium user: "Unlimited" + no gates

---

## 6. StoreKit Integration

### 6.1 `StoreKitService.swift`

**File Path**: `BananaUniverse/Core/Services/StoreKitService.swift`
**Status**: **UPDATED** (minor addition)

#### Changes Required

**Line 83**: After successful purchase, sync credits
```swift
// AFTER
await transaction.finish()
purchasedProducts.insert(product.id)
await updateSubscriptionStatus()
await syncSubscriptionToSupabase(transaction: transaction, productId: product.id)

// NEW: Refresh premium status in CreditManager
await CreditManager.shared.refreshPremiumStatus()

// OPTIONAL: Grant bonus credits on first purchase
// await CreditService.shared.addBonusCredits(amount: 10, reason: "first_purchase")
```

**No other changes required** - subscription logic is independent of credits.

---

## 7. Cache Migration

### 7.1 UserDefaults Keys

**Old Keys** (to be cleared):
- `quota_cache_v2` (from QuotaCache)
- `user_state_v1` (keep, reused)
- `device_uuid_v1` (keep, reused)

**New Keys**:
- `credit_balance_cache_v1`

**Migration Strategy**:
- On first launch after update: `CreditCache.migrateFromV1IfNeeded()`
- Clear old quota keys
- Fetch fresh credit balance from server
- Cache new balance

---

## 8. File Cleanup (Phase 7)

### Files to DELETE
```
BananaUniverse/Core/Services/HybridCreditManager.swift  (replaced by CreditManager.swift)
BananaUniverse/Core/Services/QuotaService.swift         (replaced by CreditService.swift)
BananaUniverse/Core/Services/QuotaCache.swift           (replaced by CreditCache.swift)
BananaUniverse/Core/Models/QuotaInfo.swift              (replaced by CreditBalance.swift)
BananaUniverse/Core/Models/QuotaError.swift             (replaced by CreditError.swift)
```

### Files to CREATE
```
BananaUniverse/Core/Services/CreditManager.swift
BananaUniverse/Core/Services/CreditService.swift
BananaUniverse/Core/Services/CreditCache.swift
BananaUniverse/Core/Models/CreditBalance.swift
BananaUniverse/Core/Models/CreditTransaction.swift
BananaUniverse/Core/Models/CreditError.swift
BananaUniverse/Core/Components/CreditDisplayView.swift  (renamed from QuotaDisplayView)
```

---

## 9. Testing Checklist

### Unit Tests
- [ ] `CreditManager.loadCredits()` fetches balance from backend
- [ ] `CreditManager.canProcessImage()` returns false when balance = 0
- [ ] `CreditManager.canProcessImage()` returns true for premium users (any balance)
- [ ] `CreditCache` saves and loads correctly
- [ ] `CreditService.getCredits()` parses response correctly

### Integration Tests
- [ ] Image processing fails when balance = 0 (shows paywall)
- [ ] Image processing succeeds when balance > 0 (deducts credit)
- [ ] Premium user can process unlimited images
- [ ] Credit balance updates after successful processing
- [ ] Low credit warning appears when balance < 5

### UI Tests
- [ ] `CreditDisplayView` shows "X credits" for free users
- [ ] `CreditDisplayView` shows "Unlimited" for premium users
- [ ] Paywall appears when attempting to process with 0 credits
- [ ] Profile screen shows correct credit balance

---

## 10. Migration Impact Summary

### Breaking Changes
- All `QuotaInfo` usages must be replaced with `CreditBalance`
- All `dailyQuotaUsed/Limit` references must be replaced with `creditBalance`
- All UI text mentioning "daily quota" must be updated to "credits"

### Non-Breaking Changes
- StoreKit integration unchanged (subscriptions still work)
- Authentication flow unchanged (user_id / device_id pattern preserved)
- Cache pattern unchanged (still uses UserDefaults)

### Backwards Compatibility
- **NOT SUPPORTED** - Old quota system is fully removed
- Users must update to new iOS app version
- Recommend force update in App Store

---

## Next Steps

1. Create new service files (`CreditManager`, `CreditService`, `CreditCache`)
2. Create new model files (`CreditBalance`, `CreditTransaction`, `CreditError`)
3. Update ViewModels to use new services
4. Update UI components with new wording
5. Run full test suite
6. Submit to App Store with force update flag
