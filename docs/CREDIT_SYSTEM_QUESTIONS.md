# Credit System Analysis Questions

## 🎯 Purpose
Understand how the credit system works in the other app so we can adopt the same logic.

---

## 1. Credit Initialization & Setup

### When are credits first granted?
- [ ] On app install?
- [ ] On first app launch?
- [ ] On user signup/registration?
- [ ] On device check?
- [ ] Other: _______________

### How many credits are granted initially?
- [ ] Fixed amount (e.g., 10 credits)
- [ ] Variable based on user type
- [ ] Promotional amount
- [ ] Other: _______________

### Where is the initial grant handled?
- [ ] Frontend (iOS app)
- [ ] Backend (Edge Function)
- [ ] Database trigger/function
- [ ] Other: _______________

---

## 2. Credit Storage & Database

### What database tables store credits?
- [ ] Single table (e.g., `user_credits`)
- [ ] Separate tables for authenticated vs anonymous
- [ ] Integrated in users table
- [ ] Other: _______________

### What columns exist in credit table(s)?
- [ ] `user_id` / `device_id`
- [ ] `credits` / `balance`
- [ ] `created_at` / `updated_at`
- [ ] `lifetime_purchased` / `lifetime_spent`
- [ ] Other: _______________

### Is there a transaction/audit log table?
- [ ] Yes - table name: _______________
- [ ] No
- [ ] Logs in same table
- [ ] Other: _______________

---

## 3. Credit Deduction Flow

### When are credits deducted?
- [ ] Before API call (optimistic)
- [ ] After API call succeeds
- [ ] Atomically in database function
- [ ] Other: _______________

### How is deduction handled?
- [ ] Frontend subtracts, then backend validates
- [ ] Backend deducts atomically (single source of truth)
- [ ] Both frontend and backend deduct
- [ ] Other: _______________

### What happens if deduction fails?
- [ ] Show error, don't deduct
- [ ] Retry automatically
- [ ] Refund if already deducted
- [ ] Other: _______________

### Is there idempotency protection?
- [ ] Yes - how: _______________
- [ ] No
- [ ] Only for purchases
- [ ] Other: _______________

---

## 4. Credit Addition (Purchases/Grants)

### How are credits added?
- [ ] In-app purchases (IAP)
- [ ] Admin grants
- [ ] Promotional codes
- [ ] Refunds
- [ ] Other: _______________

### Where is purchase validation handled?
- [ ] Frontend (StoreKit)
- [ ] Backend (Edge Function)
- [ ] Both (frontend + backend verification)
- [ ] Other: _______________

### What happens on purchase success?
- [ ] Credits added immediately
- [ ] Credits added after verification
- [ ] Credits queued for processing
- [ ] Other: _______________

---

## 5. Credit Validation & Checks

### When are credits checked?
- [ ] Before showing generate button
- [ ] Before API call
- [ ] In backend before processing
- [ ] All of the above
- [ ] Other: _______________

### How is "insufficient credits" handled?
- [ ] Show error message
- [ ] Show paywall
- [ ] Disable button
- [ ] Other: _______________

### Is there a minimum credit threshold?
- [ ] Yes - amount: _______________
- [ ] No
- [ ] Only for certain features
- [ ] Other: _______________

---

## 6. Frontend/Backend Sync

### How does frontend know credit balance?
- [ ] Fetches from backend on app launch
- [ ] Fetches before each operation
- [ ] Backend returns balance in API responses
- [ ] Cached locally, synced periodically
- [ ] Other: _______________

### How often is balance synced?
- [ ] On app launch only
- [ ] Before each credit operation
- [ ] Periodically in background
- [ ] On app foreground
- [ ] Other: _______________

### What happens if frontend and backend are out of sync?
- [ ] Frontend always trusts backend
- [ ] Frontend shows cached value, syncs in background
- [ ] Error shown, force refresh
- [ ] Other: _______________

---

## 7. Error Handling & Edge Cases

### What happens on network failure?
- [ ] Keep cached credits, show warning
- [ ] Block operations until network available
- [ ] Retry automatically
- [ ] Other: _______________

### What happens if user has 0 credits?
- [ ] Show paywall immediately
- [ ] Allow viewing but block generation
- [ ] Show "out of credits" message
- [ ] Other: _______________

### What happens on duplicate requests?
- [ ] Idempotency prevents double charge
- [ ] Second request fails
- [ ] Both succeed (bug)
- [ ] Other: _______________

### What happens if backend deducts but operation fails?
- [ ] Credits automatically refunded
- [ ] Credits lost (bug)
- [ ] Manual refund required
- [ ] Other: _______________

---

## 8. User Experience

### How are credits displayed to user?
- [ ] Number badge in header
- [ ] On generate button
- [ ] In profile/settings
- [ ] All of the above
- [ ] Other: _______________

### Is there credit purchase UI?
- [ ] Yes - where: _______________
- [ ] No
- [ ] Only paywall
- [ ] Other: _______________

### Are there credit warnings?
- [ ] Yes - when credits < X
- [ ] No
- [ ] Only when 0
- [ ] Other: _______________

---

## 9. Security & Validation

### How is credit manipulation prevented?
- [ ] Backend validates all operations
- [ ] Database constraints
- [ ] Row-level locking
- [ ] All of the above
- [ ] Other: _______________

### Can users see their credit history?
- [ ] Yes - in app
- [ ] No
- [ ] Only in database
- [ ] Other: _______________

### Are there rate limits?
- [ ] Yes - how: _______________
- [ ] No
- [ ] Only for purchases
- [ ] Other: _______________

---

## 10. Technical Implementation

### What database functions exist?
- [ ] `get_credits()`
- [ ] `deduct_credits()`
- [ ] `add_credits()`
- [ ] `consume_credits()`
- [ ] Other: _______________

### Are there Edge Functions for credits?
- [ ] Yes - list: _______________
- [ ] No
- [ ] Only for purchases
- [ ] Other: _______________

### How is concurrency handled?
- [ ] Database row locking (SELECT FOR UPDATE)
- [ ] Optimistic locking
- [ ] Transaction isolation
- [ ] Other: _______________

### Is there caching?
- [ ] Yes - where: _______________
- [ ] No
- [ ] Only for balance display
- [ ] Other: _______________

---

## 11. Anonymous vs Authenticated Users

### Do anonymous users get credits?
- [ ] Yes - same as authenticated
- [ ] Yes - different amount
- [ ] No
- [ ] Other: _______________

### What happens when anonymous user signs up?
- [ ] Credits transfer to authenticated account
- [ ] Credits stay with device
- [ ] Credits reset
- [ ] Other: _______________

### Are credits shared across devices?
- [ ] Yes - for authenticated users
- [ ] No - per device
- [ ] Only for purchases
- [ ] Other: _______________

---

## 12. Testing & Monitoring

### How are credit issues debugged?
- [ ] Database queries
- [ ] Transaction logs
- [ ] App logs
- [ ] All of the above
- [ ] Other: _______________

### Are there admin tools?
- [ ] Yes - for what: _______________
- [ ] No
- [ ] Only database access
- [ ] Other: _______________

---

## 13. Migration & Compatibility

### Has the credit system changed over time?
- [ ] Yes - what changed: _______________
- [ ] No
- [ ] Minor updates only
- [ ] Other: _______________

### Are there legacy systems to support?
- [ ] Yes - what: _______________
- [ ] No
- [ ] Migration completed
- [ ] Other: _______________

---

## 📝 Additional Notes

### What works really well?
_________________________________________________________________
_________________________________________________________________

### What are the pain points?
_________________________________________________________________
_________________________________________________________________

### What would you change if rebuilding?
_________________________________________________________________
_________________________________________________________________

### Any special edge cases or gotchas?
_________________________________________________________________
_________________________________________________________________

---

## 🎯 Priority Questions (Start Here)

If you want to answer just the essentials first:

1. **Where are credits stored?** (Database tables)
2. **How are credits deducted?** (Frontend vs backend)
3. **How are credits initialized?** (When and where)
4. **How does frontend sync with backend?** (When and how often)
5. **What happens on errors?** (Network failures, insufficient credits)

