# Backend Architecture: Credit System

**Part 5 of 6** - Credit management, stored procedures, transactions, and purchase flow

**Related Documents:**
- [backend-INDEX.md](./backend-INDEX.md) - Complete documentation index
- [backend-1-overview-database.md](./backend-1-overview-database.md) - Database schema
- [backend-4-auth-security.md](./backend-4-auth-security.md) - IAP verification

---

## 💰 Credit Management Overview

### Credit Operations

1. **Deduct Credits** - For video generation
2. **Add Credits** - For IAP purchases, refunds, initial grants
3. **Query Balance** - Get current credit balance
4. **Transaction History** - View credit transaction log

### Atomic Operations

All credit operations use **stored procedures** to prevent race conditions:
- Row-level locking (`FOR UPDATE`)
- Transaction logging
- Balance tracking

---

## 🔧 Stored Procedures

### Deduct Credits

**Purpose:** Atomically deduct credits with balance check

File: `supabase/migrations/002_create_stored_procedures.sql`

```sql
-- ==========================================
-- STORED PROCEDURE: Deduct Credits Atomically
-- ==========================================
CREATE OR REPLACE FUNCTION deduct_credits(
    p_user_id UUID,
    p_amount INTEGER,
    p_reason TEXT DEFAULT 'video_generation'
) RETURNS JSONB AS $$
DECLARE
    current_credits INTEGER;
    new_balance INTEGER;
BEGIN
    -- Lock row to prevent race conditions
    SELECT credits_remaining INTO current_credits
    FROM users
    WHERE id = p_user_id
    FOR UPDATE;
    
    IF current_credits IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'User not found'
        );
    END IF;
    
    IF current_credits < p_amount THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Insufficient credits',
            'current_credits', current_credits,
            'required_credits', p_amount
        );
    END IF;
    
    -- Deduct credits
    UPDATE users
    SET credits_remaining = credits_remaining - p_amount,
        updated_at = now()
    WHERE id = p_user_id
    RETURNING credits_remaining INTO new_balance;
    
    -- Log transaction
    INSERT INTO quota_log (user_id, change, reason, balance_after)
    VALUES (p_user_id, -p_amount, p_reason, new_balance);
    
    RETURN jsonb_build_object(
        'success', true,
        'credits_remaining', new_balance
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

**Usage:**

```typescript
const { data: result } = await supabaseClient.rpc('deduct_credits', {
  p_user_id: user_id,
  p_amount: 4,
  p_reason: 'video_generation'
})

if (!result.success) {
  // Handle error (insufficient credits, user not found, etc.)
  return new Response(
    JSON.stringify({ error: result.error }),
    { status: 402 }
  )
}

// Success - credits deducted
const newBalance = result.credits_remaining
```

### Add Credits

**Purpose:** Atomically add credits with duplicate transaction prevention

```sql
-- ==========================================
-- STORED PROCEDURE: Add Credits Atomically
-- ==========================================
CREATE OR REPLACE FUNCTION add_credits(
    p_user_id UUID,
    p_amount INTEGER,
    p_reason TEXT,
    p_transaction_id TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    new_balance INTEGER;
    existing_transaction BOOLEAN;
BEGIN
    -- Check for duplicate transaction
    IF p_transaction_id IS NOT NULL THEN
        SELECT EXISTS(
            SELECT 1 FROM quota_log 
            WHERE transaction_id = p_transaction_id
        ) INTO existing_transaction;
        
        IF existing_transaction THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Transaction already processed'
            );
        END IF;
    END IF;
    
    -- Add credits
    UPDATE users
    SET credits_remaining = credits_remaining + p_amount,
        credits_total = credits_total + p_amount,
        updated_at = now()
    WHERE id = p_user_id
    RETURNING credits_remaining INTO new_balance;
    
    -- Log transaction
    INSERT INTO quota_log (
        user_id, 
        change, 
        reason, 
        balance_after,
        transaction_id
    ) VALUES (
        p_user_id, 
        p_amount, 
        p_reason, 
        new_balance,
        p_transaction_id
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'credits_added', p_amount,
        'credits_remaining', new_balance
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

**Usage:**

```typescript
const { data: result } = await supabaseClient.rpc('add_credits', {
  p_user_id: user_id,
  p_amount: 10,
  p_reason: 'iap_purchase',
  p_transaction_id: transactionId // Prevents duplicates
})

if (!result.success) {
  // Handle error (duplicate transaction, user not found, etc.)
  return new Response(
    JSON.stringify({ error: result.error }),
    { status: 400 }
  )
}

// Success - credits added
const newBalance = result.credits_remaining
```

---

## 📊 Quota Log (Transaction History)

### Table Structure

See [backend-1-overview-database.md](./backend-1-overview-database.md) for complete schema.

**Key Fields:**
- `change`: Credit change amount (+ or -)
- `reason`: Reason for change
- `transaction_id`: Unique ID for IAP purchases
- `balance_after`: Balance after transaction (audit trail)

### Transaction Reasons

- `initial_grant` - First-time user gets 10 credits
- `video_generation` - Credits deducted for generation
- `iap_purchase` - Credits added from IAP
- `generation_failed_refund` - Credits refunded on failure
- `admin_refund` - Manual refund by admin

### Querying Transaction History

```typescript
const { data: transactions } = await supabaseClient
  .from('quota_log')
  .select('*')
  .eq('user_id', user_id)
  .order('created_at', { ascending: false })
  .limit(20)
```

---

## 🛒 Purchase Flow (IAP)

### Complete Flow

1. **User taps "Buy Credits"** in iOS app
2. **iOS requests purchase** from Apple StoreKit
3. **Apple processes payment**
4. **iOS receives transaction_id**
5. **iOS sends to `/update-credits`** endpoint
6. **Backend verifies with Apple** (see [backend-4-auth-security.md](./backend-4-auth-security.md))
7. **Backend checks for duplicate** transaction
8. **Backend adds credits** using stored procedure
9. **Backend logs transaction**
10. **iOS receives new balance**

### Update Credits Endpoint

File: `supabase/functions/update-credits/index.ts`

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { verifyAppleTransaction } from '../_shared/apple-iap.ts'

serve(async (req) => {
  try {
    const { user_id, transaction_id } = await req.json()
    
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )
    
    // 1. Verify transaction with Apple's App Store Server API
    const verification = await verifyAppleTransaction(transaction_id)
    
    if (!verification.valid) {
      return new Response(
        JSON.stringify({ error: 'Invalid transaction' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }
    
    // 2. Get product configuration (NEVER trust client)
    const productConfig: Record<string, number> = {
      'com.rendio.credits.10': 10,
      'com.rendio.credits.50': 50,
      'com.rendio.credits.100': 100
    }
    
    const creditsToAdd = productConfig[verification.product_id]
    
    if (!creditsToAdd) {
      return new Response(
        JSON.stringify({ error: 'Unknown product' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }
    
    // 3. Add credits atomically (handles duplicate check)
    const { data: result } = await supabaseClient.rpc('add_credits', {
      p_user_id: user_id,
      p_amount: creditsToAdd,
      p_reason: 'iap_purchase',
      p_transaction_id: transaction_id
    })
    
    if (!result.success) {
      return new Response(
        JSON.stringify({ error: result.error }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }
    
    return new Response(
      JSON.stringify({
        success: true,
        credits_added: creditsToAdd,
        credits_remaining: result.credits_remaining
      }),
      { headers: { 'Content-Type': 'application/json' } }
    )
    
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
```

### Product Configuration

**Never trust client-sent credit amounts!** Always look up in server configuration:

```typescript
const productConfig: Record<string, number> = {
  'com.rendio.credits.10': 10,
  'com.rendio.credits.50': 50,
  'com.rendio.credits.100': 100
}
```

---

## 🔄 Atomic Operations

### Why Atomic Operations?

**Problem:** Race conditions can occur when:
- User generates multiple videos simultaneously
- Multiple devices try to purchase credits
- Network retries cause duplicate requests

**Solution:** Stored procedures with row-level locking

### How It Works

1. **Lock row** with `FOR UPDATE`
2. **Check balance** (while locked)
3. **Update balance** (while locked)
4. **Log transaction** (while locked)
5. **Release lock** (commit transaction)

### Example: Concurrent Video Generations

**Without atomic operations:**
```
User has 5 credits
Request 1: Check balance (5) → Deduct 4 → Balance: 1 ✅
Request 2: Check balance (5) → Deduct 4 → Balance: 1 ❌ (should be -3)
```

**With atomic operations:**
```
User has 5 credits
Request 1: Lock → Check (5) → Deduct 4 → Balance: 1 ✅
Request 2: Wait for lock → Check (1) → Insufficient credits ❌
```

---

## 💸 Credit Refunds

### When Credits Are Refunded

1. **Video generation fails** - Refund credits used
2. **Provider timeout** - Refund credits used
3. **Admin refund** - Manual refund by support team

### Refund Implementation

```typescript
// Refund credits on generation failure
await supabaseClient.rpc('add_credits', {
  p_user_id: user_id,
  p_amount: creditsUsed,
  p_reason: 'generation_failed_refund'
})
```

**See:** [backend-3-generation-workflow.md](./backend-3-generation-workflow.md) for rollback logic.

---

## 📈 Credit Tracking

### Balance Fields

- `credits_remaining`: Current available credits
- `credits_total`: Lifetime credits earned (never decreases)

### Initial Grant

New users get 10 credits on first device check:

```typescript
// In device-check endpoint
await supabaseClient.rpc('add_credits', {
  p_user_id: newUser.id,
  p_amount: 10,
  p_reason: 'initial_grant'
})
```

**Note:** DeviceCheck prevents duplicate initial grants. See [backend-4-auth-security.md](./backend-4-auth-security.md).

---

## 🔍 Querying Credit Balance

### Get Current Balance

```typescript
const { data: user } = await supabaseClient
  .from('users')
  .select('credits_remaining')
  .eq('id', user_id)
  .single()

const balance = user.credits_remaining
```

### Get Transaction History

```typescript
const { data: transactions } = await supabaseClient
  .from('quota_log')
  .select('*')
  .eq('user_id', user_id)
  .order('created_at', { ascending: false })
  .limit(20)
```

---

## ⚠️ Error Handling

### Insufficient Credits

```typescript
const { data: result } = await supabaseClient.rpc('deduct_credits', {
  p_user_id: user_id,
  p_amount: 4,
  p_reason: 'video_generation'
})

if (!result.success) {
  if (result.error === 'Insufficient credits') {
    return new Response(
      JSON.stringify({
        error: 'Insufficient credits',
        credits_remaining: result.current_credits,
        required_credits: result.required_credits
      }),
      { status: 402 }
    )
  }
}
```

### Duplicate Transaction

```typescript
const { data: result } = await supabaseClient.rpc('add_credits', {
  p_user_id: user_id,
  p_amount: 10,
  p_reason: 'iap_purchase',
  p_transaction_id: transactionId
})

if (!result.success) {
  if (result.error === 'Transaction already processed') {
    // Return success with current balance (idempotent)
    return new Response(
      JSON.stringify({
        success: true,
        credits_remaining: currentBalance,
        message: 'Transaction already processed'
      }),
      { status: 200 }
    )
  }
}
```

---

## 🚀 Next Steps

1. **Implement IAP verification** - See [backend-4-auth-security.md](./backend-4-auth-security.md)
2. **Add admin refund endpoint** - See [backend-6-operations-testing.md](./backend-6-operations-testing.md)
3. **Monitor credit transactions** - Track refunds, purchases, usage

---

**Related Documentation:**
- [backend-INDEX.md](./backend-INDEX.md) - Complete documentation index
- [backend-1-overview-database.md](./backend-1-overview-database.md) - Database schema
- [backend-3-generation-workflow.md](./backend-3-generation-workflow.md) - Credit deduction in generation
- [backend-4-auth-security.md](./backend-4-auth-security.md) - IAP verification

