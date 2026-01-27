# 🔍 Status Code Mismatch Analysis: 402 vs 429

**Date:** 2025-01-27  
**Issue:** Backend returns `402` (Payment Required) but iOS checks for `429` (Too Many Requests)  
**Impact:** ⚠️ **HIGH** - Prevents correct error handling on client

---

## 📋 Executive Summary

**Current State:**
- ✅ Backend correctly returns `402` for insufficient credits
- ❌ iOS client checks for `429` instead of `402`
- ⚠️ **Result:** Error handling fails, user sees generic error instead of credit purchase prompt

**Recommendation:** ✅ **Update iOS client to handle `402`** (backend is correct)

**Priority:** 🔴 **HIGH** - Affects user experience and monetization

---

## 1. Semantic Differences: 402 vs 429

### 1.1 HTTP 402 Payment Required

**RFC 7231 Definition:**
> "The 402 (Payment Required) status code is reserved for future use."

**Common Usage (Industry Practice):**
- Used for **payment/balance-related** errors
- Indicates user needs to **purchase credits/subscription**
- Not officially standardized, but widely adopted for credit systems

**Semantic Meaning:**
- ✅ **User action required:** Purchase credits or upgrade subscription
- ✅ **Resolvable:** User can fix by adding credits
- ✅ **Business logic:** Related to account balance, not rate limiting

**Examples in Industry:**
- Stripe API: Returns 402 for insufficient balance
- AWS: Uses 402 for payment required
- Credit-based APIs: Standard practice for insufficient credits

---

### 1.2 HTTP 429 Too Many Requests

**RFC 6585 Definition:**
> "The 429 status code indicates that the user has sent too many requests in a given amount of time ("rate limiting")."

**Standardized Usage:**
- Used for **rate limiting** errors
- Indicates **temporal restriction** (try again later)
- Includes `Retry-After` header typically

**Semantic Meaning:**
- ✅ **Time-based:** Wait and retry later
- ✅ **Rate limit:** Too many requests per time period
- ✅ **System protection:** Prevents abuse/overload

**Examples:**
- API rate limits (100 requests/hour)
- Daily quota limits (5 requests/day)
- DDoS protection

---

### 1.3 Key Differences

| Aspect | 402 Payment Required | 429 Too Many Requests |
|--------|---------------------|----------------------|
| **Cause** | Insufficient balance/credits | Too many requests in time window |
| **Resolution** | Purchase credits/subscription | Wait and retry later |
| **User Action** | Make payment | Wait for reset |
| **Time Dependency** | No (persistent state) | Yes (temporary limit) |
| **Retry Strategy** | Purchase credits first | Wait then retry |
| **Business Model** | Monetization signal | Rate limiting signal |

---

## 2. Current Implementation Analysis

### 2.1 Backend Implementation

**Location:** ```324:324:supabase/functions/submit-job/index.ts```

```typescript
return {
  error: new Response(
    JSON.stringify({
      success: false,
      error: quotaResult.error || 'Insufficient credits. Purchase more credits to continue.',
      quota_info: {
        credits_remaining: quotaResult.credits_remaining || 0,
        is_premium: updatedIsPremium
      }
    }),
    { status: 402, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
};
```

**Analysis:**
- ✅ **Semantically correct:** 402 is appropriate for insufficient credits
- ✅ **Clear error message:** "Insufficient credits. Purchase more credits to continue."
- ✅ **Includes context:** `credits_remaining` and `is_premium` in response
- ✅ **Industry standard:** Matches common practice for credit systems

**Note:** There's also a `429` in `webhook-handler` for rate limiting (line 181), which is **correct** for that use case.

---

### 2.2 iOS Client Implementation

**Location:** ```285:286:BananaUniverse/Core/Services/SupabaseService.swift```

```swift
if httpResponse.statusCode == 429 {
    throw SupabaseError.quotaExceeded
}
```

**Error Mapping:**
```swift
// SupabaseService.swift (line 914)
case .quotaExceeded:
    return "Daily quota exceeded. Come back tomorrow or upgrade for unlimited access."
```

**AppError Mapping:**
```swift
// AppError.swift (line 84)
case .dailyQuotaExceeded:
    return "You've reached your daily limit. Come back tomorrow or upgrade for unlimited access."
```

**Analysis:**
- ❌ **Wrong status code:** Checks for 429 instead of 402
- ❌ **Wrong error message:** Says "daily limit" instead of "insufficient credits"
- ❌ **Wrong UX:** Suggests "come back tomorrow" instead of "purchase credits"
- ⚠️ **Impact:** User sees incorrect error message and no purchase prompt

---

### 2.3 Error Flow (Current - Broken)

```
User has 0 credits
    ↓
Submit job → Backend returns 402
    ↓
iOS checks for 429 → NOT FOUND
    ↓
Falls through to generic error handler
    ↓
User sees: "Something went wrong" (generic error)
    ↓
❌ NO purchase prompt shown
❌ User doesn't know they need credits
```

---

## 3. Impact Analysis

### 3.1 User Experience Impact

**Current (Broken) Flow:**
1. User runs out of credits
2. Backend returns 402 with clear message
3. iOS doesn't recognize 402
4. User sees generic error: "Something went wrong"
5. ❌ **No purchase prompt**
6. ❌ **User confused** - doesn't know why it failed
7. ❌ **Lost revenue opportunity**

**Expected (Fixed) Flow:**
1. User runs out of credits
2. Backend returns 402 with clear message
3. iOS recognizes 402
4. User sees: "You're out of credits! Tap here to get more"
5. ✅ **Purchase prompt shown**
6. ✅ **Clear call-to-action**
7. ✅ **Revenue opportunity captured**

---

### 3.2 Functionality Impact

**What Works:**
- ✅ Backend correctly identifies insufficient credits
- ✅ Backend returns appropriate status code (402)
- ✅ Backend includes helpful error message

**What's Broken:**
- ❌ iOS doesn't handle 402 status code
- ❌ Error message doesn't match actual problem
- ❌ No purchase flow triggered
- ❌ User can't resolve the issue

**Business Impact:**
- 💰 **Lost revenue:** Users can't purchase credits when needed
- 😞 **Poor UX:** Confusing error messages
- 📉 **Lower conversion:** No clear path to resolution

---

### 3.3 Edge Cases

**Case 1: User with 0 credits**
- **Current:** Generic error (broken)
- **Expected:** "Insufficient credits" with purchase prompt
- **Impact:** 🔴 **HIGH** - Primary use case

**Case 2: User with 1 credit (about to run out)**
- **Current:** Works (credit consumed successfully)
- **Expected:** Same
- **Impact:** ✅ **NONE**

**Case 3: Rate limiting (webhook-handler)**
- **Current:** Returns 429 (correct)
- **Expected:** Same
- **Impact:** ✅ **NONE** - Different endpoint

**Case 4: Premium user (unlimited credits)**
- **Current:** Never hits 402 (bypasses credit check)
- **Expected:** Same
- **Impact:** ✅ **NONE**

---

## 4. Recommendation: Update iOS Client

### 4.1 Why Update iOS (Not Backend)

**✅ Backend is Correct:**
- 402 is semantically appropriate for insufficient credits
- Matches industry standards (Stripe, AWS, etc.)
- Clear separation from rate limiting (429)

**✅ Better API Design:**
- Different status codes for different problems
- Allows client to handle each case appropriately
- Future-proof (can add rate limiting later with 429)

**✅ Industry Best Practices:**
- Credit systems use 402 for payment required
- Rate limiting uses 429 for too many requests
- Clear semantic distinction

**✅ Future-Proof:**
- If you add rate limiting later, you can use 429
- 402 remains for credit/payment issues
- Clear separation of concerns

---

### 4.2 Why NOT Change Backend to 429

**❌ Semantically Wrong:**
- 429 means "too many requests" not "insufficient credits"
- Violates HTTP specification
- Confuses rate limiting with payment issues

**❌ Industry Mismatch:**
- Most credit systems use 402
- Would be non-standard
- Harder for developers to understand

**❌ Future Problems:**
- If you add actual rate limiting, what status code would you use?
- Would need to use 402 for both credits AND rate limits (confusing)
- Or use 429 for both (also confusing)

---

## 5. Implementation Plan

### 5.1 Required Changes

#### Change 1: Update Status Code Check

**File:** `BananaUniverse/Core/Services/SupabaseService.swift`

**Current (Line 285):**
```swift
if httpResponse.statusCode == 429 {
    throw SupabaseError.quotaExceeded
}
```

**Updated:**
```swift
if httpResponse.statusCode == 402 {
    throw SupabaseError.insufficientCredits
}
```

**Also Update (Line 451):**
```swift
// Change from:
} else if httpResponse.statusCode == 429 {
// To:
} else if httpResponse.statusCode == 402 {
```

---

#### Change 2: Update Error Message

**File:** `BananaUniverse/Core/Services/SupabaseService.swift`

**Current (Line 914):**
```swift
case .quotaExceeded:
    return "Daily quota exceeded. Come back tomorrow or upgrade for unlimited access."
```

**Updated:**
```swift
case .insufficientCredits:
    return "You don't have enough credits. Purchase more credits to continue!"
```

**Note:** `.insufficientCredits` already exists (line 886), just needs to be used.

---

#### Change 3: Update AppError Mapping

**File:** `BananaUniverse/Core/Models/AppError.swift`

**Current (Line 84):**
```swift
case .dailyQuotaExceeded:
    return "You've reached your daily limit. Come back tomorrow or upgrade for unlimited access."
```

**Keep this for actual daily limits (if you add rate limiting later), but add:**
```swift
case .insufficientCredits:
    return "You're out of credits! Tap here to get more and continue processing images."
```

**Note:** `.insufficientCredits` already exists (line 28), just needs proper mapping.

---

#### Change 4: Update Error Mapping Logic

**File:** `BananaUniverse/Core/Services/SupabaseService.swift`

**Current (Line 922):**
```swift
var appError: AppError {
    switch self {
    // ... other cases ...
    case .quotaExceeded:
        return .dailyQuotaExceeded
    }
}
```

**Updated:**
```swift
var appError: AppError {
    switch self {
    // ... other cases ...
    case .insufficientCredits:
        return .insufficientCredits
    case .quotaExceeded:
        return .dailyQuotaExceeded  // Keep for future rate limiting
    }
}
```

---

### 5.2 Optional: Add Rate Limiting Support (Future)

**If you add rate limiting later, you can use 429:**

```swift
if httpResponse.statusCode == 402 {
    throw SupabaseError.insufficientCredits
} else if httpResponse.statusCode == 429 {
    throw SupabaseError.rateLimitExceeded  // Already exists at line 892
}
```

**This allows:**
- 402 → Insufficient credits (purchase required)
- 429 → Rate limit (wait and retry)

---

## 6. Testing Plan

### 6.1 Test Cases

**Test 1: User with 0 credits**
- Submit job
- Verify 402 status code received
- Verify `.insufficientCredits` error thrown
- Verify purchase prompt shown
- ✅ **Expected:** Clear error message with purchase option

**Test 2: User with 1 credit**
- Submit job
- Verify credit consumed (200 status)
- Verify balance updated
- ✅ **Expected:** Job succeeds, balance becomes 0

**Test 3: Premium user**
- Submit job with premium subscription
- Verify bypasses credit check
- Verify 200 status
- ✅ **Expected:** Job succeeds, no credit consumed

**Test 4: Network error**
- Simulate network failure
- Verify generic error handling
- ✅ **Expected:** Network error message (not credit error)

---

## 7. Best Practices Alignment

### 7.1 HTTP Status Code Best Practices

**✅ Correct Usage:**
- `402` → Payment/credit required (user action needed)
- `429` → Rate limiting (temporal restriction)
- `400` → Bad request (client error)
- `500` → Server error (server issue)

**✅ Industry Standards:**
- Stripe: 402 for payment required
- AWS: 402 for insufficient balance
- Credit APIs: 402 for insufficient credits
- Rate limiting APIs: 429 for too many requests

**✅ Semantic Clarity:**
- Different codes for different problems
- Client can handle each appropriately
- Clear separation of concerns

---

### 7.2 API Design Best Practices

**✅ Status Code Semantics:**
- Status code indicates **type** of problem
- Response body provides **details**
- Client can make **informed decisions**

**✅ Error Response Structure:**
```json
{
  "success": false,
  "error": "Insufficient credits. Purchase more credits to continue.",
  "quota_info": {
    "credits_remaining": 0,
    "is_premium": false
  }
}
```

**✅ Client Handling:**
- Check status code for error type
- Parse response body for details
- Show appropriate UI based on error type

---

## 8. Migration Strategy

### 8.1 Backward Compatibility

**Current State:**
- Backend returns 402 (correct)
- iOS checks for 429 (wrong)
- Result: Generic error

**After Fix:**
- Backend returns 402 (unchanged)
- iOS checks for 402 (fixed)
- Result: Correct error handling

**No Breaking Changes:**
- Backend API unchanged
- Only client-side fix
- No migration needed

---

### 8.2 Rollout Plan

**Phase 1: Update Code**
1. Update status code check (402 instead of 429)
2. Update error messages
3. Update error mappings
4. Test locally

**Phase 2: Deploy**
1. Deploy iOS app update
2. Monitor error rates
3. Verify purchase prompts appear
4. Track conversion rates

**Phase 3: Monitor**
1. Check error logs for 402 responses
2. Verify error handling works
3. Monitor purchase conversion
4. Gather user feedback

---

## 9. Summary & Action Items

### ✅ Recommendation: Update iOS Client

**Why:**
- Backend is semantically correct (402 for credits)
- Industry standard practice
- Better API design
- Future-proof

**Changes Required:**
1. ✅ Update status code check: `429` → `402`
2. ✅ Update error type: `.quotaExceeded` → `.insufficientCredits`
3. ✅ Update error messages: "daily limit" → "insufficient credits"
4. ✅ Update AppError mapping

**Files to Modify:**
- `BananaUniverse/Core/Services/SupabaseService.swift` (lines 285, 451, 914, 922)
- `BananaUniverse/Core/Models/AppError.swift` (line 84 - verify mapping)

**Testing:**
- Test with 0 credits (should show purchase prompt)
- Test with 1 credit (should work normally)
- Test premium user (should bypass)

**Priority:** 🔴 **HIGH** - Affects user experience and revenue

---

## 10. Code References

**Backend (Correct):**
- ```324:324:supabase/functions/submit-job/index.ts``` - Returns 402

**iOS Client (Needs Fix):**
- ```285:286:BananaUniverse/Core/Services/SupabaseService.swift``` - Checks 429
- ```451:451:BananaUniverse/Core/Services/SupabaseService.swift``` - Checks 429
- ```914:915:BananaUniverse/Core/Services/SupabaseService.swift``` - Error message
- ```84:85:BananaUniverse/Core/Models/AppError.swift``` - AppError message

**Note:** `webhook-handler` correctly uses 429 for rate limiting (line 181) - this is correct and should remain unchanged.

---

**Report Generated:** 2025-01-27  
**Status:** ✅ **Recommendation: Update iOS client to handle 402**  
**Priority:** 🔴 **HIGH** - Fix immediately for better UX and revenue

