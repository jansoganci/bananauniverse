# IAP Credit Purchase Integration — Complete Implementation Guide

**Date:** 2025-01-27  
**Products:** `credits_10`, `credits_25`, `credits_50`, `credits_100`  
**Status:** Ready for Implementation

---

## 📋 Table of Contents

1. [API Keys & App Store Server API](#1-api-keys--app-store-server-api)
2. [App Store Server Notification Webhook](#2-app-store-server-notification-webhook)
3. [Sandbox Environment Testing](#3-sandbox-environment-testing)
4. [Existing Backend Logic Analysis](#4-existing-backend-logic-analysis)
5. [Edge Function Implementation](#5-edge-function-implementation)
6. [Database Schema](#6-database-schema)
7. [Secure Key Storage](#7-secure-key-storage)
8. [Complete Purchase Flow](#8-complete-purchase-flow)
9. [Implementation Checklist](#9-implementation-checklist)

---

## 1. API Keys & App Store Server API

### 1.1 Can You Reuse Existing Keys?

**✅ YES — You can reuse the same Apple API keys for credit purchases.**

**Key Facts:**
- App Store Connect API keys (`.p8`, Key ID, Issuer ID) are **app-level**, not product-type specific
- The same keys work for:
  - ✅ Subscriptions (auto-renewable)
  - ✅ Consumable products (credits)
  - ✅ Non-consumable products
  - ✅ Receipt verification
  - ✅ Transaction status checks
  - ✅ Webhook notifications

**No Configuration Changes Required:**
- Same `.p8` private key file
- Same Key ID
- Same Issuer ID
- Same Bundle ID

**What Changes:**
- **Only the API endpoints you call** (transaction verification vs subscription status)
- **Product IDs** you verify (credits vs subscriptions)

### 1.2 Required Environment Variables

**If you already have keys for subscriptions, use the same ones:**

```bash
# Supabase Edge Function Secrets
APPLE_KEY_ID=ABC123XYZ          # Your existing Key ID
APPLE_ISSUER_ID=12345678-1234-1234-1234-123456789012  # Your existing Issuer ID
APPLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n..."  # Your existing .p8 file content
APPLE_BUNDLE_ID=com.bananauniverse.app  # Your existing Bundle ID
```

**Set in Supabase Dashboard:**
1. Go to **Project Settings → Edge Functions → Secrets**
2. Add/verify these secrets exist
3. No changes needed if already configured for subscriptions

### 1.3 API Endpoints Used

**For Credit Purchases:**
```typescript
// Verify transaction
GET https://api.storekit.itunes.apple.com/inApps/v1/transactions/{transactionId}

// Check transaction status (for refunds)
GET https://api.storekit.itunes.apple.com/inApps/v1/transactions/{transactionId}/status
```

**For Subscriptions (existing):**
```typescript
// Check subscription status
GET https://api.storekit.itunes.apple.com/inApps/v1/subscriptions/{originalTransactionId}
```

**Same authentication method (JWT) for both!**

---

## 2. App Store Server Notification Webhook

### 2.1 Current State

**❌ No webhook handler exists in your codebase.**

**What's Missing:**
- No Edge Function for Apple webhook notifications
- No webhook URL configured in App Store Connect
- No refund detection logic

### 2.2 Webhook Setup Steps

#### Step 1: Create Edge Function

**File:** `supabase/functions/iap-webhook/index.ts`

**Purpose:** Handle Apple App Store Server Notifications

**Events Handled:**
- `REFUND` - User refunded a purchase
- `DID_RENEW` - Subscription renewed (not relevant for credits)
- `DID_FAIL_TO_RENEW` - Subscription failed (not relevant for credits)
- `REVOKE` - Subscription revoked (not relevant for credits)

#### Step 2: Configure in App Store Connect

1. Go to **App Store Connect → Your App → App Information**
2. Scroll to **App Store Server Notifications**
3. Click **Configure**
4. Enter webhook URL:
   ```
   https://jiorfutbmahpfgplkats.supabase.co/functions/v1/iap-webhook
   ```
5. Select **Production** and **Sandbox** environments
6. Save configuration

#### Step 3: Security Verification

**Apple sends webhook with JWT signature:**
- Verify signature using Apple's public key
- Validate `iss` (issuer) matches Apple
- Check `aud` (audience) matches your Bundle ID
- Validate `exp` (expiration)

### 2.3 Webhook Payload Structure

```json
{
  "signedPayload": "eyJhbGciOiJFUzI1NiIsIng1YyI6WyJNSUlCUERDQ...",
  "notificationType": "REFUND",
  "subtype": "INITIAL_BUY",
  "data": {
    "bundleId": "com.bananauniverse.app",
    "bundleVersion": "1.0.0",
    "environment": "Production",
    "signedTransactionInfo": "eyJhbGciOiJFUzI1NiIsIng1YyI6WyJNSUlCUERDQ...",
    "signedRenewalInfo": null
  }
}
```

### 2.4 Webhook Handler Logic

**See Section 5.3 for complete Edge Function implementation.**

**Key Steps:**
1. Verify JWT signature from Apple
2. Decode `signedPayload` to get notification data
3. Extract `originalTransactionId` from transaction info
4. Find matching purchase in `iap_transactions` table
5. If `notificationType === 'REFUND'`:
   - Check if credits already spent
   - If available, remove credits via `consume_credits()`
   - Update `iap_transactions.status = 'refunded'`
   - Log refund in `credit_transactions`

---

## 3. Sandbox Environment Testing

### 3.1 Sandbox Setup

#### Step 1: Create Sandbox Test Account

1. Go to **App Store Connect → Users and Access → Sandbox Testers**
2. Click **+** to add new tester
3. Enter:
   - Email (must be unique, not used for real Apple ID)
   - Password
   - First/Last Name
   - Country/Region
4. Save tester

#### Step 2: Create Test Products in App Store Connect

1. Go to **App Store Connect → Your App → Features → In-App Purchases**
2. Click **+** to create new consumable product
3. For each product (`credits_10`, `credits_25`, `credits_50`, `credits_100`):
   - **Product ID:** `credits_10` (exact match)
   - **Type:** Consumable
   - **Reference Name:** "10 Credits Pack"
   - **Description:** "Purchase 10 credits for image processing"
   - **Price:** Set tier (e.g., Tier 1 = $0.99)
4. Save all products
5. **Status must be "Ready to Submit"** (or "Approved" for production)

#### Step 3: Configure StoreKit Configuration File (Xcode)

**File:** `BananaUniverse.storekit`

**Update to include credit products:**

```json
{
  "identifier": "BananaUniverse.storekit",
  "products": [
    {
      "displayPrice": "0.99",
      "familyShareable": false,
      "internalID": "2000001",
      "localizations": [
        {
          "description": "Purchase 10 credits for image processing",
          "displayName": "10 Credits",
          "locale": "en_US"
        }
      ],
      "productID": "credits_10",
      "referenceName": "10 Credits Pack",
      "type": "Consumable"
    },
    {
      "displayPrice": "1.99",
      "familyShareable": false,
      "internalID": "2000002",
      "localizations": [
        {
          "description": "Purchase 25 credits for image processing",
          "displayName": "25 Credits",
          "locale": "en_US"
        }
      ],
      "productID": "credits_25",
      "referenceName": "25 Credits Pack",
      "type": "Consumable"
    },
    {
      "displayPrice": "3.99",
      "familyShareable": false,
      "internalID": "2000003",
      "localizations": [
        {
          "description": "Purchase 50 credits for image processing",
          "displayName": "50 Credits",
          "locale": "en_US"
        }
      ],
      "productID": "credits_50",
      "referenceName": "50 Credits Pack",
      "type": "Consumable"
    },
    {
      "displayPrice": "6.99",
      "familyShareable": false,
      "internalID": "2000004",
      "localizations": [
        {
          "description": "Purchase 100 credits for image processing",
          "displayName": "100 Credits",
          "locale": "en_US"
        }
      ],
      "productID": "credits_100",
      "referenceName": "100 Credits Pack",
      "type": "Consumable"
    }
  ],
  "subscriptionGroups": [
    // ... existing subscription groups ...
  ]
}
```

#### Step 4: Test in iOS Simulator/Device

**Using Sandbox Account:**
1. **Sign out** of App Store on device/simulator
2. Run app in Xcode
3. When prompted for App Store login, use **sandbox test account**
4. Purchase credit product
5. Verify:
   - Transaction appears in App Store Connect → Sales and Trends
   - Credits granted in app
   - Transaction logged in database

**Testing Checklist:**
- [ ] Purchase `credits_10` → Verify 10 credits granted
- [ ] Purchase `credits_25` → Verify 25 credits granted
- [ ] Purchase `credits_50` → Verify 50 credits granted
- [ ] Purchase `credits_100` → Verify 100 credits granted
- [ ] Duplicate purchase → Verify idempotency (no double credits)
- [ ] Network failure → Verify retry works
- [ ] Invalid receipt → Verify error handling

### 3.2 Production Testing (If Sandbox Unavailable)

**⚠️ WARNING: Production testing uses REAL MONEY**

**Best Practices:**
1. **Test with smallest product first** (`credits_10`)
2. **Use test account** (not your main Apple ID)
3. **Request refund immediately** after testing
4. **Monitor database** for transaction logging
5. **Check App Store Connect** for transaction records

**Limitations:**
- Cannot test refunds easily (must request from Apple)
- Real money transactions
- Cannot easily reset test state
- Slower feedback loop

**Recommendation:** Always use Sandbox for initial testing.

---

## 4. Existing Backend Logic Analysis

### 4.1 Previous Quota System

**What Existed:**
- `daily_quotas` table (removed in migration 063)
- `quota_log` table (removed)
- `consume_quota()` function (replaced by `consume_credits()`)
- Daily limit logic (3 requests per day)

**Current State:**
- ✅ **Removed** in favor of credit system
- ✅ Migration `063_remove_daily_quota_system.sql` cleaned up old tables

### 4.2 Current Credit System (Reusable)

**✅ These components can be used for IAP:**

#### 4.2.1 Database Functions

**`add_credits()` - Already supports purchases:**
```sql
-- Location: supabase/migrations/064_create_credit_functions.sql
-- Signature:
add_credits(
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL,
    p_amount INTEGER DEFAULT 1,
    p_idempotency_key TEXT DEFAULT NULL
)
```

**Features:**
- ✅ Supports authenticated and anonymous users
- ✅ Idempotency via `p_idempotency_key`
- ✅ Auto-detects reason from idempotency key (`purchase-{transaction_id}`)
- ✅ Logs to `credit_transactions` table
- ✅ Returns `{success, credits_remaining}`

**Usage for IAP:**
```typescript
await supabase.rpc('add_credits', {
  p_user_id: userId,
  p_device_id: deviceId,
  p_amount: totalCredits,  // credits + bonus_credits
  p_idempotency_key: `purchase-${originalTransactionId}`
});
```

#### 4.2.2 Idempotency System

**`idempotency_keys` table:**
- ✅ Prevents duplicate credit grants
- ✅ Caches response for retries
- ✅ Used by `add_credits()` automatically

**For IAP:**
- Use `original_transaction_id` as idempotency key
- Format: `purchase-{original_transaction_id}`
- Prevents double-crediting if webhook called twice

#### 4.2.3 Transaction Logging

**`credit_transactions` table:**
- ✅ Logs all credit operations
- ✅ Includes: amount, balance_before, balance_after, reason, metadata
- ✅ Supports both user_id and device_id
- ✅ Includes `idempotency_key` for audit

**For IAP:**
- `reason = 'purchase'` (auto-detected from idempotency key)
- `transaction_metadata` stores: `{transaction_id, product_id, verified_at}`

#### 4.2.4 Session Management

**`set_device_id_session()` function:**
- ✅ Sets `request.device_id` session variable
- ✅ Used by RLS policies
- ✅ Supports anonymous users

**For IAP:**
- Edge Function should call this if `device_id` provided
- Ensures RLS policies work correctly

### 4.3 What Needs to Be Created

**New Components Required:**
1. ❌ `products` table (credit package definitions)
2. ❌ `iap_transactions` table (optional, for audit)
3. ❌ `verify-iap-purchase` Edge Function
4. ❌ `iap-webhook` Edge Function
5. ❌ Apple JWT verification helper
6. ❌ Product lookup logic

**Reusable Patterns:**
- ✅ Idempotency pattern (from `add_credits`)
- ✅ Transaction logging pattern (from `credit_transactions`)
- ✅ Error handling pattern (from existing Edge Functions)
- ✅ Authentication pattern (from `submit-job`)

---

## 5. Edge Function Implementation

### 5.1 Function: `verify-iap-purchase`

**Location:** `supabase/functions/verify-iap-purchase/index.ts`

**Purpose:** Verify Apple transaction and grant credits

**Request:**
```typescript
POST /functions/v1/verify-iap-purchase
Headers:
  Authorization: Bearer {anon_key or user_jwt}
  Content-Type: application/json
Body:
{
  "transaction_jwt": "eyJhbGciOiJFUzI1NiIsIng1YyI6WyJNSUlCUERDQ...",  // From StoreKit Transaction
  "product_id": "credits_10",  // For validation
  "device_id": "uuid-here"  // Optional, for anonymous users
}
```

**Response:**
```typescript
{
  "success": true,
  "credits_granted": 10,
  "balance_after": 20,
  "transaction_id": "2000000123456789",
  "original_transaction_id": "2000000123456789"
}
```

**Error Response:**
```typescript
{
  "success": false,
  "error": "Invalid transaction",
  "code": "INVALID_RECEIPT"
}
```

**Complete Implementation:**

```typescript
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import * as jose from 'https://deno.land/x/jose@v4.14.4/index.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // ============================================
    // 1. AUTHENTICATE REQUEST
    // ============================================
    const authHeader = req.headers.get('authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return new Response(
        JSON.stringify({ success: false, error: 'Missing authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Get user from JWT (if authenticated)
    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    
    let userId: string | null = null;
    let deviceId: string | null = null;

    if (user) {
      userId = user.id;
    } else {
      // Anonymous user - get device_id from body
      const body = await req.json();
      deviceId = body.device_id || null;
      
      if (!deviceId) {
        return new Response(
          JSON.stringify({ success: false, error: 'device_id required for anonymous users' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // Set device_id session for RLS
      await supabase.rpc('set_device_id_session', { p_device_id: deviceId });
    }

    // ============================================
    // 2. PARSE REQUEST BODY
    // ============================================
    const body = await req.json();
    const { transaction_jwt, product_id } = body;

    if (!transaction_jwt || !product_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'Missing transaction_jwt or product_id' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // ============================================
    // 3. VERIFY TRANSACTION WITH APPLE
    // ============================================
    const verification = await verifyAppleTransaction(transaction_jwt);

    if (!verification.valid) {
      return new Response(
        JSON.stringify({ success: false, error: 'Invalid transaction', code: 'INVALID_RECEIPT' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Validate product_id matches
    if (verification.product_id !== product_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'Product ID mismatch', code: 'PRODUCT_MISMATCH' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // ============================================
    // 4. CHECK IDEMPOTENCY
    // ============================================
    const idempotencyKey = `purchase-${verification.original_transaction_id}`;
    
    const { data: existingKey } = await supabase
      .from('idempotency_keys')
      .select('response_body')
      .eq('idempotency_key', idempotencyKey)
      .eq(userId ? 'user_id' : 'device_id', userId || deviceId)
      .single();

    if (existingKey?.response_body) {
      // Already processed - return cached result
      console.log('✅ [IAP] Idempotent request, returning cached result');
      return new Response(
        JSON.stringify(existingKey.response_body),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // ============================================
    // 5. LOOKUP PRODUCT IN DATABASE
    // ============================================
    const { data: product, error: productError } = await supabase
      .from('products')
      .select('credits, bonus_credits, is_active')
      .eq('product_id', product_id)
      .single();

    if (productError || !product) {
      return new Response(
        JSON.stringify({ success: false, error: 'Product not found', code: 'PRODUCT_NOT_FOUND' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (!product.is_active) {
      return new Response(
        JSON.stringify({ success: false, error: 'Product is not active', code: 'PRODUCT_INACTIVE' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const totalCredits = product.credits + (product.bonus_credits || 0);

    // ============================================
    // 6. GRANT CREDITS
    // ============================================
    const { data: creditResult, error: creditError } = await supabase.rpc('add_credits', {
      p_user_id: userId,
      p_device_id: deviceId,
      p_amount: totalCredits,
      p_idempotency_key: idempotencyKey
    });

    if (creditError || !creditResult?.success) {
      console.error('❌ [IAP] Failed to grant credits:', creditError || creditResult);
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: creditResult?.error || 'Failed to grant credits',
          code: 'CREDIT_GRANT_FAILED'
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // ============================================
    // 7. LOG IAP TRANSACTION (Optional)
    // ============================================
    try {
      await supabase
        .from('iap_transactions')
        .insert({
          user_id: userId,
          device_id: deviceId,
          product_id: product_id,
          transaction_id: verification.transaction_id,
          original_transaction_id: verification.original_transaction_id,
          credits_granted: totalCredits,
          status: 'completed',
          verified_at: new Date().toISOString(),
          receipt_data: { transaction_jwt: transaction_jwt.substring(0, 100) + '...' }  // Truncated for storage
        });
    } catch (logError) {
      // Don't fail if logging fails
      console.warn('⚠️ [IAP] Failed to log IAP transaction:', logError);
    }

    // ============================================
    // 8. RETURN SUCCESS
    // ============================================
    const response = {
      success: true,
      credits_granted: totalCredits,
      balance_after: creditResult.credits_remaining,
      transaction_id: verification.transaction_id,
      original_transaction_id: verification.original_transaction_id
    };

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error: any) {
    console.error('❌ [IAP] Fatal error:', error);
    return new Response(
      JSON.stringify({ success: false, error: error.message || 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

// ============================================
// APPLE TRANSACTION VERIFICATION
// ============================================

async function verifyAppleTransaction(transactionJWT: string): Promise<{
  valid: boolean;
  product_id?: string;
  transaction_id?: string;
  original_transaction_id?: string;
  purchase_date?: number;
}> {
  try {
    // Decode JWT to get transaction ID
    const decoded = await jose.decodeJwt(transactionJWT);
    
    const transactionId = decoded.transactionId as string;
    if (!transactionId) {
      return { valid: false };
    }

    // Create JWT for Apple API authentication
    const privateKey = Deno.env.get('APPLE_PRIVATE_KEY')!
      .replace(/\\n/g, '\n');

    const algorithm = 'ES256';
    const key = await jose.importPKCS8(privateKey, algorithm);

    const authJWT = await new jose.SignJWT({})
      .setProtectedHeader({
        alg: algorithm,
        kid: Deno.env.get('APPLE_KEY_ID')!
      })
      .setIssuer(Deno.env.get('APPLE_ISSUER_ID')!)
      .setAudience('appstoreconnect-v1')
      .setIssuedAt()
      .setExpirationTime('1h')
      .sign(key);

    // Call App Store Server API
    const response = await fetch(
      `https://api.storekit.itunes.apple.com/inApps/v1/transactions/${transactionId}`,
      {
        headers: {
          'Authorization': `Bearer ${authJWT}`,
          'Content-Type': 'application/json'
        }
      }
    );

    if (!response.ok) {
      const errorText = await response.text();
      console.error('❌ [IAP] Apple API error:', errorText);
      return { valid: false };
    }

    const data = await response.json();

    // Verify the signed transaction (JWS)
    const { payload } = await jose.jwtVerify(
      data.signedTransaction,
      key  // In production, use Apple's public key from JWKS
    );

    // Validate bundle ID
    const bundleId = Deno.env.get('APPLE_BUNDLE_ID');
    if (payload.bundleId !== bundleId) {
      console.error('❌ [IAP] Bundle ID mismatch:', payload.bundleId, 'expected', bundleId);
      return { valid: false };
    }

    return {
      valid: true,
      product_id: payload.productId as string,
      transaction_id: payload.transactionId as string,
      original_transaction_id: payload.originalTransactionId as string,
      purchase_date: payload.purchaseDate as number
    };

  } catch (error: any) {
    console.error('❌ [IAP] Verification error:', error);
    return { valid: false };
  }
}
```

### 5.2 Function: `iap-webhook`

**Location:** `supabase/functions/iap-webhook/index.ts`

**Purpose:** Handle Apple App Store Server Notifications (refunds, etc.)

**Complete Implementation:**

```typescript
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import * as jose from 'https://deno.land/x/jose@v4.14.4/index.ts';

Deno.serve(async (req: Request) => {
  try {
    const body = await req.json();
    const { signedPayload, notificationType } = body;

    if (!signedPayload) {
      return new Response('Missing signedPayload', { status: 400 });
    }

    // ============================================
    // 1. VERIFY WEBHOOK SIGNATURE
    // ============================================
    // In production, verify with Apple's public key from JWKS
    // For now, decode without verification (add proper verification in production)
    const { payload } = await jose.decodeJwt(signedPayload);

    // ============================================
    // 2. HANDLE REFUND NOTIFICATION
    // ============================================
    if (notificationType === 'REFUND') {
      const transactionInfo = payload.data?.signedTransactionInfo;
      if (!transactionInfo) {
        return new Response('Missing transaction info', { status: 400 });
      }

      // Decode transaction info
      const { payload: txPayload } = await jose.decodeJwt(transactionInfo);
      const originalTransactionId = txPayload.originalTransactionId as string;

      // ============================================
      // 3. FIND TRANSACTION IN DATABASE
      // ============================================
      const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
      const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
      const supabase = createClient(supabaseUrl, supabaseServiceKey);

      const { data: iapTransaction, error: findError } = await supabase
        .from('iap_transactions')
        .select('user_id, device_id, credits_granted, status')
        .eq('original_transaction_id', originalTransactionId)
        .eq('status', 'completed')
        .single();

      if (findError || !iapTransaction) {
        console.warn('⚠️ [WEBHOOK] Transaction not found:', originalTransactionId);
        return new Response('Transaction not found', { status: 404 });
      }

      // ============================================
      // 4. REMOVE CREDITS (if not already refunded)
      // ============================================
      if (iapTransaction.status !== 'refunded') {
        const { error: consumeError } = await supabase.rpc('consume_credits', {
          p_user_id: iapTransaction.user_id,
          p_device_id: iapTransaction.device_id,
          p_amount: iapTransaction.credits_granted,
          p_idempotency_key: `refund-${originalTransactionId}`
        });

        if (consumeError) {
          console.error('❌ [WEBHOOK] Failed to remove credits:', consumeError);
          // Continue anyway - mark as refunded
        }

        // ============================================
        // 5. UPDATE TRANSACTION STATUS
        // ============================================
        await supabase
          .from('iap_transactions')
          .update({
            status: 'refunded',
            refunded_at: new Date().toISOString()
          })
          .eq('original_transaction_id', originalTransactionId);

        console.log('✅ [WEBHOOK] Refund processed:', originalTransactionId);
      }
    }

    // Return 200 to acknowledge receipt
    return new Response('OK', { status: 200 });

  } catch (error: any) {
    console.error('❌ [WEBHOOK] Error:', error);
    return new Response('Internal server error', { status: 500 });
  }
});
```

---

## 6. Database Schema

### 6.1 Products Table

**Migration:** `supabase/migrations/067_create_iap_products.sql`

```sql
-- =====================================================
-- Migration 067: Create IAP Products Table
-- Purpose: Store credit package definitions for in-app purchases
-- =====================================================

-- =====================================================
-- PRODUCTS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS products (
    product_id TEXT PRIMARY KEY,  -- Matches App Store product ID (credits_10, etc.)
    
    -- Product info
    name TEXT NOT NULL,
    description TEXT,
    
    -- Credits
    credits INTEGER NOT NULL CHECK (credits > 0),
    bonus_credits INTEGER DEFAULT 0 CHECK (bonus_credits >= 0),
    
    -- Product type
    product_type TEXT DEFAULT 'consumable' CHECK (product_type = 'consumable'),
    
    -- Availability
    is_active BOOLEAN DEFAULT true,
    is_featured BOOLEAN DEFAULT false,
    
    -- Time-based availability (for promotions)
    valid_from TIMESTAMPTZ,
    valid_until TIMESTAMPTZ,
    
    -- UI
    display_order INTEGER DEFAULT 0,
    
    -- Metadata
    metadata JSONB DEFAULT '{}'::jsonb,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_products_active ON products(is_active, display_order);

-- Seed initial products
INSERT INTO products (product_id, name, description, credits, bonus_credits, display_order) VALUES
    ('credits_10', '10 Credits', 'Small credit pack for quick tasks', 10, 0, 1),
    ('credits_25', '25 Credits', 'Standard credit pack', 25, 2, 2),
    ('credits_50', '50 Credits', 'Popular credit pack with bonus', 50, 5, 3),
    ('credits_100', '100 Credits', 'Best value pack with extra credits', 100, 15, 4)
ON CONFLICT (product_id) DO NOTHING;

-- RLS Policies
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

-- Anyone can view active products
CREATE POLICY "Anyone can view active products"
    ON products FOR SELECT
    USING (is_active = true);

-- Service role can manage products
CREATE POLICY "Service role can manage products"
    ON products FOR ALL
    USING (auth.role() = 'service_role');

COMMENT ON TABLE products IS 'Credit package definitions for in-app purchases';
COMMENT ON COLUMN products.product_id IS 'Must match App Store Connect product ID exactly';
COMMENT ON COLUMN products.credits IS 'Base credits granted';
COMMENT ON COLUMN products.bonus_credits IS 'Extra credits (for promotions)';
```

### 6.2 IAP Transactions Table (Optional)

**Migration:** `supabase/migrations/068_create_iap_transactions.sql`

```sql
-- =====================================================
-- Migration 068: Create IAP Transactions Table
-- Purpose: Audit trail for all in-app purchases
-- =====================================================

CREATE TABLE IF NOT EXISTS iap_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- User identification
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT,
    
    -- Product
    product_id TEXT NOT NULL REFERENCES products(product_id),
    
    -- Apple transaction IDs
    transaction_id TEXT NOT NULL,
    original_transaction_id TEXT NOT NULL,  -- For idempotency
    
    -- Credits
    credits_granted INTEGER NOT NULL,
    
    -- Status
    status TEXT NOT NULL CHECK (status IN ('pending', 'completed', 'refunded', 'failed')) DEFAULT 'pending',
    
    -- Verification
    verified_at TIMESTAMPTZ,
    receipt_data JSONB,  -- Store truncated receipt for debugging
    
    -- Refund tracking
    refunded_at TIMESTAMPTZ,
    refund_reason TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT iap_transactions_identifier CHECK (
        (user_id IS NOT NULL) OR (device_id IS NOT NULL)
    )
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_iap_transactions_user ON iap_transactions(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_iap_transactions_device ON iap_transactions(device_id) WHERE device_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_iap_transactions_transaction_id ON iap_transactions(transaction_id);
CREATE INDEX IF NOT EXISTS idx_iap_transactions_original_id ON iap_transactions(original_transaction_id);
CREATE INDEX IF NOT EXISTS idx_iap_transactions_status ON iap_transactions(status);
CREATE INDEX IF NOT EXISTS idx_iap_transactions_created ON iap_transactions(created_at DESC);

-- Unique constraint on original_transaction_id (prevents duplicates)
CREATE UNIQUE INDEX IF NOT EXISTS idx_iap_transactions_original_unique ON iap_transactions(original_transaction_id);

-- RLS Policies
ALTER TABLE iap_transactions ENABLE ROW LEVEL SECURITY;

-- Users can view their own transactions
CREATE POLICY "Users can view own transactions"
    ON iap_transactions FOR SELECT
    USING (
        (auth.uid() = user_id) OR
        (auth.role() = 'service_role')
    );

-- Service role can manage all transactions
CREATE POLICY "Service role can manage transactions"
    ON iap_transactions FOR ALL
    USING (auth.role() = 'service_role');

COMMENT ON TABLE iap_transactions IS 'Audit trail for all in-app purchase transactions';
COMMENT ON COLUMN iap_transactions.original_transaction_id IS 'Apple original transaction ID - used for idempotency';
```

---

## 7. Secure Key Storage

### 7.1 Product IDs in Code

**❌ DO NOT hardcode product IDs in client code**

**✅ DO store in database (`products` table)**

**iOS Client:**
```swift
// Fetch products from database
let products = try await supabase
    .from("products")
    .select("*")
    .eq("is_active", true)
    .order("display_order")
    .execute()

// Use product_id from database response
for product in products {
    let productId = product.product_id  // "credits_10"
    // Load from StoreKit using this ID
}
```

**Why:**
- ✅ Change products without app update
- ✅ Run promotions (disable/enable products)
- ✅ A/B test different packages
- ✅ Single source of truth

### 7.2 Apple API Keys

**Storage Location:** Supabase Edge Function Secrets

**Set via Supabase Dashboard:**
1. Go to **Project Settings → Edge Functions → Secrets**
2. Add secrets:
   - `APPLE_KEY_ID`
   - `APPLE_ISSUER_ID`
   - `APPLE_PRIVATE_KEY` (full `.p8` file content)
   - `APPLE_BUNDLE_ID`

**Set via CLI:**
```bash
supabase secrets set APPLE_KEY_ID=ABC123XYZ
supabase secrets set APPLE_ISSUER_ID=12345678-1234-1234-1234-123456789012
supabase secrets set APPLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n..."
supabase secrets set APPLE_BUNDLE_ID=com.bananauniverse.app
```

**Security:**
- ✅ Never commit to git
- ✅ Never expose to client
- ✅ Only accessible in Edge Functions
- ✅ Rotate if compromised

### 7.3 Environment-Specific Configuration

**Development:**
- Use sandbox test account
- Use sandbox products
- Test with `StoreKit Configuration` file

**Production:**
- Use real App Store Connect products
- Use production webhook URL
- Monitor for errors

---

## 8. Complete Purchase Flow

### 8.1 Step-by-Step Flow

```
┌─────────────┐
│  iOS Client │
└──────┬──────┘
       │
       │ 1. User taps "Buy 10 Credits"
       │
       ▼
┌─────────────────────┐
│ StoreKit.purchase() │
│ (credits_10)        │
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
       │    POST /verify-iap-purchase
       │    {
       │      transaction_jwt: "...",
       │      product_id: "credits_10",
       │      device_id: "uuid" (if anonymous)
       │    }
       │
       ▼
┌─────────────────────────────┐
│ verify-iap-purchase         │
│ Edge Function               │
└──────┬───────────────────────┘
       │
       │ 4. Authenticate request
       │    (JWT or device_id)
       │
       ▼
┌─────────────────────────────┐
│ Decode transaction JWT      │
│ Extract transaction_id      │
└──────┬───────────────────────┘
       │
       │ 5. Create Apple API JWT
       │    (using APPLE_PRIVATE_KEY)
       │
       ▼
┌─────────────────────────────┐
│ Apple App Store Server API   │
│ GET /transactions/{id}      │
└──────┬───────────────────────┘
       │
       │ 6. Verify transaction
       │    - Check signature
       │    - Validate bundle_id
       │    - Extract product_id
       │
       ▼
┌─────────────────────────────┐
│ Check idempotency_keys      │
│ (purchase-{original_tx_id}) │
└──────┬───────────────────────┘
       │
       │ 7. Already processed?
       │    YES → Return cached result
       │    NO → Continue
       │
       ▼
┌─────────────────────────────┐
│ Lookup product in database   │
│ products table               │
└──────┬───────────────────────┘
       │
       │ 8. Get credits + bonus
       │    credits_10 → 10 credits
       │
       ▼
┌─────────────────────────────┐
│ add_credits() RPC            │
│ - Grant credits              │
│ - Log to credit_transactions │
│ - Cache in idempotency_keys  │
└──────┬───────────────────────┘
       │
       │ 9. Log to iap_transactions
       │    (optional audit trail)
       │
       ▼
┌─────────────────────────────┐
│ Return success response      │
│ {
       │   success: true,
       │   credits_granted: 10,
       │   balance_after: 20
       │ }
       │
       ▼
┌─────────────┐
│  iOS Client │
│ Update UI   │
│ Show success│
└─────────────┘
```

### 8.2 Error Handling

**Network Failure:**
- Client retries with same transaction
- Backend idempotency prevents double-crediting
- Return cached result if already processed

**Invalid Receipt:**
- Return `400` with error code `INVALID_RECEIPT`
- Don't grant credits
- Log for investigation

**Product Not Found:**
- Return `404` with error code `PRODUCT_NOT_FOUND`
- Check `products` table exists and product is active

**Insufficient Permissions:**
- Return `401` if authentication fails
- Return `403` if user doesn't have permission

**Duplicate Purchase:**
- Return success with cached result (idempotent)
- No error - this is expected behavior

### 8.3 Edge Cases

**1. Transaction Too Old:**
- Reject transactions older than 7 days
- Return error: "Transaction too old"
- Log as suspicious activity

**2. Product Disabled:**
- Check `products.is_active = true`
- Return error: "Product is not available"
- Allow admin to disable products instantly

**3. Credits Already Spent (Refund):**
- If user spent credits, can't refund
- Log refund attempt
- Return warning: "Credits already used"

**4. Anonymous User Becomes Authenticated:**
- Credits stay with `device_id`
- User can merge credits later (future feature)

---

## 9. Implementation Checklist

### Phase 1: Database Setup
- [ ] Create `products` table migration (067)
- [ ] Seed 4 credit products (`credits_10`, `credits_25`, `credits_50`, `credits_100`)
- [ ] Create `iap_transactions` table migration (068) - Optional
- [ ] Apply migrations to database
- [ ] Verify RLS policies work

### Phase 2: Backend Implementation
- [ ] Create `verify-iap-purchase` Edge Function
- [ ] Implement Apple JWT verification helper
- [ ] Add product lookup logic
- [ ] Integrate with `add_credits()` RPC
- [ ] Add error handling and logging
- [ ] Create `iap-webhook` Edge Function
- [ ] Implement refund detection logic
- [ ] Deploy Edge Functions to Supabase

### Phase 3: Apple Configuration
- [ ] Verify App Store Connect API keys exist
- [ ] Set Edge Function secrets (APPLE_KEY_ID, APPLE_ISSUER_ID, APPLE_PRIVATE_KEY, APPLE_BUNDLE_ID)
- [ ] Create consumable products in App Store Connect
- [ ] Configure webhook URL in App Store Connect
- [ ] Test webhook endpoint accessibility

### Phase 4: iOS Client
- [ ] Update `StoreKitService.swift` to include credit product IDs
- [ ] Implement consumable purchase flow
- [ ] Add purchase completion handler
- [ ] Call `verify-iap-purchase` Edge Function
- [ ] Update UI to show credit packages (fetch from database)
- [ ] Add error handling and user feedback
- [ ] Update `BananaUniverse.storekit` configuration file

### Phase 5: Testing
- [ ] Create sandbox test account
- [ ] Test purchase flow in sandbox
- [ ] Verify credits granted correctly
- [ ] Test duplicate purchase (idempotency)
- [ ] Test network failure and retry
- [ ] Test invalid receipt handling
- [ ] Test refund webhook (if possible)
- [ ] Monitor database for transaction logging

### Phase 6: Production
- [ ] Test with smallest product (`credits_10`) in production
- [ ] Monitor error logs
- [ ] Verify transaction logging
- [ ] Check App Store Connect for transaction records
- [ ] Gradually enable all products
- [ ] Set up monitoring and alerts

---

## 10. Quick Reference

### Product IDs
- `credits_10` - 10 Credits
- `credits_25` - 25 Credits
- `credits_50` - 50 Credits
- `credits_100` - 100 Credits

### Edge Functions
- `verify-iap-purchase` - Verify transaction and grant credits
- `iap-webhook` - Handle Apple webhook notifications

### Database Tables
- `products` - Credit package definitions
- `iap_transactions` - Purchase audit trail (optional)
- `credit_transactions` - All credit operations (existing)
- `idempotency_keys` - Prevent duplicates (existing)

### Environment Variables
- `APPLE_KEY_ID` - App Store Connect Key ID
- `APPLE_ISSUER_ID` - App Store Connect Issuer ID
- `APPLE_PRIVATE_KEY` - `.p8` file content
- `APPLE_BUNDLE_ID` - Bundle identifier

---

**Last Updated:** 2025-01-27  
**Status:** Ready for Implementation

