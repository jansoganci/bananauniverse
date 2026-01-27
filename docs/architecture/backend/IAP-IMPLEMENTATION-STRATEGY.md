# In-App Purchase (IAP) Implementation Strategy

**Purpose:** Document patterns for implementing Apple In-App Purchases with products database, subscription handling, and refund systems.

**Generated:** 2025-01-15

**Target:** AI agent system templates for solo developers

---

## 🎯 Current Implementation Status

### ✅ What Already Exists

Your current backend has these IAP patterns implemented:

| Pattern | Status | Implementation |
|---------|--------|----------------|
| **Server-side Verification** | ✅ Implemented | App Store Server API with JWT |
| **Transaction Validation** | ✅ Implemented | Signature verification |
| **Duplicate Prevention** | ✅ Implemented | Using original_transaction_id |
| **One-Time Purchases** | ✅ Implemented | Credit grants for consumables |
| **Basic Purchase Flow** | ✅ Implemented | Deduct → Verify → Grant → Log |

### 🟡 What Needs Documentation

Patterns that need to be documented as templates:

1. **Products in Database** - Dynamic product management without redeployment
2. **Subscription Handling** - Renewals, grace periods, cancellations
3. **Refund System** - Detection, rollback, and notifications

---

## 📊 Decision Framework: Products Database vs Hardcoded

### Option A: Hardcoded Products (Simple) ⚡

**Your Current Approach** (needs migration to database)

**Best for:**
- Single product apps
- Fixed pricing forever
- No promotions or bonuses
- Minimal product changes

**Implementation:**
```typescript
// Hardcoded in Edge Function
const PRODUCTS = {
  'com.app.credits.pack1': { credits: 10, name: '10 Credits' },
  'com.app.credits.pack2': { credits: 50, name: '50 Credits' },
  'com.app.credits.pack3': { credits: 100, name: '100 Credits' }
}
```

**Pros:**
- ✅ Simple implementation
- ✅ No database queries needed
- ✅ Fast lookups
- ✅ Easy to understand

**Cons:**
- ❌ Changes require redeployment
- ❌ Can't run promotions easily
- ❌ No A/B testing possible
- ❌ Can't disable products quickly
- ❌ No bonus credits without deploy

---

### Option B: Products in Database (Flexible) ✅ **RECOMMENDED**

**Best for:**
- Multiple products
- Promotional campaigns
- A/B testing pricing
- Seasonal offers
- Bonus credit campaigns
- Growing apps

**Implementation:**
```sql
CREATE TABLE products (
    product_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    credits INTEGER NOT NULL,
    bonus_credits INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    is_promotional BOOLEAN DEFAULT false,
    valid_from TIMESTAMPTZ,
    valid_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);
```

**Pros:**
- ✅ Add products without deploying
- ✅ Run limited-time promotions
- ✅ A/B test pricing
- ✅ Disable products instantly
- ✅ Add bonus credits dynamically
- ✅ Track product performance

**Cons:**
- ⚠️ Requires database query per purchase
- ⚠️ Slightly more complex
- ⚠️ Need admin interface for management

**Decision:** Use database for production apps. Use hardcoded only for prototypes.

---

## 🏗️ Pattern 1: Products Database Implementation

### Database Schema

```sql
-- ==========================================
-- PRODUCTS TABLE
-- ==========================================
CREATE TABLE products (
    product_id TEXT PRIMARY KEY,  -- Matches App Store product ID
    name TEXT NOT NULL,            -- Display name
    description TEXT,              -- Product description

    -- Pricing (for reference, actual price from App Store)
    price_tier TEXT,               -- e.g., "tier_1", "tier_5"
    price_usd NUMERIC(10,2),       -- For analytics only

    -- Credits
    credits INTEGER NOT NULL,      -- Base credits granted
    bonus_credits INTEGER DEFAULT 0,  -- Extra credits (promotions)

    -- Product Type
    product_type TEXT CHECK (product_type IN ('consumable', 'non_consumable', 'auto_renewable_subscription', 'non_renewing_subscription')),

    -- Availability
    is_active BOOLEAN DEFAULT true,  -- Can be purchased
    is_promotional BOOLEAN DEFAULT false,  -- Is this a promo offer
    is_featured BOOLEAN DEFAULT false,  -- Show prominently in UI

    -- Time-based availability
    valid_from TIMESTAMPTZ,        -- When promo starts
    valid_until TIMESTAMPTZ,       -- When promo ends

    -- Metadata
    display_order INTEGER DEFAULT 0,  -- Sort order in UI
    metadata JSONB DEFAULT '{}'::jsonb,  -- Custom fields

    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),

    -- Indexes
    INDEX idx_products_active (is_active, display_order)
);

-- ==========================================
-- PRODUCT HISTORY (for audit trail)
-- ==========================================
CREATE TABLE product_history (
    id BIGSERIAL PRIMARY KEY,
    product_id TEXT NOT NULL,
    change_type TEXT CHECK (change_type IN ('created', 'updated', 'activated', 'deactivated', 'promo_started', 'promo_ended')),
    old_value JSONB,
    new_value JSONB,
    changed_by TEXT,  -- Admin user or system
    changed_at TIMESTAMPTZ DEFAULT now()
);

-- ==========================================
-- SEED DATA (Example)
-- ==========================================
INSERT INTO products (product_id, name, description, credits, bonus_credits, product_type, is_active, display_order) VALUES
('com.yourapp.credits.small', 'Starter Pack', '10 credits to get started', 10, 0, 'consumable', true, 1),
('com.yourapp.credits.medium', 'Popular Pack', '50 credits + 5 bonus', 50, 5, 'consumable', true, 2),
('com.yourapp.credits.large', 'Best Value', '100 credits + 20 bonus', 100, 20, 'consumable', true, 3),
('com.yourapp.subscription.monthly', 'Monthly Pro', '100 credits per month', 100, 0, 'auto_renewable_subscription', true, 4);
```

---

### Migration Pattern: Hardcoded → Database

**Step-by-step migration approach:**

#### Phase 1: Dual Mode (Backward Compatible)
```typescript
// _shared/products.ts

async function getProduct(productId: string): Promise<Product> {
  // Try database first
  const { data: dbProduct } = await supabaseClient
    .from('products')
    .select('*')
    .eq('product_id', productId)
    .eq('is_active', true)
    .single()

  if (dbProduct) {
    return dbProduct
  }

  // Fallback to hardcoded (during migration)
  const HARDCODED_PRODUCTS = {
    'com.app.credits.pack1': {
      product_id: 'com.app.credits.pack1',
      name: '10 Credits',
      credits: 10,
      bonus_credits: 0,
      product_type: 'consumable'
    },
    // ... other products
  }

  const hardcodedProduct = HARDCODED_PRODUCTS[productId]
  if (hardcodedProduct) {
    // Log warning: product not in database
    console.warn(`Product ${productId} not in database, using hardcoded fallback`)
    return hardcodedProduct
  }

  throw new Error(`Unknown product: ${productId}`)
}
```

#### Phase 2: Migrate Existing Products
```sql
-- Insert all hardcoded products into database
INSERT INTO products (product_id, name, credits, bonus_credits, product_type, is_active)
VALUES
  ('com.app.credits.pack1', '10 Credits', 10, 0, 'consumable', true),
  ('com.app.credits.pack2', '50 Credits', 50, 0, 'consumable', true),
  ('com.app.credits.pack3', '100 Credits', 100, 0, 'consumable', true);
```

#### Phase 3: Remove Hardcoded Fallback
```typescript
async function getProduct(productId: string): Promise<Product> {
  const { data: product, error } = await supabaseClient
    .from('products')
    .select('*')
    .eq('product_id', productId)
    .eq('is_active', true)
    .single()

  if (error || !product) {
    throw new Error(`Product not found or inactive: ${productId}`)
  }

  return product
}
```

---

### Dynamic Product Management Patterns

#### 1. Limited-Time Promotions

```sql
-- Add Black Friday bonus (50% more credits)
UPDATE products
SET bonus_credits = credits * 0.5,
    is_promotional = true,
    valid_from = '2024-11-29 00:00:00',
    valid_until = '2024-12-02 23:59:59'
WHERE product_type = 'consumable';

-- Automatically end promotions (scheduled job)
UPDATE products
SET bonus_credits = 0,
    is_promotional = false
WHERE is_promotional = true
  AND valid_until < now();
```

#### 2. A/B Testing Products

```sql
-- Create variant products for testing
INSERT INTO products (product_id, name, credits, bonus_credits, product_type, is_active, metadata)
VALUES
  ('com.app.credits.test_a', '50 Credits', 50, 0, 'consumable', true, '{"variant": "control"}'),
  ('com.app.credits.test_b', '50 Credits', 50, 10, 'consumable', true, '{"variant": "bonus_10"}');

-- Analyze which variant converts better
SELECT
  p.metadata->>'variant' as variant,
  COUNT(*) as purchases,
  SUM(p.credits + p.bonus_credits) as total_credits_sold
FROM quota_log ql
JOIN products p ON ql.metadata->>'product_id' = p.product_id
WHERE ql.reason = 'iap_purchase'
  AND ql.created_at > now() - interval '7 days'
GROUP BY p.metadata->>'variant';
```

#### 3. Seasonal Products

```sql
-- Create holiday-themed product
INSERT INTO products (
  product_id,
  name,
  credits,
  bonus_credits,
  product_type,
  is_promotional,
  valid_from,
  valid_until,
  metadata
) VALUES (
  'com.app.credits.holiday2024',
  '🎄 Holiday Special',
  100,
  50,  -- 50% bonus
  'consumable',
  true,
  '2024-12-15 00:00:00',
  '2024-12-26 23:59:59',
  '{"theme": "christmas", "limited_edition": true}'
);
```

#### 4. Disable Product Instantly (Emergency)

```sql
-- Disable problematic product immediately
UPDATE products
SET is_active = false
WHERE product_id = 'com.app.credits.buggy_product';

-- Log the deactivation
INSERT INTO product_history (product_id, change_type, changed_by)
VALUES ('com.app.credits.buggy_product', 'deactivated', 'admin');
```

---

### Updated Purchase Flow with Database Products

```typescript
// POST /update-credits (with database products)

async function handlePurchase(userId: string, transactionId: string) {
  // 1. Verify transaction with Apple
  const verification = await verifyAppleTransaction(transactionId)

  // 2. Get product from DATABASE (not hardcoded!)
  const { data: product, error: productError } = await supabaseClient
    .from('products')
    .select('*')
    .eq('product_id', verification.product_id)
    .eq('is_active', true)  // Only active products
    .single()

  if (productError || !product) {
    return { error: 'Product not found or inactive' }
  }

  // 3. Check if promotional period is valid
  if (product.is_promotional) {
    const now = new Date()
    const validFrom = product.valid_from ? new Date(product.valid_from) : null
    const validUntil = product.valid_until ? new Date(product.valid_until) : null

    if (validFrom && now < validFrom) {
      return { error: 'Promotion not yet started' }
    }
    if (validUntil && now > validUntil) {
      return { error: 'Promotion expired' }
    }
  }

  // 4. Calculate total credits (base + bonus)
  const totalCredits = product.credits + product.bonus_credits

  // 5. Grant credits atomically
  const { data: result } = await supabaseClient.rpc('add_credits', {
    p_user_id: userId,
    p_amount: totalCredits,
    p_reason: 'iap_purchase',
    p_transaction_id: verification.original_transaction_id,
    p_metadata: {
      product_id: product.product_id,
      product_name: product.name,
      base_credits: product.credits,
      bonus_credits: product.bonus_credits,
      is_promotional: product.is_promotional,
      transaction_id: transactionId
    }
  })

  return result
}
```

---

## 🔄 Pattern 2: Subscription Handling

### Subscription Lifecycle

```
┌─────────────────────────────────────────────────────┐
│ Subscription Lifecycle                              │
└─────────────────────────────────────────────────────┘

1. User Subscribes
   ↓
   CREATE subscription record
   GRANT initial credits

2. Monthly Renewal
   ↓
   Webhook: DID_RENEW
   GRANT monthly credits
   UPDATE expiration_date

3. Grace Period (payment issue)
   ↓
   Webhook: DID_FAIL_TO_RENEW
   MARK as grace_period
   ALLOW continued access

4. Recovered from Grace
   ↓
   Webhook: DID_RECOVER
   GRANT monthly credits
   UPDATE status to active

5. Expired (not recovered)
   ↓
   Webhook: EXPIRED
   REVOKE access
   UPDATE status to expired

6. User Cancels
   ↓
   Webhook: DID_CHANGE_RENEWAL_STATUS
   MARK will_renew = false
   ALLOW access until expiration

7. Refunded
   ↓
   Webhook: REFUND
   DEDUCT credits
   UPDATE status to refunded
```

---

### Database Schema for Subscriptions

```sql
-- ==========================================
-- SUBSCRIPTIONS TABLE
-- ==========================================
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) NOT NULL,

    -- Apple Subscription IDs
    original_transaction_id TEXT UNIQUE NOT NULL,  -- Never changes
    latest_transaction_id TEXT NOT NULL,           -- Updates on renewal

    -- Product Info
    product_id TEXT REFERENCES products(product_id),

    -- Status
    status TEXT CHECK (status IN ('active', 'expired', 'grace_period', 'billing_retry', 'cancelled', 'refunded')) NOT NULL,

    -- Renewal
    will_auto_renew BOOLEAN DEFAULT true,
    auto_renew_enabled BOOLEAN DEFAULT true,

    -- Dates
    purchase_date TIMESTAMPTZ NOT NULL,
    expires_date TIMESTAMPTZ NOT NULL,
    grace_period_expires_date TIMESTAMPTZ,

    -- Billing
    billing_retry_date TIMESTAMPTZ,

    -- Credits
    credits_per_period INTEGER NOT NULL,  -- How many credits granted per renewal
    total_renewals INTEGER DEFAULT 0,      -- Track renewal count

    -- Metadata
    metadata JSONB DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),

    -- Indexes
    INDEX idx_subscriptions_user (user_id, status),
    INDEX idx_subscriptions_original_tx (original_transaction_id),
    INDEX idx_subscriptions_expires (expires_date)
);

-- ==========================================
-- SUBSCRIPTION EVENTS (webhook log)
-- ==========================================
CREATE TABLE subscription_events (
    id BIGSERIAL PRIMARY KEY,
    subscription_id UUID REFERENCES subscriptions(id),

    event_type TEXT NOT NULL,  -- Apple notification type
    transaction_id TEXT NOT NULL,

    -- Event details
    event_data JSONB NOT NULL,
    processed BOOLEAN DEFAULT false,

    created_at TIMESTAMPTZ DEFAULT now(),

    INDEX idx_subscription_events_subscription (subscription_id, created_at DESC),
    INDEX idx_subscription_events_unprocessed (processed, created_at)
);
```

---

### Subscription Event Handlers

#### Initial Subscription Purchase

```typescript
// Webhook: INITIAL_BUY

async function handleInitialSubscription(notification: AppleNotification) {
  const { original_transaction_id, transaction_id, product_id, expires_date } = notification.data

  // 1. Get product details
  const product = await getProduct(product_id)

  // 2. Create subscription record
  const { data: subscription } = await supabaseClient
    .from('subscriptions')
    .insert({
      user_id: notification.user_id,
      original_transaction_id,
      latest_transaction_id: transaction_id,
      product_id,
      status: 'active',
      will_auto_renew: true,
      purchase_date: new Date(),
      expires_date: new Date(expires_date),
      credits_per_period: product.credits
    })
    .select()
    .single()

  // 3. Grant initial credits
  await supabaseClient.rpc('add_credits', {
    p_user_id: notification.user_id,
    p_amount: product.credits,
    p_reason: 'subscription_initial',
    p_transaction_id: original_transaction_id,
    p_metadata: {
      subscription_id: subscription.id,
      product_id: product_id
    }
  })

  // 4. Log event
  await supabaseClient.from('subscription_events').insert({
    subscription_id: subscription.id,
    event_type: 'INITIAL_BUY',
    transaction_id,
    event_data: notification,
    processed: true
  })
}
```

---

#### Subscription Renewal

```typescript
// Webhook: DID_RENEW

async function handleSubscriptionRenewal(notification: AppleNotification) {
  const { original_transaction_id, transaction_id, expires_date } = notification.data

  // 1. Find subscription
  const { data: subscription } = await supabaseClient
    .from('subscriptions')
    .select('*')
    .eq('original_transaction_id', original_transaction_id)
    .single()

  if (!subscription) {
    throw new Error('Subscription not found')
  }

  // 2. Check for duplicate renewal (idempotency)
  const { data: existingEvent } = await supabaseClient
    .from('subscription_events')
    .select('id')
    .eq('transaction_id', transaction_id)
    .eq('event_type', 'DID_RENEW')
    .single()

  if (existingEvent) {
    console.log('Renewal already processed')
    return
  }

  // 3. Update subscription
  await supabaseClient
    .from('subscriptions')
    .update({
      latest_transaction_id: transaction_id,
      status: 'active',
      expires_date: new Date(expires_date),
      total_renewals: subscription.total_renewals + 1,
      updated_at: new Date()
    })
    .eq('id', subscription.id)

  // 4. Grant monthly credits
  await supabaseClient.rpc('add_credits', {
    p_user_id: subscription.user_id,
    p_amount: subscription.credits_per_period,
    p_reason: 'subscription_renewal',
    p_transaction_id: transaction_id,
    p_metadata: {
      subscription_id: subscription.id,
      renewal_count: subscription.total_renewals + 1
    }
  })

  // 5. Log event
  await supabaseClient.from('subscription_events').insert({
    subscription_id: subscription.id,
    event_type: 'DID_RENEW',
    transaction_id,
    event_data: notification,
    processed: true
  })

  // 6. Send notification to user
  await sendPushNotification(subscription.user_id, {
    title: 'Subscription Renewed',
    body: `${subscription.credits_per_period} credits added to your account`
  })
}
```

---

#### Grace Period Handling

```typescript
// Webhook: DID_FAIL_TO_RENEW

async function handleFailedRenewal(notification: AppleNotification) {
  const { original_transaction_id, grace_period_expires_date } = notification.data

  // 1. Update subscription to grace period
  await supabaseClient
    .from('subscriptions')
    .update({
      status: 'grace_period',
      grace_period_expires_date: new Date(grace_period_expires_date),
      updated_at: new Date()
    })
    .eq('original_transaction_id', original_transaction_id)

  // 2. Notify user of payment issue
  const { data: subscription } = await supabaseClient
    .from('subscriptions')
    .select('user_id')
    .eq('original_transaction_id', original_transaction_id)
    .single()

  await sendPushNotification(subscription.user_id, {
    title: 'Payment Issue',
    body: 'Please update your payment method to continue your subscription'
  })
}

// Webhook: DID_RECOVER

async function handleGraceRecovery(notification: AppleNotification) {
  const { original_transaction_id, transaction_id, expires_date } = notification.data

  // 1. Update subscription back to active
  const { data: subscription } = await supabaseClient
    .from('subscriptions')
    .update({
      status: 'active',
      latest_transaction_id: transaction_id,
      expires_date: new Date(expires_date),
      grace_period_expires_date: null,
      updated_at: new Date()
    })
    .eq('original_transaction_id', original_transaction_id)
    .select()
    .single()

  // 2. Grant credits for the recovered period
  await supabaseClient.rpc('add_credits', {
    p_user_id: subscription.user_id,
    p_amount: subscription.credits_per_period,
    p_reason: 'subscription_recovery',
    p_transaction_id: transaction_id
  })
}
```

---

#### Cancellation Handling

```typescript
// Webhook: DID_CHANGE_RENEWAL_STATUS

async function handleCancellation(notification: AppleNotification) {
  const { original_transaction_id, auto_renew_status } = notification.data

  // auto_renew_status: true = resubscribed, false = cancelled

  await supabaseClient
    .from('subscriptions')
    .update({
      will_auto_renew: auto_renew_status,
      auto_renew_enabled: auto_renew_status,
      updated_at: new Date()
    })
    .eq('original_transaction_id', original_transaction_id)

  // If cancelled, allow access until expiration
  if (!auto_renew_status) {
    const { data: subscription } = await supabaseClient
      .from('subscriptions')
      .select('user_id, expires_date')
      .eq('original_transaction_id', original_transaction_id)
      .single()

    await sendPushNotification(subscription.user_id, {
      title: 'Subscription Cancelled',
      body: `You have access until ${new Date(subscription.expires_date).toLocaleDateString()}`
    })
  }
}
```

---

#### Expiration Handling

```typescript
// Webhook: EXPIRED

async function handleExpiration(notification: AppleNotification) {
  const { original_transaction_id } = notification.data

  // 1. Mark subscription as expired
  await supabaseClient
    .from('subscriptions')
    .update({
      status: 'expired',
      updated_at: new Date()
    })
    .eq('original_transaction_id', original_transaction_id)

  // 2. Revoke premium features (optional, depends on your app)
  const { data: subscription } = await supabaseClient
    .from('subscriptions')
    .select('user_id')
    .eq('original_transaction_id', original_transaction_id)
    .single()

  // 3. Notify user
  await sendPushNotification(subscription.user_id, {
    title: 'Subscription Expired',
    body: 'Renew to continue accessing premium features'
  })
}
```

---

## 💰 Pattern 3: Refund System

### Refund Detection & Processing

#### Refund Webhook Handler

```typescript
// Webhook: REFUND or REVOKE

async function handleRefund(notification: AppleNotification) {
  const { original_transaction_id, revocation_reason } = notification.data

  // 1. Find the original purchase
  const { data: purchase } = await supabaseClient
    .from('quota_log')
    .select('user_id, change, job_id, metadata')
    .eq('transaction_id', original_transaction_id)
    .eq('reason', 'iap_purchase')
    .single()

  if (!purchase) {
    console.error('Purchase not found for refund:', original_transaction_id)
    return
  }

  // 2. Check if refund already processed (idempotency)
  const { data: existingRefund } = await supabaseClient
    .from('quota_log')
    .select('id')
    .eq('transaction_id', original_transaction_id)
    .eq('reason', 'iap_refund')
    .single()

  if (existingRefund) {
    console.log('Refund already processed')
    return
  }

  // 3. Deduct refunded credits
  const creditsToDeduct = purchase.change  // This is positive from original purchase

  const { data: deductResult } = await supabaseClient.rpc('deduct_credits', {
    p_user_id: purchase.user_id,
    p_amount: creditsToDeduct,
    p_reason: 'iap_refund',
    p_metadata: {
      original_transaction_id,
      refund_reason: revocation_reason,
      refund_date: new Date().toISOString()
    }
  })

  // 4. Handle insufficient credits (user spent more than they had)
  if (!deductResult.success) {
    // Option A: Allow negative balance
    await supabaseClient.rpc('set_credits_force', {
      p_user_id: purchase.user_id,
      p_amount: 0,  // Set to zero
      p_reason: 'iap_refund_forced'
    })

    // Option B: Ban user for fraud
    await supabaseClient
      .from('users')
      .update({ is_banned: true, ban_reason: 'refund_abuse' })
      .eq('id', purchase.user_id)
  }

  // 5. Cancel any ongoing jobs paid for with refunded credits
  if (purchase.metadata?.job_id) {
    await supabaseClient
      .from('video_jobs')
      .update({
        status: 'cancelled',
        error_message: 'Payment refunded'
      })
      .eq('id', purchase.metadata.job_id)
      .eq('status', 'pending')
  }

  // 6. Log refund event
  await supabaseClient.from('refund_log').insert({
    user_id: purchase.user_id,
    transaction_id: original_transaction_id,
    credits_deducted: creditsToDeduct,
    refund_reason: revocation_reason,
    processed_at: new Date()
  })

  // 7. Alert admin about refund
  await sendTelegramAlert({
    level: 'warning',
    title: 'Refund Processed',
    message: `User ${purchase.user_id} refunded ${creditsToDeduct} credits`,
    metadata: {
      user_id: purchase.user_id,
      transaction_id: original_transaction_id,
      reason: revocation_reason
    }
  })

  // 8. Notify user
  await sendPushNotification(purchase.user_id, {
    title: 'Refund Processed',
    body: `${creditsToDeduct} credits have been removed from your account`
  })
}
```

---

### Database Schema for Refund Tracking

```sql
-- ==========================================
-- REFUND LOG
-- ==========================================
CREATE TABLE refund_log (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES users(id) NOT NULL,

    -- Transaction Info
    transaction_id TEXT NOT NULL,
    original_purchase_amount INTEGER NOT NULL,
    credits_deducted INTEGER NOT NULL,

    -- Refund Details
    refund_reason TEXT,  -- From Apple: fraud, customer_support, other

    -- User Impact
    balance_before INTEGER,
    balance_after INTEGER,
    went_negative BOOLEAN DEFAULT false,

    -- Actions Taken
    jobs_cancelled INTEGER DEFAULT 0,
    user_banned BOOLEAN DEFAULT false,

    processed_at TIMESTAMPTZ DEFAULT now(),

    INDEX idx_refund_log_user (user_id, processed_at DESC)
);

-- ==========================================
-- STORED PROCEDURE: Force Set Credits
-- ==========================================
CREATE OR REPLACE FUNCTION set_credits_force(
    p_user_id UUID,
    p_amount INTEGER,
    p_reason TEXT DEFAULT 'admin_adjustment'
) RETURNS JSONB AS $$
DECLARE
    old_balance INTEGER;
BEGIN
    -- Get current balance
    SELECT credits_remaining INTO old_balance
    FROM users WHERE id = p_user_id FOR UPDATE;

    -- Force set to new amount
    UPDATE users
    SET credits_remaining = p_amount
    WHERE id = p_user_id;

    -- Log the change
    INSERT INTO quota_log (
        user_id,
        change,
        reason,
        balance_before,
        balance_after,
        metadata
    ) VALUES (
        p_user_id,
        p_amount - old_balance,
        p_reason,
        old_balance,
        p_amount,
        jsonb_build_object('forced', true)
    );

    RETURN jsonb_build_object(
        'success', true,
        'old_balance', old_balance,
        'new_balance', p_amount
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

### Refund Edge Cases

#### 1. User Spent Refunded Credits

**Scenario:** User purchased 100 credits, used 80, then refunded.

**Options:**

**Option A: Allow Negative Balance**
```sql
-- User ends up with -80 credits
UPDATE users SET credits_remaining = 20 - 100 WHERE id = user_id;
-- Must purchase again to use app
```

**Option B: Zero Out Balance**
```sql
-- User ends up with 0 credits
UPDATE users SET credits_remaining = 0 WHERE id = user_id;
-- Absorb the loss
```

**Option C: Ban User (Fraud Protection)**
```sql
-- Detect refund abuse
SELECT user_id, COUNT(*) as refund_count
FROM refund_log
WHERE user_id = user_id
GROUP BY user_id
HAVING COUNT(*) >= 3;  -- 3+ refunds = likely abuse

-- Ban user
UPDATE users
SET is_banned = true, ban_reason = 'refund_abuse'
WHERE id = user_id;
```

---

#### 2. Subscription Refund

**Scenario:** User had subscription for 3 months, refunded all.

```typescript
async function handleSubscriptionRefund(originalTransactionId: string) {
  // 1. Find all renewals for this subscription
  const { data: renewals } = await supabaseClient
    .from('quota_log')
    .select('user_id, change')
    .eq('metadata->>subscription_id', originalTransactionId)
    .in('reason', ['subscription_initial', 'subscription_renewal'])

  // 2. Calculate total credits to deduct
  const totalCredits = renewals.reduce((sum, r) => sum + r.change, 0)

  // 3. Deduct all subscription credits
  await supabaseClient.rpc('deduct_credits', {
    p_user_id: renewals[0].user_id,
    p_amount: totalCredits,
    p_reason: 'subscription_refund',
    p_metadata: {
      original_transaction_id: originalTransactionId,
      months_refunded: renewals.length
    }
  })

  // 4. Mark subscription as refunded
  await supabaseClient
    .from('subscriptions')
    .update({ status: 'refunded' })
    .eq('original_transaction_id', originalTransactionId)
}
```

---

#### 3. Partial Refund (Rare)

**Scenario:** App Store issues partial refund.

```typescript
// Some regions support partial refunds
async function handlePartialRefund(notification: AppleNotification) {
  const { refund_amount_in_cents, original_purchase_amount_in_cents } = notification.data

  const refundPercentage = refund_amount_in_cents / original_purchase_amount_in_cents

  // Calculate partial credit deduction
  const originalCredits = 100  // From purchase record
  const creditsToDeduct = Math.floor(originalCredits * refundPercentage)

  await supabaseClient.rpc('deduct_credits', {
    p_user_id: userId,
    p_amount: creditsToDeduct,
    p_reason: 'iap_partial_refund',
    p_metadata: {
      refund_percentage: refundPercentage,
      original_credits: originalCredits
    }
  })
}
```

---

## 📋 Complete IAP Implementation Checklist

### Phase 1: Products Database Setup

- [ ] **Create products table**
  - [ ] Schema with product_id, credits, bonus_credits, is_active
  - [ ] Add valid_from/valid_until for promotions
  - [ ] Add product_type field (consumable vs subscription)
  - [ ] Add display_order for UI sorting

- [ ] **Create product history table**
  - [ ] Audit trail for all product changes
  - [ ] Track who changed what and when

- [ ] **Migrate existing products**
  - [ ] Insert hardcoded products into database
  - [ ] Verify all product_ids match App Store

- [ ] **Update purchase flow**
  - [ ] Query products from database (not hardcoded)
  - [ ] Validate promotional period before purchase
  - [ ] Calculate total credits (base + bonus)

- [ ] **Test product management**
  - [ ] Add new product without deployment
  - [ ] Run limited-time promotion
  - [ ] Disable product instantly
  - [ ] Verify A/B test variant tracking

---

### Phase 2: Subscription Implementation

- [ ] **Create subscriptions table**
  - [ ] original_transaction_id (unique, never changes)
  - [ ] latest_transaction_id (updates on renewal)
  - [ ] Status tracking (active/expired/grace_period)
  - [ ] Expiration date tracking

- [ ] **Create subscription_events table**
  - [ ] Log all webhook events
  - [ ] Idempotency tracking
  - [ ] Event processing status

- [ ] **Implement webhook handlers**
  - [ ] INITIAL_BUY - Create subscription + grant credits
  - [ ] DID_RENEW - Grant monthly credits + update expiration
  - [ ] DID_FAIL_TO_RENEW - Enter grace period
  - [ ] DID_RECOVER - Exit grace period + grant credits
  - [ ] DID_CHANGE_RENEWAL_STATUS - Handle cancellation
  - [ ] EXPIRED - Mark subscription as expired

- [ ] **Setup App Store Server Notifications v2**
  - [ ] Configure webhook endpoint in App Store Connect
  - [ ] Validate webhook signatures
  - [ ] Handle all notification types

- [ ] **Test subscription flows**
  - [ ] Initial purchase grants credits
  - [ ] Renewal grants monthly credits
  - [ ] Grace period allows continued access
  - [ ] Cancellation allows access until expiration
  - [ ] Expiration revokes access

---

### Phase 3: Refund System

- [ ] **Create refund_log table**
  - [ ] Track all refund events
  - [ ] Store refund reason from Apple
  - [ ] Record balance before/after
  - [ ] Flag if balance went negative

- [ ] **Implement refund webhook handler**
  - [ ] REFUND or REVOKE event handling
  - [ ] Find original purchase in quota_log
  - [ ] Check idempotency (don't process twice)
  - [ ] Deduct refunded credits

- [ ] **Handle edge cases**
  - [ ] User spent more than refunded → Allow negative or zero out
  - [ ] Subscription refund → Deduct all renewal credits
  - [ ] Refund abuse detection → Auto-ban after 3+ refunds
  - [ ] Cancel pending jobs paid with refunded credits

- [ ] **Create stored procedures**
  - [ ] set_credits_force() - Admin override for negative balances
  - [ ] detect_refund_abuse() - Flag suspicious users

- [ ] **Setup monitoring**
  - [ ] Telegram alert on every refund
  - [ ] Track refund rate (should be <5%)
  - [ ] Monitor users with negative balance

---

### Phase 4: Testing & Validation

- [ ] **Sandbox Testing**
  - [ ] Test consumable purchase with database products
  - [ ] Test subscription purchase + renewal
  - [ ] Test subscription cancellation
  - [ ] Test refund processing
  - [ ] Test promotional products
  - [ ] Test expired promotional products

- [ ] **Production Validation**
  - [ ] Monitor first real purchase
  - [ ] Monitor first real subscription
  - [ ] Monitor first real refund
  - [ ] Check credit balances reconcile

- [ ] **Analytics Setup**
  - [ ] Track product conversion rates
  - [ ] Track subscription retention
  - [ ] Track refund rate by product
  - [ ] Track promotional campaign performance

---

## 🔐 Security Checklist

- [ ] All transactions verified with App Store Server API (never trust client)
- [ ] Product amounts looked up from database (never trust client)
- [ ] Webhook signatures validated with HMAC
- [ ] Idempotency checks on all purchases/renewals/refunds
- [ ] Refund abuse detection enabled
- [ ] Admin alerts configured for high-value refunds
- [ ] RLS policies protect products table from client tampering

---

## 📊 Monitoring & Analytics

### Key Metrics to Track

```sql
-- Daily revenue by product
SELECT
  DATE(created_at) as date,
  metadata->>'product_id' as product_id,
  COUNT(*) as purchases,
  SUM(change) as total_credits_sold
FROM quota_log
WHERE reason = 'iap_purchase'
  AND created_at > NOW() - INTERVAL '30 days'
GROUP BY DATE(created_at), metadata->>'product_id'
ORDER BY date DESC, total_credits_sold DESC;

-- Subscription retention
SELECT
  DATE_TRUNC('month', purchase_date) as cohort_month,
  COUNT(*) as subscriptions_started,
  COUNT(*) FILTER (WHERE status = 'active') as still_active,
  ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'active') / COUNT(*), 2) as retention_pct
FROM subscriptions
GROUP BY DATE_TRUNC('month', purchase_date)
ORDER BY cohort_month DESC;

-- Refund rate
SELECT
  DATE(processed_at) as date,
  COUNT(*) as refunds,
  SUM(credits_deducted) as credits_refunded,
  COUNT(*) FILTER (WHERE went_negative) as negative_balances,
  COUNT(*) FILTER (WHERE user_banned) as users_banned
FROM refund_log
WHERE processed_at > NOW() - INTERVAL '30 days'
GROUP BY DATE(processed_at)
ORDER BY date DESC;

-- Promotional campaign performance
SELECT
  p.name,
  p.is_promotional,
  COUNT(*) as purchases,
  SUM(p.credits + p.bonus_credits) as total_credits_sold,
  SUM(p.bonus_credits) as bonus_credits_given
FROM quota_log ql
JOIN products p ON ql.metadata->>'product_id' = p.product_id
WHERE ql.reason = 'iap_purchase'
  AND ql.created_at > NOW() - INTERVAL '7 days'
GROUP BY p.name, p.is_promotional
ORDER BY purchases DESC;
```

---

**This document provides complete patterns for implementing Apple In-App Purchases with database-driven products, subscription handling, and refund processing for the AI agent system.**
