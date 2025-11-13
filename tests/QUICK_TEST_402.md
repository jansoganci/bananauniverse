# Quick Test Guide: 402 Status Code Fix

**Quick reference for testing the status code mismatch fix**

---

## 🚀 Quick Test (5 minutes)

### Step 1: Test Backend with curl

```bash
# Set your variables
export SUPABASE_URL="https://jiorfutbmahpfgplkats.supabase.co"
export ANON_KEY="your-anon-key"
export DEVICE_ID="test-$(date +%s)"

# Run the test script
./tests/test_402_status_code.sh
```

**Expected Output:**
```
✅ SUCCESS: Backend correctly returns 402 status code
✅ Response contains credit-related error message
✅ Response includes credits_remaining field
```

---

### Step 2: Test iOS App (Manual)

1. **Set credits to 0:**
   ```sql
   -- In Supabase SQL Editor
   UPDATE anonymous_credits 
   SET credits = 0 
   WHERE device_id = 'your-device-id';
   ```

2. **Test in iOS app:**
   - Open app
   - Try to submit a job
   - **Expected:** See "You're out of credits! Tap here to get more"

3. **Verify in Xcode console:**
   - Look for: `SupabaseError.insufficientCredits`
   - Check error message is correct

---

## 📋 Detailed Testing

### Option A: Automated Script (Backend)

```bash
# Full automated test
./tests/test_402_status_code.sh
```

**What it does:**
- Consumes all credits (submits 11 jobs)
- Verifies 402 status code is returned
- Checks response structure
- Validates error message

---

### Option B: Manual curl Test

```bash
# 1. Consume credits (submit 11 jobs)
for i in {1..11}; do
  curl -X POST "$SUPABASE_URL/functions/v1/submit-job" \
    -H "Authorization: Bearer $ANON_KEY" \
    -H "Content-Type: application/json" \
    -H "device-id: $DEVICE_ID" \
    -d '{"image_url": "https://example.com/test.jpg", "prompt": "test", "device_id": "'"$DEVICE_ID"'"}'
  sleep 1
done

# 2. Test 402 response
curl -v -X POST "$SUPABASE_URL/functions/v1/submit-job" \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "Content-Type: application/json" \
  -H "device-id: $DEVICE_ID" \
  -d '{"image_url": "https://example.com/test.jpg", "prompt": "test", "device_id": "'"$DEVICE_ID"'"}'

# Look for: HTTP/1.1 402 Payment Required
```

---

### Option C: iOS App Testing

See full guide: `tests/IOS_TESTING_GUIDE.md`

**Quick checklist:**
- [ ] User with 0 credits → Shows purchase prompt
- [ ] User with 1 credit → Job succeeds
- [ ] Premium user → Unlimited credits
- [ ] Error message is correct

---

## ✅ Success Criteria

**Backend Test:**
- ✅ Returns HTTP 402 status code
- ✅ Response contains `"success": false`
- ✅ Response contains `"error": "Insufficient credits..."`
- ✅ Response contains `"credits_remaining": 0`

**iOS App Test:**
- ✅ Recognizes 402 status code
- ✅ Shows correct error message
- ✅ Purchase prompt appears (if implemented)
- ✅ No crashes

---

## 🐛 Troubleshooting

### Backend returns 200 instead of 402

**Check:**
- User still has credits (check database)
- Premium user bypasses credit check
- Credit consumption function working

**Fix:**
```sql
-- Manually set credits to 0
UPDATE anonymous_credits SET credits = 0 WHERE device_id = 'your-device-id';
```

### iOS app doesn't show error

**Check:**
- Status code check is `402` (not `429`)
- Error type is `insufficientCredits` (not `quotaExceeded`)
- Error mapping is correct

**Verify:**
```swift
// In SupabaseService.swift line 285
if httpResponse.statusCode == 402 {  // ✅ Should be 402
    throw SupabaseError.insufficientCredits  // ✅ Should be insufficientCredits
}
```

---

## 📚 Full Documentation

- **Backend Test Script:** `tests/test_402_status_code.sh`
- **iOS Testing Guide:** `tests/IOS_TESTING_GUIDE.md`
- **Status Code Analysis:** `docs/STATUS_CODE_MISMATCH_ANALYSIS.md`

---

**Quick Test Time:** ~5 minutes  
**Full Test Time:** ~15 minutes

