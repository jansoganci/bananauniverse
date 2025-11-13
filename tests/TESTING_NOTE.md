# Testing Note: 402 Status Code Test

## Issue: 401 Invalid JWT Error

The test script is currently getting `401 Invalid JWT` errors. This is because:

1. **The anon key in the script may be expired** - JWT tokens can expire
2. **Supabase Edge Functions require valid authentication** at the platform level
3. **The function code runs after platform authentication passes**

## Solutions

### Option 1: Get Fresh Anon Key (Recommended)

1. Go to Supabase Dashboard: https://supabase.com/dashboard
2. Select your project: `jiorfutbmahpfgplkats`
3. Go to: **Settings → API**
4. Copy the **anon/public** key
5. Run:
   ```bash
   export ANON_KEY='your-fresh-anon-key'
   ./tests/test_402_status_code.sh
   ```

### Option 2: Test via iOS App (Alternative)

Since the iOS app uses the same authentication, you can test the 402 fix directly in the app:

1. **Set credits to 0 in database:**
   ```sql
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
   - Check HTTP status code is 402

### Option 3: Test with Valid User Session

If you have a valid user session token:

```bash
export USER_TOKEN='your-valid-jwt-token'
export DEVICE_ID='your-device-id'

curl -X POST "$SUPABASE_URL/functions/v1/submit-job" \
  -H "Authorization: Bearer $USER_TOKEN" \
  -H "Content-Type: application/json" \
  -H "device-id: $DEVICE_ID" \
  -d '{"image_url":"test.jpg","prompt":"test","device_id":"'$DEVICE_ID'"}'
```

## What the Test Verifies

The test script verifies:
1. ✅ Backend returns 402 when credits are exhausted
2. ✅ Response contains error message about insufficient credits
3. ✅ Response includes `credits_remaining: 0`
4. ✅ Response structure is correct

## Current Status

- ❌ **Backend test:** Blocked by authentication (401 errors)
- ✅ **iOS fix:** Code changes complete
- ✅ **Ready for:** iOS app testing (manual)

## Next Steps

1. **Get fresh anon key** from Supabase Dashboard
2. **Re-run test script** with valid key
3. **OR test via iOS app** (recommended for end-to-end verification)

---

**Note:** The 402 status code fix is complete in the iOS code. The test script is just for verification. You can verify the fix works by testing in the iOS app directly.

