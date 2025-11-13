# Credit System - Quick Reference

**Date**: November 13, 2025
**Status**: ✅ Production Ready

---

## TL;DR - What Changed?

### OLD: Daily Quota (Deleted)
- Users: 3 uses/day, resets at midnight UTC
- Premium: 100 uses/day
- Confusing: "Resets in 8 hours"

### NEW: Persistent Credits (Active)
- Users: Start with 10 credits, never reset
- Premium: Unlimited (bypass credit checks)
- Clear: "You have 10 credits"

---

## Database

### Tables
```sql
user_credits          -- Authenticated users
├── user_id (PK)
└── credits (default: 10)

anonymous_credits     -- Anonymous users
├── device_id (PK)
└── credits (default: 10)
```

### Functions
- `consume_credits(user_id, device_id, amount, idempotency_key)` - Deduct credits
- `add_credits(user_id, device_id, amount, idempotency_key)` - Add credits (refunds/purchases)
- `get_credits(user_id, device_id)` - Get balance

### Deleted
- ❌ `daily_quotas` table
- ❌ `consume_quota()` function
- ❌ `get_quota()` function

---

## Edge Functions

### submit-job/index.ts
```typescript
// Calls consume_credits() with idempotency
const result = await supabase.rpc('consume_credits', {
  p_user_id: userId || null,
  p_device_id: deviceId || null,
  p_amount: 1,
  p_idempotency_key: requestId
});

// Returns
{
  quota_info: {
    credits_remaining: 9,
    is_premium: false
  }
}
```

### webhook-handler/index.ts
```typescript
// Refunds credits on job failure
await supabase.rpc('add_credits', {
  p_user_id: userId || null,
  p_device_id: deviceId || null,
  p_amount: 1,
  p_idempotency_key: `refund-${requestId}`
});
```

---

## iOS Client

### Models
```swift
// CreditInfo.swift (NEW)
struct CreditInfo: Codable {
    let creditsRemaining: Int  // Current balance
    let isPremium: Bool
}
```

### Services
```swift
// CreditManager.swift
class CreditManager {
    @Published private(set) var creditsRemaining: Int = 10
    @Published private(set) var isPremiumUser: Bool = false

    func loadQuota() async  // Fetches from backend
    func canProcessImage() -> Bool  // Check if credits > 0
}
```

### UI
```swift
// Shows balance
Text("\(creditManager.creditsRemaining) credits")

// Premium users
Text(creditManager.isPremiumUser ? "Unlimited" : "\(creditsRemaining) credits")
```

---

## Migration Files

1. **062_activate_credit_system.sql** - Activate credits, set defaults
2. **063_remove_daily_quota_system.sql** - Delete old quota system
3. **064_create_credit_functions.sql** - Create new credit functions

---

## API Responses

### Success Response
```json
{
  "success": true,
  "job_id": "abc123",
  "status": "pending",
  "quota_info": {
    "credits_remaining": 9,
    "is_premium": false
  }
}
```

### Error Response (Insufficient Credits)
```json
{
  "success": false,
  "error": "Insufficient credits",
  "quota_info": {
    "credits_remaining": 0,
    "is_premium": false
  }
}
```

### Premium User Response
```json
{
  "success": true,
  "credits_remaining": 999999,
  "is_premium": true
}
```

---

## Key Concepts

### Persistent Balance
- Credits NEVER reset
- Like money in a wallet
- Buy once, use anytime

### Idempotency
- Prevents double-charging if iOS retries
- Use unique `requestId` per request
- Cached results returned for duplicate keys

### Premium Bypass
- Premium users: `is_premium: true`
- Skip all credit checks
- Return `credits_remaining: 999999` (unlimited)

### Atomic Transactions
- `FOR UPDATE` lock prevents race conditions
- Balance checked and deducted in single transaction
- Either succeeds or fails (no partial deduction)

---

## Testing Commands

### Database
```sql
-- Check credit balance
SELECT user_id, credits FROM user_credits WHERE user_id = 'xxx';

-- Add credits manually
SELECT add_credits('user-id', null, 10, 'manual-add-123');

-- Check history
SELECT * FROM idempotency_keys WHERE user_id = 'xxx' ORDER BY created_at DESC;
```

### Edge Functions
```bash
# Test submit-job
curl -X POST https://xxx.supabase.co/functions/v1/submit-job \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"image_url": "...", "prompt": "enhance"}'

# Check logs
supabase functions logs submit-job --tail
```

### iOS
```swift
// Check balance
print(CreditManager.shared.creditsRemaining)

// Trigger credit load
await CreditManager.shared.loadQuota()
```

---

## Deployment

```bash
# 1. Migrations
supabase db push

# 2. Edge Functions
supabase functions deploy submit-job
supabase functions deploy webhook-handler

# 3. iOS App
xcodebuild build
```

---

## Common Tasks

### Give User Free Credits
```sql
SELECT add_credits(
  'user-id',
  null,
  10,
  'promo-2025-11-13'
);
```

### Check All Users with Low Credits
```sql
SELECT user_id, credits
FROM user_credits
WHERE credits < 3 AND credits > 0
ORDER BY credits ASC;
```

### Reset User Credits (Support)
```sql
UPDATE user_credits
SET credits = 10
WHERE user_id = 'xxx';
```

### View Credit Transaction History
```sql
SELECT * FROM idempotency_keys
WHERE user_id = 'xxx'
ORDER BY created_at DESC
LIMIT 20;
```

---

## Troubleshooting

### User Has 0 Credits
**Problem**: New user shows 0 credits
**Solution**: Call `get_credits()` - auto-initializes with 10

### iOS Shows Old Quota Format
**Problem**: Shows "3 / 10" instead of "7 credits"
**Solution**: Update `QuotaDisplayView` to use `creditsRemaining`

### Backend Returns Wrong Fields
**Problem**: iOS can't decode response
**Solution**: Ensure backend sends `credits_remaining` (not `credits`)

---

## Files Changed

### Backend
- `supabase/migrations/062_activate_credit_system.sql` (NEW)
- `supabase/migrations/063_remove_daily_quota_system.sql` (NEW)
- `supabase/migrations/064_create_credit_functions.sql` (NEW)
- `supabase/functions/submit-job/index.ts` (UPDATED)

### iOS
- `BananaUniverse/Core/Models/CreditInfo.swift` (NEW)
- `BananaUniverse/Core/Models/QuotaInfo.swift` (DELETED)
- `BananaUniverse/Core/Services/CreditManager.swift` (RENAMED)
- `BananaUniverse/Core/Services/QuotaService.swift` (UPDATED)
- `BananaUniverse/Core/Services/QuotaCache.swift` (UPDATED)
- `BananaUniverse/Core/Components/QuotaDisplayView.swift` (UPDATED)

---

## Contact

**Questions?** Check the full documentation:
- `docs/credit-system/CREDIT_SYSTEM_MIGRATION_COMPLETE.md`
- `docs/credit-system/AUDIT_REPORT.md` (if exists)

**Need Help?** Contact development team or check Supabase logs.
