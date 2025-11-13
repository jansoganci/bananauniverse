# iOS App Testing Guide: 402 Status Code Fix

**Purpose:** Test that iOS app correctly handles 402 status code for insufficient credits

---

## Prerequisites

1. ✅ iOS app code updated (status code check changed from 429 to 402)
2. ✅ Backend returns 402 for insufficient credits (verified with curl)
3. ✅ Test device/emulator ready

---

## Test Scenarios

### Test 1: User with 0 Credits

**Objective:** Verify app shows purchase prompt when credits are exhausted

**Steps:**
1. **Setup:** Ensure test user/device has 0 credits
   - Option A: Use a new device (starts with 10 credits, consume them)
   - Option B: Manually set credits to 0 in database:
     ```sql
     UPDATE anonymous_credits SET credits = 0 WHERE device_id = 'your-device-id';
     ```

2. **Test:**
   - Open iOS app
   - Try to submit an image processing job
   - Observe error handling

3. **Expected Behavior:**
   - ✅ App receives 402 status code
   - ✅ `SupabaseError.insufficientCredits` is thrown
   - ✅ Error message displayed: "You don't have enough credits. Purchase more credits to continue!"
   - ✅ `AppError.insufficientCredits` is shown to user
   - ✅ User sees: "You're out of credits! Tap here to get more and continue processing images."
   - ✅ Purchase prompt/button appears (if implemented)

4. **Verify in Console:**
   ```swift
   // Check error type
   print("Error type: \(error)")
   // Should print: SupabaseError.insufficientCredits
   
   // Check error message
   print("Error message: \(error.localizedDescription)")
   // Should print: "You don't have enough credits. Purchase more credits to continue!"
   ```

---

### Test 2: User with 1 Credit

**Objective:** Verify app works normally when credits are available

**Steps:**
1. **Setup:** Ensure test user/device has 1 credit
   ```sql
   UPDATE anonymous_credits SET credits = 1 WHERE device_id = 'your-device-id';
   ```

2. **Test:**
   - Open iOS app
   - Submit an image processing job
   - Observe behavior

3. **Expected Behavior:**
   - ✅ Job submits successfully
   - ✅ Returns 200 status code
   - ✅ Credit consumed (balance becomes 0)
   - ✅ No error shown

4. **Verify:**
   - Check credit balance after job: should be 0
   - Next job should trigger 402 error (Test 1 scenario)

---

### Test 3: Premium User (Unlimited Credits)

**Objective:** Verify premium users bypass credit checks

**Steps:**
1. **Setup:** Create active subscription for test user
   ```sql
   INSERT INTO subscriptions (user_id, device_id, status, product_id, expires_at, original_transaction_id)
   VALUES (NULL, 'your-device-id', 'active', 'weekly_pro', NOW() + INTERVAL '7 days', 'test-tx-123');
   ```

2. **Test:**
   - Open iOS app
   - Submit multiple jobs (more than 10)
   - Observe behavior

3. **Expected Behavior:**
   - ✅ All jobs succeed (no 402 errors)
   - ✅ Backend returns `is_premium: true`
   - ✅ Credits show as "Unlimited" in UI
   - ✅ No credit consumption

---

### Test 4: Error Handling Flow

**Objective:** Verify error is properly mapped through the error handling chain

**Steps:**
1. **Setup:** User with 0 credits

2. **Test:** Submit job and trace error flow

3. **Verify Error Chain:**
   ```
   HTTP 402 Response
       ↓
   SupabaseService.swift (line 285)
       ↓
   SupabaseError.insufficientCredits
       ↓
   appError property (line 926)
       ↓
   AppError.insufficientCredits
       ↓
   User-facing message (AppError.swift line 82)
       ↓
   UI Display
   ```

4. **Add Debug Logging:**
   ```swift
   // In SupabaseService.swift, after line 285
   if httpResponse.statusCode == 402 {
       print("🔍 [DEBUG] Received 402 status code")
       print("🔍 [DEBUG] Throwing SupabaseError.insufficientCredits")
       throw SupabaseError.insufficientCredits
   }
   
   // In error handler
   catch let error as SupabaseError {
       print("🔍 [DEBUG] Caught SupabaseError: \(error)")
       print("🔍 [DEBUG] AppError: \(error.appError)")
   }
   ```

---

## Manual Testing Checklist

### Pre-Test Setup
- [ ] Backend deployed and returning 402 (verified with curl)
- [ ] iOS app code updated (status code check changed)
- [ ] App rebuilt with latest changes
- [ ] Test device/emulator ready

### Test Execution
- [ ] Test 1: 0 credits → Shows purchase prompt
- [ ] Test 2: 1 credit → Job succeeds
- [ ] Test 3: Premium user → Unlimited credits
- [ ] Test 4: Error handling chain works

### Verification
- [ ] Console logs show correct error type
- [ ] Error message is user-friendly
- [ ] Purchase prompt appears (if implemented)
- [ ] No crashes or unexpected behavior

---

## Debugging Tips

### If 402 Error Not Caught

**Check:**
1. Is status code check correct?
   ```swift
   // Should be:
   if httpResponse.statusCode == 402 {
   // NOT:
   if httpResponse.statusCode == 429 {
   ```

2. Is error type correct?
   ```swift
   // Should be:
   throw SupabaseError.insufficientCredits
   // NOT:
   throw SupabaseError.quotaExceeded
   ```

### If Wrong Error Message

**Check:**
1. Error mapping in `SupabaseService.swift` (line 926)
2. Error message in `SupabaseError` (line 900)
3. User message in `AppError` (line 82)

### If Purchase Prompt Not Showing

**Check:**
1. Is purchase flow implemented?
2. Is error properly mapped to `AppError.insufficientCredits`?
3. Does UI listen for this error type?

---

## Automated Testing (Future)

### Unit Test Example

```swift
func testInsufficientCreditsError() async throws {
    // Mock HTTP response with 402
    let mockResponse = HTTPURLResponse(
        url: URL(string: "https://test.com")!,
        statusCode: 402,
        httpVersion: nil,
        headerFields: nil
    )!
    
    // Test error handling
    // Verify SupabaseError.insufficientCredits is thrown
    // Verify error message is correct
}
```

---

## Success Criteria

✅ **Test Passes If:**
- App correctly identifies 402 status code
- Error message is clear and actionable
- Purchase prompt appears (if implemented)
- No crashes or unexpected behavior
- Error handling chain works end-to-end

❌ **Test Fails If:**
- App doesn't recognize 402 status code
- Generic error shown instead of credit error
- Wrong error message displayed
- App crashes on 402 response
- Purchase prompt doesn't appear

---

## Next Steps After Testing

1. ✅ Verify all test scenarios pass
2. ✅ Document any issues found
3. ✅ Fix any bugs discovered
4. ✅ Re-test after fixes
5. ✅ Deploy to production
6. ✅ Monitor error logs in production

---

**Last Updated:** 2025-01-27  
**Status:** Ready for testing

