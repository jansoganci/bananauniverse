# Log Analysis: Credit Sync Issue

## Timeline from Logs

### 1. App Launch (Initial State)
```
💾 [CACHE] Loaded: 3 credits, stale: true
📊 [CREDITS] Balance: 10 → 3
📱 [CREDITS] Loaded from cache: 3 credits
```
**Analysis:**
- Cache had **stale data** (3 credits, marked as stale)
- App loaded 3 credits from cache (old data)
- Initial balance showed 10 → 3 (this is just the initial state change)

### 2. First Backend Sync Attempt
```
❌ [CREDITS] Load failed: Network error. Please check your connection and try again.
```
**Analysis:**
- First attempt to sync with backend **failed** (network error)
- App kept using cached value (3 credits)
- User saw 3 credits in UI (but this was stale data)

### 3. Successful Backend Sync (Later)
```
🔄 [CREDITS] Backend sync: 3 → 0
💾 [CACHE] Saved: 0 credits
📊 [CREDITS] Balance: 3 → 0
```
**Analysis:**
- Backend sync **succeeded** and returned **0 credits**
- Frontend updated from 3 → 0
- Cache saved 0 credits

## Root Cause Analysis

### Problem 1: Stale Cache Data
- Cache had 3 credits from a previous session
- Cache was marked as "stale" (older than 5 minutes)
- App used stale cache when network failed

### Problem 2: Backend Has 0 Credits
- Backend actually returned **0 credits** for this user/device
- This is the **real issue** - why does backend have 0?

### Possible Reasons for 0 Credits:
1. **Credits were consumed** in previous sessions
2. **User/device record doesn't exist** in credit tables
3. **Credits never initialized** when user/device was created
4. **Wrong user_id/device_id** being used (different account)

## The Real Bug

The user expected to have 10 credits (initial grant), but backend has 0. This suggests:

1. **Missing Initialization**: User/device record might not exist in `user_credits` or `anonymous_credits` table
2. **Credits Were Spent**: User might have used 10 credits in previous sessions
3. **Database Issue**: Credits might have been reset or deleted

## Solution

### Immediate Fix (Already Applied)
✅ Refresh credits from backend before checking
✅ Sync frontend when backend returns 402 error
✅ Added logging to track credit changes

### Next Steps to Investigate

1. **Check Database:**
   ```sql
   -- Check if user/device has credit record
   SELECT * FROM user_credits WHERE user_id = '<user_id>';
   SELECT * FROM anonymous_credits WHERE device_id = '<device_id>';
   
   -- Check credit transactions
   SELECT * FROM credit_transactions 
   WHERE user_id = '<user_id>' OR device_id = '<device_id>'
   ORDER BY created_at DESC;
   ```

2. **Check `get_credits` Function:**
   - Should auto-initialize credits if record doesn't exist
   - Verify it's creating records with 10 credits

3. **Check User/Device ID:**
   - Verify correct user_id/device_id is being used
   - Check if user switched between anonymous/authenticated

## Recommendations

1. **Auto-Initialize Credits**: Ensure `get_credits` always returns at least 10 credits for new users/devices
2. **Better Error Handling**: Show user-friendly message when credits are 0
3. **Credit History**: Add UI to show credit transaction history
4. **Debug Mode**: Add button to check actual backend credit balance

