# Backend Credit System Changes

This document details all Supabase Edge Function and RPC integration changes required to migrate from the quota system to the credit system.

---

## Overview

The backend migration involves:
1. **Edge Function Updates**: Replace quota RPC calls with credit RPC calls
2. **Idempotency**: Ensure single `requestId` is used for deduction + refund
3. **Premium Bypass**: Server validates premium status from `subscriptions` table
4. **Refund Logic**: Use `add_credits` on AI processing failure

**Key Principle**: Server-authoritative credit enforcement. The Edge Function deducts credits **before** AI processing and refunds **on failure**.

---

## 1. Edge Function: `process-image`

### 1.1 File Location
**Path**: `supabase/functions/process-image/index.ts`
**Current Size**: 625 lines
**Status**: **UPDATED** (major refactor)

---

### 1.2 Sections to REMOVE

#### Section 1: Old Quota System (Lines ~182-240)
**Current Code**:
```typescript
// OLD: New quota system with consume_quota
const { data, error } = await supabase.rpc('consume_quota', {
  p_user_id: userType === 'authenticated' ? userIdentifier : null,
  p_device_id: userType === 'anonymous' ? userIdentifier : null,
  p_client_request_id: requestId
});

if (error) {
  console.warn('⚠️ [QUOTA] New quota system failed, falling back...');
  useNewSystem = false;
}
```

**Replacement**:
```typescript
// NEW: Credit system with deduct_credits
const { data, error } = await supabase.rpc('deduct_credits', {
  p_user_id: userType === 'authenticated' ? userIdentifier : null,
  p_device_id: userType === 'anonymous' ? userIdentifier : null,
  p_amount: 1,  // Cost of this operation
  p_request_id: requestId,
  p_reason: 'image_processing'
});

if (error) {
  console.error('❌ [CREDIT] Credit deduction failed:', error);
  return new Response(
    JSON.stringify({ success: false, error: 'Credit deduction failed' }),
    { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}
```

---

#### Section 2: Fallback to Old System (Lines ~242-365)
**Current Code**: Entire fallback block with `validate_user_daily_quota`, `consume_credit_with_quota`

**Action**: **DELETE ENTIRELY** - No fallback needed, credit system is primary and only.

---

#### Section 3: Quota Result Check (Lines ~367-386)
**Current Code**:
```typescript
if (!quotaResult.success) {
  console.log(`❌ [QUOTA] Quota check failed: ${quotaResult.error}`);
  return new Response(
    JSON.stringify({
      success: false,
      error: quotaResult.error || 'Daily limit reached...',
      quota_info: { ... }
    }),
    { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}
```

**Replacement**:
```typescript
const creditResult = data;

// Check if idempotent (duplicate request)
if (creditResult?.idempotent === true) {
  console.log('✅ [IDEMPOTENCY] Duplicate request detected — returning cached result');
  return new Response(
    JSON.stringify({
      success: true,
      idempotent: true,
      processed_image_url: creditResult.previous_image_url || null,
      job_id: creditResult.previous_job_id || null,
      credit_info: {
        balance: creditResult.balance,
        is_premium: creditResult.is_premium
      }
    }),
    { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}

// Check if credit deduction succeeded
if (!creditResult.success) {
  console.log(`❌ [CREDIT] Insufficient credits: ${creditResult.error}`);
  return new Response(
    JSON.stringify({
      success: false,
      error: creditResult.error || 'Insufficient credits. Please purchase more.',
      credit_info: {
        balance: creditResult.balance || 0,
        is_premium: creditResult.is_premium || false
      }
    }),
    { status: 402, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }  // 402 Payment Required
  );
}

console.log(`✅ [CREDIT] Credit deducted successfully. Balance: ${creditResult.balance}`);
```

---

#### Section 4: Refund Logic (Lines ~451-469)
**Current Code**:
```typescript
catch (falError) {
  console.error('❌ [REFUND] Fal.AI processing failed, initiating quota refund:', falError);

  const { error: refundError } = await supabase.rpc('refund_quota', {
    p_user_id: userType === 'authenticated' ? userIdentifier : null,
    p_device_id: userType === 'anonymous' ? userIdentifier : null,
    p_client_request_id: requestId
  });

  if (refundError) {
    console.error('⚠️ [REFUND] Quota refund failed:', refundError);
  } else {
    console.log('💰 [REFUND] Quota refunded successfully');
  }

  throw falError;
}
```

**Replacement**:
```typescript
catch (falError) {
  console.error('❌ [REFUND] Fal.AI processing failed, initiating credit refund:', falError);

  // Refund credit using add_credits with idempotency key
  const { error: refundError } = await supabase.rpc('add_credits', {
    p_user_id: userType === 'authenticated' ? userIdentifier : null,
    p_device_id: userType === 'anonymous' ? userIdentifier : null,
    p_amount: 1,  // Refund 1 credit
    p_reason: 'processing_failed',
    p_idempotency_key: `refund-${requestId}`  // Prevent duplicate refunds
  });

  if (refundError) {
    console.error('⚠️ [REFUND] Credit refund failed:', refundError);
    // Still throw original error, but log refund failure for manual resolution
  } else {
    console.log('💰 [REFUND] Credit refunded successfully');
  }

  throw falError;
}
```

---

### 1.3 Response Payload Updates

#### Success Response (Line ~592-603)
**Current Code**:
```typescript
const response: ProcessImageResponse = {
  success: true,
  processed_image_url: urlData.signedUrl,
  job_id: jobId,
  quota_info: {
    credits: quotaResult.credits || 0,
    quota_used: quotaResult.quota_used,
    quota_limit: quotaResult.quota_limit,
    quota_remaining: quotaResult.quota_remaining,
    is_premium: isPremium
  }
};
```

**Replacement**:
```typescript
const response: ProcessImageResponse = {
  success: true,
  processed_image_url: urlData.signedUrl,
  job_id: jobId,
  credit_info: {
    balance: creditResult.balance,
    is_premium: creditResult.is_premium || false
  }
};
```

---

### 1.4 TypeScript Interface Updates

**Current Interface** (Line ~8-29):
```typescript
interface ProcessImageResponse {
  success: boolean;
  processed_image_url?: string;
  job_id?: string;
  error?: string;
  quota_info?: {
    credits: number;
    quota_used: number;
    quota_limit: number;
    quota_remaining: number;
    is_premium: boolean;
  };
}
```

**New Interface**:
```typescript
interface ProcessImageResponse {
  success: boolean;
  processed_image_url?: string;
  job_id?: string;
  error?: string;
  credit_info?: {
    balance: number;
    is_premium: boolean;
  };
  idempotent?: boolean;  // For duplicate request detection
}
```

---

## 2. Idempotency Implementation

### 2.1 Request ID Generation (Line ~54-56)

**Current Code**:
```typescript
const requestId = client_request_id || crypto.randomUUID();
console.log('🔑 [STEVE-JOBS] Request ID:', requestId);
```

**Keep As-Is** ✅ - This is correct. Single requestId is generated once and reused.

---

### 2.2 Request ID Reuse

**Deduct Credits** (Line ~195-200):
```typescript
const { data, error } = await supabase.rpc('deduct_credits', {
  p_user_id: userType === 'authenticated' ? userIdentifier : null,
  p_device_id: userType === 'anonymous' ? userIdentifier : null,
  p_amount: 1,
  p_request_id: requestId,  // ✅ Use same requestId
  p_reason: 'image_processing'
});
```

**Refund Credits** (Line ~456-460):
```typescript
const { error: refundError } = await supabase.rpc('add_credits', {
  p_user_id: userType === 'authenticated' ? userIdentifier : null,
  p_device_id: userType === 'anonymous' ? userIdentifier : null,
  p_amount: 1,
  p_reason: 'processing_failed',
  p_idempotency_key: `refund-${requestId}`  // ✅ Different key for refund
});
```

**Why Different Keys?**
- Deduction uses `requestId` directly (e.g., `abc-123`)
- Refund uses `refund-${requestId}` (e.g., `refund-abc-123`)
- This allows:
  - Duplicate deduction requests → return cached result (idempotent)
  - Duplicate refund requests → return cached result (idempotent)
  - Deduction + refund for same request → both succeed independently

---

### 2.3 Idempotency Flow

**Scenario 1**: Duplicate Request (Network Retry)
```
1. Client sends requestId: "abc-123"
2. Edge Function calls deduct_credits(requestId: "abc-123")
3. Database deducts credit, logs transaction with idempotency_key: "abc-123"
4. Client retries (network timeout), sends same requestId: "abc-123"
5. Edge Function calls deduct_credits(requestId: "abc-123") again
6. Database finds existing transaction with "abc-123"
7. Returns cached result: { success: true, idempotent: true, balance: X }
8. Edge Function returns cached image URL (if available) or processes again
```

**Scenario 2**: Processing Failure + Refund
```
1. Edge Function deducts credit with requestId: "abc-123"
2. Fal.AI fails (timeout, error, etc.)
3. Edge Function calls add_credits(idempotency_key: "refund-abc-123")
4. Database adds 1 credit, logs transaction with "refund-abc-123"
5. Client retries entire request with same requestId: "abc-123"
6. Edge Function deducts credit again → finds cached deduction (idempotent)
7. BUT refund was already applied, so balance is correct
```

---

## 3. Premium Bypass Logic

### 3.1 Server-Side Premium Detection

**Current Implementation** (Line ~211-216):
```typescript
// ✅ FIX: Extract is_premium from server response
if (quotaResult?.is_premium !== undefined) {
  isPremium = quotaResult.is_premium;
  console.log('🔍 [QUOTA] Server premium status:', isPremium);
  if (isPremium) {
    console.log('💎 [QUOTA] Premium user detected — bypassing quota');
  }
}
```

**Keep As-Is** ✅ - Backend `deduct_credits` function checks `subscriptions` table and returns `is_premium: true` if active subscription found.

**Premium Bypass Flow**:
1. Edge Function calls `deduct_credits(requestId)`
2. Database function checks `subscriptions` table:
   ```sql
   SELECT EXISTS(
     SELECT 1 FROM subscriptions
     WHERE (user_id = p_user_id OR device_id = p_device_id)
     AND status = 'active'
     AND expires_at > NOW()
   ) INTO v_is_premium;
   ```
3. If premium: Return `{ success: true, premium_bypass: true, balance: 999999 }`
4. If not premium: Deduct credit normally

**Client Never Decides Premium Status** - Server is source of truth via `subscriptions` table.

---

## 4. Error Handling

### 4.1 HTTP Status Codes

| Scenario | Status Code | Response |
|----------|-------------|----------|
| Success | 200 | `{ success: true, processed_image_url, credit_info }` |
| Insufficient Credits | 402 | `{ success: false, error: "Insufficient credits", credit_info }` |
| Server Error | 500 | `{ success: false, error: "Internal error" }` |
| Authentication Failed | 401 | `{ success: false, error: "Auth required" }` |
| Idempotent Request | 200 | `{ success: true, idempotent: true, processed_image_url }` |

---

### 4.2 Error Response Format

**Insufficient Credits**:
```json
{
  "success": false,
  "error": "Insufficient credits. Please purchase more or upgrade to Premium.",
  "credit_info": {
    "balance": 0,
    "is_premium": false
  }
}
```

**Processing Failed (After Refund)**:
```json
{
  "success": false,
  "error": "AI processing failed: timeout",
  "refund_applied": true,
  "credit_info": {
    "balance": 5,
    "is_premium": false
  }
}
```

---

## 5. RPC Call Reference

### 5.1 `deduct_credits`

**Purpose**: Atomic credit deduction with idempotency and premium bypass.

**Parameters**:
```typescript
{
  p_user_id: UUID | null,           // Authenticated user ID
  p_device_id: string | null,       // Anonymous device ID
  p_amount: number,                 // Credits to deduct (usually 1)
  p_request_id: string,             // Idempotency key
  p_reason: string                  // 'image_processing', 'manual_deduction', etc.
}
```

**Returns**:
```typescript
{
  success: boolean,
  balance: number,                  // Balance after deduction
  premium_bypass?: boolean,         // true if premium user
  idempotent?: boolean,             // true if duplicate request
  error?: string                    // Error message if success = false
}
```

**Usage in Edge Function**:
```typescript
const { data: creditResult, error } = await supabase.rpc('deduct_credits', {
  p_user_id: userType === 'authenticated' ? userIdentifier : null,
  p_device_id: userType === 'anonymous' ? userIdentifier : null,
  p_amount: 1,
  p_request_id: requestId,
  p_reason: 'image_processing'
});
```

---

### 5.2 `add_credits`

**Purpose**: Add credits (purchase, refund, admin grant) with idempotency.

**Parameters**:
```typescript
{
  p_user_id: UUID | null,
  p_device_id: string | null,
  p_amount: number,                 // Credits to add (positive)
  p_reason: string,                 // 'purchase', 'refund', 'processing_failed', etc.
  p_idempotency_key: string         // Prevents duplicate adds
}
```

**Returns**:
```typescript
{
  success: boolean,
  balance: number,                  // Balance after addition
  idempotent?: boolean,
  error?: string
}
```

**Usage in Edge Function** (Refund):
```typescript
const { error: refundError } = await supabase.rpc('add_credits', {
  p_user_id: userType === 'authenticated' ? userIdentifier : null,
  p_device_id: userType === 'anonymous' ? userIdentifier : null,
  p_amount: 1,
  p_reason: 'processing_failed',
  p_idempotency_key: `refund-${requestId}`
});
```

---

### 5.3 `get_credits`

**Purpose**: Fetch current credit balance (used by iOS app, not Edge Function).

**Parameters**:
```typescript
{
  p_user_id: UUID | null,
  p_device_id: string | null
}
```

**Returns**:
```typescript
{
  balance: number,
  lifetime_purchased: number,
  lifetime_spent: number
}
```

**Not Used in Edge Function** - Only used by iOS `CreditService.getCredits()`.

---

## 6. Deployment Steps

### 6.1 Pre-Deployment
1. Ensure database migration `052_create_credit_system.sql` is deployed
2. Test RPC functions directly via Supabase Dashboard SQL Editor:
   ```sql
   SELECT deduct_credits(
     p_user_id := 'test-user-id'::uuid,
     p_device_id := null,
     p_amount := 1,
     p_request_id := 'test-request-123',
     p_reason := 'test'
   );
   ```

---

### 6.2 Deployment
```bash
# Deploy updated Edge Function
supabase functions deploy process-image

# Verify deployment
curl -X POST https://your-project.supabase.co/functions/v1/process-image \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"image_url":"...","prompt":"...","device_id":"test-device"}'
```

---

### 6.3 Post-Deployment Monitoring

**Metrics to Watch**:
- Error rate for `deduct_credits` RPC calls
- Refund rate (should be < 5% if AI is stable)
- Idempotent request rate (indicates retries)
- Premium bypass rate (should match subscription count)

**Logs to Monitor**:
- `❌ [CREDIT] Credit deduction failed` → Investigate RLS or balance issues
- `⚠️ [REFUND] Credit refund failed` → Manual refund may be needed
- `✅ [IDEMPOTENCY] Duplicate request detected` → Normal, no action needed

---

## 7. Testing Checklist

### Unit Tests (Edge Function)
- [ ] Deduct credits before AI processing
- [ ] Refund credits on AI failure
- [ ] Idempotency: Same requestId returns cached result
- [ ] Premium bypass: Active subscription skips credit check
- [ ] Insufficient credits: Returns 402 status

### Integration Tests
- [ ] End-to-end image processing with credit deduction
- [ ] Simulate AI failure → verify refund applied
- [ ] Simulate network retry → verify no double-charge
- [ ] Test with anonymous user (device_id)
- [ ] Test with authenticated user (user_id)
- [ ] Test with premium user (unlimited credits)

---

## 8. Rollback Plan

If Edge Function update causes critical issues:

1. **Revert Edge Function**:
   ```bash
   git revert <commit-hash>
   supabase functions deploy process-image
   ```

2. **Restore Old Quota Tables** (if dropped prematurely):
   ```sql
   -- Restore from backup
   pg_restore -d postgres -t daily_quotas backup.sql
   ```

3. **Notify iOS Team**: Old quota system must be temporarily re-enabled in iOS app (or force users to update).

---

## 9. File Cleanup (Phase 7)

### Edge Function
- **No files to delete** - Only `index.ts` is updated in place

### Database
- Drop old quota functions (see `DATABASE_CREDIT_CHANGES.md`)

---

## Next Steps

1. Review this document with backend team
2. Deploy database migration first (`052_create_credit_system.sql`)
3. Update `process-image/index.ts` per specifications above
4. Deploy Edge Function to staging
5. Test thoroughly with curl/Postman
6. Deploy to production during low-traffic window
7. Monitor logs and error rates for 24-48 hours
