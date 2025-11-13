# In-App Purchase (IAP) Credit Purchase Integration Analysis

**Date:** 2025-01-27  
**Purpose:** Comprehensive analysis and implementation plan for IAP credit purchases  
**Status:** Not Currently Implemented

---

## 📊 Executive Summary

**Current State:**
- ✅ StoreKit 2 integration exists (subscriptions only)
- ✅ Backend credit system ready (`add_credits`, `credit_transactions`)
- ❌ **No credit purchase products defined**
- ❌ **No receipt verification for credit purchases**
- ❌ **No Edge Function for IAP credit validation**
- ❌ **No products table for credit packages**

**What's Needed:**
1. Products table for credit packages
2. Edge Function for Apple receipt verification
3. iOS client purchase flow for consumables
4. Apple App Store Server API integration
5. Refund detection webhook

---

## 1. Current State Analysis

### 1.1 iOS App (StoreKit)

**File:** `BananaUniverse/Core/Services/StoreKitService.swift`

**Current Implementation:**
- ✅ StoreKit 2 integrated
- ✅ Handles **subscriptions only** (`banana_weekly`, `banana_yearly`)
- ✅ Transaction verification with `checkVerified()`
- ✅ Syncs subscriptions to Supabase via `sync_subscription` RPC
- ❌ **No consumable credit products**
- ❌ **No credit purchase flow**

**Current Product IDs:**
```swift
private let productIds = ["banana_weekly", "banana_yearly"]  // Subscriptions only
```

**What's Missing:**
- Credit product IDs (e.g., `credits_10`, `credits_50`, `credits_100`)
- Consumable purchase flow
- Credit purchase completion handler

### 1.2 Backend Infrastructure

**Existing:**
- ✅ `add_credits()` function (supports purchase reason)
- ✅ `credit_transactions` table (audit logging)
- ✅ `subscriptions` table (for subscriptions, not credits)
- ✅ `idempotency_keys` table (prevents duplicate purchases)

**Missing:**
- ❌ `products` table (credit package definitions)
- ❌ Edge Function for receipt verification
- ❌ Apple App Store Server API integration
- ❌ Refund detection webhook

### 1.3 App Store Connect / Play Console

**Status:** Unknown - Need to verify

**Required Setup:**
1. Create consumable products in App Store Connect:
   - `credits_10` - 10 Credits Pack
   - `credits_50` - 50 Credits Pack
   - `credits_100` - 100 Credits Pack
   - `credits_500` - 500 Credits Pack (optional)

2. Configure product metadata:
   - Price (set in App Store Connect)
   - Display name
   - Description

---

## 2. Backend Infrastructure Requirements

### 2.1 Products Table

**Purpose:** Store credit package definitions (product_id → credits mapping)

**Schema:**
```sql
CREATE TABLE products (
    product_id TEXT PRIMARY KEY,  -- Matches App Store product ID
    name TEXT NOT NULL,            -- Display name
    description TEXT,
    credits INTEGER NOT NULL CHECK (credits > 0),
    bonus_credits INTEGER DEFAULT 0,
    product_type TEXT DEFAULT 'consumable',
    is_active BOOLEAN DEFAULT true,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Why Database vs Hardcoded:**
- ✅ Change prices/packages without app update
- ✅ Run promotions (bonus credits)
- ✅ A/B test different packages
- ✅ Disable products instantly

### 2.2 Edge Function: `verify-iap-purchase`

**Purpose:** Verify Apple receipt and grant credits

**Flow:**
1. Receive transaction JWT from iOS client
2. Verify with Apple App Store Server API
3. Check for duplicate (idempotency)
4. Look up product → credits mapping
5. Grant credits via `add_credits()`
6. Log transaction

**Security:**
- Verify JWT signature with Apple public key
- Check transaction ID uniqueness
- Validate product_id exists in database
- Rate limiting per user/device

### 2.3 Apple App Store Server API

**Required:**
- App Store Connect API Key (`.p8` file)
- Key ID
- Issuer ID
- Bundle ID

**Endpoints Used:**
- `GET /v1/transactions/{transactionId}` - Verify transaction
- `GET /v1/transactions/{transactionId}/status` - Check refund status

---

## 3. Recommended Purchase Flow

### 3.1 Complete Flow Diagram

```
┌─────────────┐
│  iOS Client │
└──────┬──────┘
       │
       │ 1. User taps "Buy 50 Credits"
       │
       ▼
┌─────────────────────┐
│ StoreKit.purchase() │
└──────┬──────────────┘
       │
       │ 2. Apple processes payment
       │
       ▼
┌─────────────────────┐
│ Transaction JWT     │
│ (signed by Apple)   │
└──────┬──────────────┘
       │
       │ 3. Send to backend
       │
       ▼
┌─────────────────────────────┐
│ verify-iap-purchase         │
│ Edge Function                │
└──────┬───────────────────────┘
       │
       │ 4. Verify with Apple
       │
       ▼
┌─────────────────────────────┐
│ Apple App Store Server API  │
│ (Verify JWT signature)      │
└──────┬───────────────────────┘
       │
       │ 5. Transaction verified
       │
       ▼
┌─────────────────────────────┐
│ Check idempotency_keys      │
│ (Prevent duplicate)         │
└──────┬───────────────────────┘
       │
       │ 6. Not seen before
       │
       ▼
┌─────────────────────────────┐
│ Lookup product → credits    │
│ (products table)            │
└──────┬───────────────────────┘
       │
       │ 7. credits_50 → 50 credits
       │
       ▼
┌─────────────────────────────┐
│ add_credits()                │
│ (Grant credits)              │
└──────┬───────────────────────┘
       │
       │ 8. Credits added
       │
       ▼
┌─────────────────────────────┐
│ Log to credit_transactions   │
│ (Audit trail)               │
└──────┬───────────────────────┘
       │
       │ 9. Return success
       │
       ▼
┌─────────────┐
│  iOS Client │
│ (Update UI) │
└─────────────┘
```

### 3.2 Security Best Practices

**1. Server-Side Verification (Critical)**
- ✅ Always verify on backend (never trust client)
- ✅ Use Apple App Store Server API
- ✅ Verify JWT signature with Apple public key

**2. Idempotency (Prevent Duplicates)**
- ✅ Use `original_transaction_id` as idempotency key
- ✅ Check `idempotency_keys` table before granting credits
- ✅ Return cached result if already processed

**3. Fraud Prevention**
- ✅ Rate limiting (max purchases per hour)
- ✅ Validate product_id exists in database
- ✅ Check transaction age (reject very old transactions)
- ✅ Verify bundle ID matches

**4. Error Handling**
- ✅ Network failures → Retry mechanism
- ✅ Invalid receipt → Return error, don't grant credits
- ✅ Duplicate purchase → Return success (idempotent)
- ✅ Expired receipt → Reject

---

## 4. Database Schema Requirements

### 4.1 Products Table

```sql
CREATE TABLE products (
    product_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    credits INTEGER NOT NULL CHECK (credits > 0),
    bonus_credits INTEGER DEFAULT 0 CHECK (bonus_credits >= 0),
    product_type TEXT DEFAULT 'consumable' CHECK (product_type = 'consumable'),
    is_active BOOLEAN DEFAULT true,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_products_active ON products(is_active, display_order);

-- Seed initial products
INSERT INTO products (product_id, name, description, credits, bonus_credits, display_order) VALUES
    ('credits_10', '10 Credits', 'Small credit pack', 10, 0, 1),
    ('credits_50', '50 Credits', 'Popular credit pack', 50, 5, 2),
    ('credits_100', '100 Credits', 'Best value pack', 100, 20, 3),
    ('credits_500', '500 Credits', 'Mega pack', 500, 100, 4);
```

### 4.2 IAP Transactions Table (Optional but Recommended)

**Purpose:** Store all IAP transactions for audit and refund detection

```sql
CREATE TABLE iap_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT,
    product_id TEXT NOT NULL REFERENCES products(product_id),
    transaction_id TEXT NOT NULL UNIQUE,  -- Apple transaction ID
    original_transaction_id TEXT NOT NULL,  -- For idempotency
    credits_granted INTEGER NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('pending', 'completed', 'refunded', 'failed')),
    receipt_data JSONB,  -- Store full receipt for debugging
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT iap_transactions_identifier CHECK (
        (user_id IS NOT NULL) OR (device_id IS NOT NULL)
    )
);

-- Indexes
CREATE INDEX idx_iap_transactions_user ON iap_transactions(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_iap_transactions_device ON iap_transactions(device_id) WHERE device_id IS NOT NULL;
CREATE INDEX idx_iap_transactions_transaction_id ON iap_transactions(transaction_id);
CREATE INDEX idx_iap_transactions_original_id ON iap_transactions(original_transaction_id);
CREATE INDEX idx_iap_transactions_status ON iap_transactions(status);
```

### 4.3 Update credit_transactions

**Already exists** - Just ensure `reason = 'purchase'` is logged correctly.

**Current schema supports:**
- `reason` column (includes 'purchase')
- `idempotency_key` column
- `transaction_metadata` JSONB (can store transaction_id)

---

## 5. User/Device Identification & Security

### 5.1 User Identification

**Authenticated Users:**
- Use `user_id` from JWT token
- Set via `auth.uid()` in Supabase

**Anonymous Users:**
- Use `device_id` (UUID stored in app)
- Set via `set_device_id_session()` RPC

### 5.2 Replay Attack Prevention

**Mechanisms:**
1. **Idempotency Keys:**
   ```sql
   -- Use original_transaction_id as idempotency key
   p_idempotency_key = 'purchase-' + original_transaction_id
   ```

2. **Transaction ID Uniqueness:**
   ```sql
   -- Check if transaction_id already exists
   SELECT 1 FROM iap_transactions 
   WHERE transaction_id = $1
   ```

3. **Rate Limiting:**
   ```sql
   -- Max 10 purchases per hour per user/device
   SELECT COUNT(*) FROM iap_transactions
   WHERE (user_id = $1 OR device_id = $2)
     AND created_at > NOW() - INTERVAL '1 hour'
   ```

### 5.3 Session Management

**Current Implementation:**
- `set_device_id_session()` function exists
- Sets `request.device_id` session variable
- Used by RLS policies

**For IAP:**
- Edge Function should call `set_device_id_session()` if `device_id` provided
- Ensures RLS policies work correctly

---

## 6. Transaction Logging & Audit Trails

### 6.1 Current Logging

**Already Implemented:**
- ✅ `credit_transactions` table logs all credit operations
- ✅ `add_credits()` function logs transactions
- ✅ Includes: amount, balance_before, balance_after, reason, metadata

### 6.2 Enhanced Logging for IAP

**What to Log:**
1. **credit_transactions:**
   - `reason = 'purchase'`
   - `idempotency_key = 'purchase-{original_transaction_id}'`
   - `transaction_metadata = { transaction_id, product_id, verified_at }`

2. **iap_transactions (new table):**
   - Full receipt data
   - Verification status
   - Refund status

### 6.3 Audit Queries

```sql
-- All credit purchases today
SELECT 
    ct.user_id,
    ct.device_id,
    ct.amount as credits_purchased,
    ct.transaction_metadata->>'product_id' as product_id,
    ct.transaction_metadata->>'transaction_id' as apple_transaction_id,
    ct.created_at
FROM credit_transactions ct
WHERE ct.reason = 'purchase'
  AND DATE(ct.created_at) = CURRENT_DATE
ORDER BY ct.created_at DESC;

-- Revenue by product
SELECT 
    ct.transaction_metadata->>'product_id' as product_id,
    COUNT(*) as purchase_count,
    SUM(ct.amount) as total_credits_sold
FROM credit_transactions ct
WHERE ct.reason = 'purchase'
  AND ct.created_at > NOW() - INTERVAL '30 days'
GROUP BY product_id
ORDER BY total_credits_sold DESC;
```

---

## 7. Refund Detection & Handling

### 7.1 Apple Refund Detection

**Method 1: App Store Server Notifications (Recommended)**
- Set up webhook URL in App Store Connect
- Apple sends notifications for refunds
- Edge Function processes refund notification

**Method 2: Periodic Status Check**
- Cron job checks transaction status
- Less real-time but simpler

### 7.2 Refund Webhook Flow

```
Apple App Store
      │
      │ REFUND notification
      │
      ▼
┌─────────────────────────────┐
│ iap-refund-webhook          │
│ Edge Function               │
└──────┬───────────────────────┘
       │
       │ 1. Verify webhook signature
       │
       ▼
┌─────────────────────────────┐
│ Extract transaction_id       │
└──────┬───────────────────────┘
       │
       │ 2. Find transaction
       │
       ▼
┌─────────────────────────────┐
│ iap_transactions table      │
└──────┬───────────────────────┘
       │
       │ 3. Get credits_granted
       │
       ▼
┌─────────────────────────────┐
│ consume_credits()           │
│ (Remove credits)            │
└──────┬───────────────────────┘
       │
       │ 4. Update status
       │
       ▼
┌─────────────────────────────┐
│ Update iap_transactions     │
│ status = 'refunded'          │
└─────────────────────────────┘
```

### 7.3 Refund Safety

**Prevent Double Refunds:**
- Check if already refunded
- Use idempotency for refund operations
- Log refund in `credit_transactions` (negative amount)

**Edge Cases:**
- User already spent credits → Can't refund (credits used)
- Partial refund → Only refund unused credits
- Refund after subscription → Handle gracefully

---

## 8. Error Handling & Edge Cases

### 8.1 Network Failures

**Scenario:** iOS client sends receipt, but network fails before response

**Solution:**
- Client retries with same transaction
- Backend idempotency prevents double-crediting
- Return cached result if already processed

### 8.2 Expired Receipts

**Scenario:** User tries to use old transaction (weeks old)

**Solution:**
- Reject transactions older than 7 days
- Log as suspicious activity
- Return error: "Transaction too old, please contact support"

### 8.3 Partial Purchases

**Scenario:** Payment succeeds but verification fails

**Solution:**
- Don't grant credits until verified
- Return error to client
- Client can retry verification
- Apple will not charge again (transaction already processed)

### 8.4 Invalid Products

**Scenario:** Product ID doesn't exist in database

**Solution:**
- Return error: "Product not found"
- Log for investigation
- Don't grant credits

### 8.5 Duplicate Purchases

**Scenario:** User purchases same product twice

**Solution:**
- Idempotency check returns cached result
- Both purchases grant credits (intended behavior)
- User gets credits for each purchase

---

## 9. Client-Side vs Server-Side Validation

### 9.1 Client-Side (iOS)

**Responsibilities:**
- ✅ Initiate purchase via StoreKit
- ✅ Handle purchase UI/UX
- ✅ Send transaction JWT to backend
- ✅ Display success/error messages
- ❌ **Never grant credits locally**
- ❌ **Never trust client for credit balance**

### 9.2 Server-Side (Supabase)

**Responsibilities:**
- ✅ Verify transaction with Apple
- ✅ Check for duplicates
- ✅ Grant credits via `add_credits()`
- ✅ Log all transactions
- ✅ Handle refunds
- ✅ Enforce rate limits

### 9.3 Security Principle

**Golden Rule:** Client initiates, server validates and grants.

**Never:**
- Trust client for credit amounts
- Grant credits without server verification
- Skip receipt verification

**Always:**
- Verify receipt on backend
- Check idempotency
- Log all operations

---

## 10. Edge Function Implementation Outline

### 10.1 Function: `verify-iap-purchase`

**Location:** `supabase/functions/verify-iap-purchase/index.ts`

**Request Body:**
```typescript
{
  transaction_jwt: string,  // Apple transaction JWT
  product_id: string,       // Product ID (for validation)
  device_id?: string,      // For anonymous users
  user_id?: string         // For authenticated users (from JWT)
}
```

**Response:**
```typescript
{
  success: boolean,
  credits_granted?: number,
  balance_after?: number,
  transaction_id?: string,
  error?: string
}
```

**Flow:**
1. Authenticate request (service role or user JWT)
2. Verify transaction JWT with Apple App Store Server API
3. Extract `original_transaction_id` from JWT
4. Check idempotency (`purchase-{original_transaction_id}`)
5. Lookup product in `products` table
6. Calculate total credits (credits + bonus_credits)
7. Call `add_credits()` with idempotency key
8. Insert into `iap_transactions` table
9. Return success response

**Error Responses:**
- `400` - Invalid request (missing fields)
- `401` - Unauthorized
- `402` - Invalid receipt/transaction
- `409` - Duplicate purchase (return success with cached result)
- `404` - Product not found
- `500` - Server error

### 10.2 Function: `iap-refund-webhook`

**Location:** `supabase/functions/iap-refund-webhook/index.ts`

**Purpose:** Handle Apple refund notifications

**Flow:**
1. Verify webhook signature (Apple JWT)
2. Extract refunded transaction_id
3. Find transaction in `iap_transactions`
4. Check if credits already spent
5. If credits available, remove via `consume_credits()`
6. Update `iap_transactions.status = 'refunded'`
7. Log refund in `credit_transactions`

---

## 11. Multiple Product Tiers

### 11.1 Recommended Packages

| Product ID | Credits | Bonus | Total | Price (Example) |
|------------|---------|-------|-------|-----------------|
| `credits_10` | 10 | 0 | 10 | $0.99 |
| `credits_50` | 50 | 5 | 55 | $4.99 |
| `credits_100` | 100 | 20 | 120 | $9.99 |
| `credits_500` | 500 | 100 | 600 | $39.99 |

### 11.2 Dynamic Product Management

**Benefits of Database:**
- Change prices without app update
- Run promotions (increase bonus_credits)
- A/B test different packages
- Disable products instantly

**Example Promotion:**
```sql
-- Double bonus credits for holidays
UPDATE products 
SET bonus_credits = credits * 0.2  -- 20% bonus
WHERE product_id IN ('credits_50', 'credits_100', 'credits_500')
  AND valid_until > NOW();
```

### 11.3 Product Display Logic

**iOS Client:**
```swift
// Fetch products from database
let products = try await supabase
    .from("products")
    .select("*")
    .eq("is_active", true)
    .order("display_order")
    .execute()

// Display in UI
for product in products {
    // Show product card with credits + bonus
}
```

---

## 12. Test Plan

### 12.1 Sandbox Testing

**Setup:**
1. Create sandbox test account in App Store Connect
2. Use sandbox environment in iOS app
3. Test with sandbox products

**Test Cases:**
1. ✅ Successful purchase → Credits granted
2. ✅ Duplicate purchase → Idempotent (no double credits)
3. ✅ Invalid product → Error returned
4. ✅ Network failure → Retry works
5. ✅ Expired transaction → Rejected
6. ✅ Refund → Credits removed

### 12.2 Production Testing

**Before Launch:**
1. Test with real products (smallest package)
2. Verify receipt validation works
3. Check transaction logging
4. Test refund flow
5. Monitor for errors

### 12.3 Monitoring

**Key Metrics:**
- Purchase success rate
- Average credits per purchase
- Refund rate
- Error rate by type
- Revenue per product

**Alerts:**
- High error rate (> 5%)
- Unusual refund spike
- Failed verifications
- Duplicate detection failures

---

## 13. Implementation Checklist

### Phase 1: Database Setup
- [ ] Create `products` table migration
- [ ] Seed initial credit products
- [ ] Create `iap_transactions` table (optional)
- [ ] Update `add_credits()` to handle purchase reason

### Phase 2: Backend
- [ ] Create `verify-iap-purchase` Edge Function
- [ ] Integrate Apple App Store Server API
- [ ] Implement receipt verification
- [ ] Add idempotency checks
- [ ] Create `iap-refund-webhook` Edge Function (optional)

### Phase 3: iOS Client
- [ ] Add credit product IDs to StoreKitService
- [ ] Implement consumable purchase flow
- [ ] Add purchase completion handler
- [ ] Update UI to show credit packages
- [ ] Add error handling

### Phase 4: App Store Connect
- [ ] Create consumable products
- [ ] Set prices
- [ ] Configure product metadata
- [ ] Set up App Store Server API key
- [ ] Configure refund webhook (optional)

### Phase 5: Testing
- [ ] Sandbox testing
- [ ] Production testing
- [ ] Refund testing
- [ ] Error scenario testing

### Phase 6: Monitoring
- [ ] Set up error alerts
- [ ] Create analytics queries
- [ ] Monitor purchase success rate
- [ ] Track revenue metrics

---

## 14. Code Examples

### 14.1 Edge Function: verify-iap-purchase

**See:** `supabase/functions/verify-iap-purchase/index.ts` (to be created)

**Key Functions:**
- `verifyAppleTransaction()` - Verify JWT with Apple
- `checkIdempotency()` - Prevent duplicates
- `getProductCredits()` - Lookup product → credits
- `grantCredits()` - Call `add_credits()`
- `logTransaction()` - Audit trail

### 14.2 iOS Client Update

**StoreKitService.swift:**
```swift
// Add credit product IDs
private let creditProductIds = [
    "credits_10",
    "credits_50", 
    "credits_100",
    "credits_500"
]

// Purchase credit product
func purchaseCredits(_ product: Product) async throws {
    let result = try await product.purchase()
    
    switch result {
    case .success(let verification):
        let transaction = try checkVerified(verification)
        
        // Send to backend for verification and credit grant
        try await verifyAndGrantCredits(
            transaction: transaction,
            productId: product.id
        )
        
        await transaction.finish()
        
    case .userCancelled:
        // Handle cancellation
        break
        
    @unknown default:
        break
    }
}

// Verify with backend
private func verifyAndGrantCredits(
    transaction: Transaction,
    productId: String
) async throws {
    let response = try await SupabaseService.shared.client
        .functions
        .invoke("verify-iap-purchase", options: FunctionInvokeOptions(
            body: [
                "transaction_jwt": transaction.jwsRepresentation,
                "product_id": productId,
                "device_id": await getDeviceUUID()
            ]
        ))
    
    // Handle response
    if response.data["success"] as? Bool == true {
        // Credits granted, refresh balance
        await CreditManager.shared.refreshBalance()
    }
}
```

---

## 15. Security Checklist

- [ ] Receipt verification on backend (never trust client)
- [ ] JWT signature validation with Apple public key
- [ ] Idempotency for all purchases
- [ ] Rate limiting (max purchases per hour)
- [ ] Transaction age validation (reject old transactions)
- [ ] Bundle ID verification
- [ ] Product ID validation (exists in database)
- [ ] User/device authentication
- [ ] Audit logging for all operations
- [ ] Refund detection and handling

---

## 16. Next Steps

1. **Review this analysis** - Confirm approach
2. **Create products table** - Database migration
3. **Set up App Store Connect** - Create products
4. **Implement Edge Function** - Receipt verification
5. **Update iOS client** - Purchase flow
6. **Test in sandbox** - End-to-end validation
7. **Deploy to production** - Monitor closely

---

**Last Updated:** 2025-01-27

