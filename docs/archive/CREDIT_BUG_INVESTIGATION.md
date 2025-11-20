# Credit Deduction Bug Investigation

## Problem Description
- User starts with **10 credits** ✅
- User clicks generate button
- Credits **drop by 3** (should drop by 1) ❌
- App shows **"no credit"** error even though user should have 7 credits left ❌

## Expected Behavior
- Clicking generate should deduct **1 credit** (from 10 → 9)
- User should be able to continue with 9 credits remaining

## Current Flow Analysis

### 1. Frontend Check (Before Generation)
**Location**: `ChatView.swift:137` and `ChatViewModel.swift:174`
```swift
if !creditManager.canProcessImage() {
    showingPaywall = true
    return
}
```
- Checks if `creditsRemaining > 0`
- This happens **BEFORE** the API call

### 2. Backend Credit Deduction
**Location**: `supabase/functions/submit-job/index.ts:316`
```typescript
const { data, error } = await supabase.rpc('consume_credits', {
    p_user_id: userType === 'authenticated' ? userIdentifier : null,
    p_device_id: userType === 'anonymous' ? userIdentifier : null,
    p_amount: 1,  // ✅ Should deduct 1 credit
    p_idempotency_key: requestId
});
```
- Calls `consume_credits` with `p_amount: 1` ✅
- Uses idempotency key to prevent duplicate charges

### 3. Frontend Credit Update
**Location**: `ChatViewModel.swift:276-279`
```swift
if let creditInfo = submitResponse.creditInfo {
    await creditManager.updateFromBackendResponse(
        creditsRemaining: creditInfo.creditsRemaining
    )
}
```
- Updates credits from backend response
- Should reflect the new balance after deduction

## Possible Root Causes

### 🔴 Hypothesis 1: Multiple API Calls
**Issue**: Button might be clicked multiple times, causing multiple API calls
**Evidence Needed**: Check if idempotency is working correctly
**Check**: Look for duplicate `submit-job` calls in logs

### 🔴 Hypothesis 2: Wrong Amount in Database Function
**Issue**: `consume_credits` function might be deducting wrong amount
**Evidence Needed**: Check actual SQL function implementation
**Check**: Verify `p_amount` parameter is used correctly in `consume_credits`

### 🔴 Hypothesis 3: Frontend Double Deduction
**Issue**: Frontend might be deducting credits in addition to backend
**Evidence Needed**: Check if there's any frontend credit subtraction
**Check**: Search for `creditsRemaining -=` or similar operations

### 🔴 Hypothesis 4: Credit Check Timing Issue
**Issue**: Credit check might happen AFTER deduction but BEFORE UI update
**Evidence Needed**: Check the exact timing of credit checks
**Check**: Verify when `canProcessImage()` is called vs when credits are updated

### 🔴 Hypothesis 5: Race Condition
**Issue**: Multiple concurrent requests might cause race condition
**Evidence Needed**: Check if idempotency key is unique per request
**Check**: Verify `client_request_id` generation

## Debugging Steps

### Step 1: Add Logging
Add detailed logging to track:
1. Credit balance before API call
2. Credit balance after API call
3. Amount being deducted
4. Idempotency key used

### Step 2: Check Database Logs
Query `idempotency_keys` table to see:
- How many times `consume_credits` was called
- What amounts were deducted
- If idempotency is working

### Step 3: Check Edge Function Logs
```bash
supabase functions logs submit-job --limit 100
```
Look for:
- Multiple calls with same idempotency key
- Different amounts being passed
- Error messages

### Step 4: Check Frontend Logs
Add console logs to track:
- When `canProcessImage()` is called
- When credits are updated
- Credit values at each step

## Files to Check

1. **Backend**: `supabase/functions/submit-job/index.ts` (line 316)
2. **Database**: `supabase/migrations/066_remove_premium_checks_from_credit_functions.sql` (consume_credits function)
3. **Frontend**: `BananaUniverse/Features/Chat/ViewModels/ChatViewModel.swift` (line 276)
4. **Frontend**: `BananaUniverse/Core/Services/CreditManager.swift` (updateCredits method)

## Next Steps

1. ✅ Document the problem
2. ⏳ Add logging to track credit flow
3. ⏳ Check database for actual credit values
4. ⏳ Verify idempotency is working
5. ⏳ Test with single click vs multiple clicks

