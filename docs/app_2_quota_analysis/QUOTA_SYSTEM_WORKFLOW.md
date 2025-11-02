# 📊 Quota System Workflow Reference

**Quick Reference Guide** - Visual workflows and call sequences

---

## 🔄 Complete Workflow: Guest User First Reading

```
┌─────────────────────────────────────────────────────────────────────┐
│ 1. APP LAUNCH                                                       │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
    ┌────────────────────────────────────────────┐
    │ DeviceIDManager.getOrCreateDeviceID()      │
    │ • Checks UserDefaults for existing ID      │
    │ • Uses UIDevice.identifierForVendor        │
    │ • Stores: "device_id" → UserDefaults       │
    └────────────────┬───────────────────────────┘
                     │
                     ▼
    ┌────────────────────────────────────────────┐
    │ AuthService.createGuestUser(deviceId)      │
    │ • Calls: create_guest_user(p_device_id)    │
    │ • Returns: UUID (user_id)                  │
    │ • Stores: "guest_user_id" → UserDefaults   │
    └────────────────┬───────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 2. MAIN TAB VIEW LOADS                                              │
└─────────────────────────────────────────────────────────────────────┘
                     │
                     ▼
    ┌────────────────────────────────────────────┐
    │ QuotaManager.fetchQuota()                  │
    │ • Check cache (< 5 min TTL) → return       │
    │ • Call: get_quota Edge Function            │
    │   ├─ POST /functions/v1/get_quota          │
    │   ├─ Body: { user_id: "..." }              │
    │   └─ Edge Function calls RPC:              │
    │       get_quota(p_user_id: UUID)           │
    └────────────────┬───────────────────────────┘
                     │
                     ▼
    ┌────────────────────────────────────────────┐
    │ Database: get_quota() RPC Function         │
    │ 1. Check subscriptions (premium?)          │
    │    → Yes: Return { quota_remaining: 999999 }│
    │ 2. Query daily_quotas                      │
    │    SELECT free_readings_used               │
    │    WHERE user_id = ? AND date = TODAY      │
    │ 3. Calculate: 3 - free_readings_used       │
    │ 4. Return JSON response                    │
    └────────────────┬───────────────────────────┘
                     │
                     ▼
    ┌────────────────────────────────────────────┐
    │ UI Updates                                 │
    │ • remainingQuota = 3                       │
    │ • isPremiumUser = false                    │
    │ • Display: "0/3 used"                      │
    └────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 3. USER TAKES PHOTO                                                 │
└─────────────────────────────────────────────────────────────────────┘
                     │
                     ▼
    ┌────────────────────────────────────────────┐
    │ PhotoCaptureViewModel.processSelectedImage │
    │ 1. Resize image (1080x1920)                │
    │ 2. Compress (JPEG 80%)                     │
    │ 3. Upload via StorageService               │
    └────────────────┬───────────────────────────┘
                     │
                     ▼
    ┌────────────────────────────────────────────┐
    │ StorageService.uploadImage()               │
    │ • Bucket: "fortune-images"                 │
    │ • Path: "{user_id}/{timestamp}.jpg"        │
    │ • Returns: public URL                      │
    └────────────────┬───────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 4. USER SUBMITS READING REQUEST                                    │
└─────────────────────────────────────────────────────────────────────┘
                     │
                     ▼
    ┌────────────────────────────────────────────┐
    │ AIProcessingService.processPalmReading()   │
    │ • Calls: process-palm-reading Edge Func    │
    │ • Body: {                                  │
    │     image_url: "https://...",              │
    │     user_id: "uuid",                       │
    │     reading_type: "palm",                  │
    │     cultural_origin: "chinese"             │
    │   }                                        │
    └────────────────┬───────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 5. EDGE FUNCTION: process-palm-reading                              │
└─────────────────────────────────────────────────────────────────────┘
                     │
                     ▼
    ┌────────────────────────────────────────────┐
    │ STEP 1: Check Quota                       │
    │ • Call: get_quota(p_user_id)               │
    │ • If quota_remaining <= 0 → Return 429     │
    └────────────────┬───────────────────────────┘
                     │
                     ▼
    ┌────────────────────────────────────────────┐
    │ STEP 2: Fetch User Profile                │
    │ • Query users table                        │
    │ • Get: birth_date, birth_time, birth_city  │
    └────────────────┬───────────────────────────┘
                     │
                     ▼
    ┌────────────────────────────────────────────┐
    │ STEP 3: Fetch Image & Convert             │
    │ • Download from Storage URL                │
    │ • Convert to base64                        │
    └────────────────┬───────────────────────────┘
                     │
                     ▼
    ┌────────────────────────────────────────────┐
    │ STEP 4: Call Gemini AI                    │
    │ • Build personalized prompt                │
    │ • Send image + prompt to Gemini API        │
    │ • Receive fortune text                     │
    └────────────────┬───────────────────────────┘
                     │
                     ▼
    ┌────────────────────────────────────────────┐
    │ STEP 5: Save Reading                      │
    │ • INSERT INTO readings                     │
    │   (user_id, reading_type, image_url,       │
    │    result_text, cultural_origin)           │
    └────────────────┬───────────────────────────┘
                     │
                     ▼
    ┌────────────────────────────────────────────┐
    │ STEP 6: Consume Quota ⚠️ VULNERABILITY!    │
    │ • Call: consume_quota(p_user_id)           │
    │ • If error → Log but don't fail            │
    │ • ⚠️ Quota consumed AFTER processing!      │
    └────────────────┬───────────────────────────┘
                     │
                     ▼
    ┌────────────────────────────────────────────┐
    │ Database: consume_quota() RPC              │
    │ 1. Get current quota usage                 │
    │ 2. Check if quota_remaining > 0            │
    │    → No: Return { success: false }         │
    │ 3. Increment free_readings_used            │
    │    INSERT ... ON CONFLICT DO UPDATE        │
    │    SET free_readings_used += 1             │
    │ 4. Return { success: true, quota_remaining }│
    └────────────────┬───────────────────────────┘
                     │
                     ▼
    ┌────────────────────────────────────────────┐
    │ Return Response to iOS                     │
    │ {                                          │
    │   success: true,                           │
    │   result: "Your fortune text...",          │
    │   reading_type: "palm",                    │
    │   cultural_origin: "chinese",              │
    │   share_card_url: "...",                   │
    │   processing_time: 2341                    │
    │ }                                          │
    └────────────────┬───────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 6. CLIENT UPDATES UI                                                │
└─────────────────────────────────────────────────────────────────────┘
                     │
                     ▼
    ┌────────────────────────────────────────────┐
    │ QuotaManager.fetchQuota(forceRefresh: true)│
    │ • Bypass cache                             │
    │ • Fetch updated quota                      │
    │ • Update UI: "1/3 used"                    │
    └────────────────────────────────────────────┘

```

---

## 🔓 Attack Workflow: Race Condition Exploit

```
┌─────────────────────────────────────────────────────────────────────┐
│ ATTACKER: Sends 5 Concurrent Requests                              │
└─────────────────────────────────────────────────────────────────────┘
                     │
         ┌───────────┼───────────┬───────────┬───────────┐
         │           │           │           │           │
         ▼           ▼           ▼           ▼           ▼
    ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐
    │ REQ #1 │  │ REQ #2 │  │ REQ #3 │  │ REQ #4 │  │ REQ #5 │
    └───┬────┘  └───┬────┘  └───┬────┘  └───┬────┘  └───┬────┘
        │           │           │           │           │
        ▼           ▼           ▼           ▼           ▼
    ┌──────────────────────────────────────────────────────────┐
    │ All 5 call get_quota() simultaneously                    │
    │ Database returns: quota_remaining = 3                    │
    └──────────────────────────────────────────────────────────┘
        │           │           │           │           │
        ▼           ▼           ▼           ▼           ▼
    ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐
    │ All 5 pass quota check (3 > 0) ✅                        │
    └───┬────┘  └───┬────┘  └───┬────┘  └───┬────┘  └───┬────┘
        │           │           │           │           │
        ▼           ▼           ▼           ▼           ▼
    ┌──────────────────────────────────────────────────────────┐
    │ All 5 process readings (AI, image fetch, save)          │
    └──────────────────────────────────────────────────────────┘
        │           │           │           │           │
        ▼           ▼           ▼           ▼           ▼
    ┌──────────────────────────────────────────────────────────┐
    │ All 5 call consume_quota() sequentially                 │
    │ • REQ #1: quota: 3 → 2 ✅                                │
    │ • REQ #2: quota: 2 → 1 ✅                                │
    │ • REQ #3: quota: 1 → 0 ✅                                │
    │ • REQ #4: quota: 0 → -1 ⚠️ (should fail, but doesn't!)  │
    │ • REQ #5: quota: -1 → -2 ⚠️                              │
    └──────────────────────────────────────────────────────────┘
                     │
                     ▼
    ┌──────────────────────────────────────────────────────────┐
    │ RESULT: Attacker gets 5 readings instead of 3            │
    │ COST: $0.10 in AI processing (should be prevented)       │
    └──────────────────────────────────────────────────────────┘
```

---

## 🎭 Attack Workflow: Guest User ID Rotation

```
┌─────────────────────────────────────────────────────────────────────┐
│ ATTACKER: Unlimited Readings via New Guest Accounts                │
└─────────────────────────────────────────────────────────────────────┘

FOR i = 1 to 100:
    │
    ▼
┌────────────────────────────────────────────┐
│ Generate fake device ID                    │
│ device_id = crypto.randomUUID()            │
│ (e.g., "550e8400-e29b-41d4-a716-446655440000")│
└────────────────┬───────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────────┐
│ Call: create_guest_user(device_id)         │
│ Returns: user_id (UUID)                    │
│ ⚠️ No verification of device_id!           │
└────────────────┬───────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────────┐
│ Use 3 free readings                        │
│ • Reading #1: Palm reading                 │
│ • Reading #2: Face reading                 │
│ • Reading #3: Coffee reading               │
└────────────────┬───────────────────────────┘
                 │
                 ▼ (loop continues)

RESULT: 300 free readings (100 accounts × 3)
COST TO ATTACKER: $0
COST TO BUSINESS: ~$30 in AI processing
```

---

## 🔐 Secure Workflow: Recommended Fix

```
┌─────────────────────────────────────────────────────────────────────┐
│ IMPROVED WORKFLOW                                                   │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│ 1. CLIENT GENERATES UNIQUE REQUEST ID                               │
└─────────────────────────────────────────────────────────────────────┘
                     │
                     ▼
    ┌────────────────────────────────────────────┐
    │ const idempotencyKey = crypto.randomUUID() │
    │ headers['Idempotency-Key'] = idempotencyKey│
    └────────────────┬───────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 2. EDGE FUNCTION CHECKS FOR DUPLICATE                               │
└─────────────────────────────────────────────────────────────────────┘
                     │
                     ▼
    ┌────────────────────────────────────────────┐
    │ Check request_log for idempotencyKey       │
    │ • Found? Return cached response            │
    │ • Not found? Proceed                       │
    └────────────────┬───────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 3. CONSUME QUOTA FIRST (ATOMIC)                                     │
└─────────────────────────────────────────────────────────────────────┘
                     │
                     ▼
    ┌────────────────────────────────────────────┐
    │ BEGIN TRANSACTION                          │
    │                                            │
    │ 1. SELECT FOR UPDATE (lock row)            │
    │    WHERE user_id = ? AND date = TODAY      │
    │                                            │
    │ 2. Check quota_remaining > 0               │
    │    → No: ROLLBACK, Return 429              │
    │                                            │
    │ 3. UPDATE free_readings_used += 1          │
    │                                            │
    │ 4. COMMIT                                  │
    └────────────────┬───────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 4. PROCESS READING (quota already consumed)                         │
└─────────────────────────────────────────────────────────────────────┘
                     │
                     ▼
    ┌────────────────────────────────────────────┐
    │ Fetch image → Call Gemini AI → Save result│
    │                                            │
    │ IF ERROR:                                  │
    │   • Call refund_quota(user_id)             │
    │   • Return error to client                 │
    └────────────────┬───────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 5. LOG REQUEST & RETURN                                             │
└─────────────────────────────────────────────────────────────────────┘
                     │
                     ▼
    ┌────────────────────────────────────────────┐
    │ INSERT INTO request_log                    │
    │   (idempotency_key, response, created_at)  │
    │                                            │
    │ RETURN response to client                  │
    └────────────────────────────────────────────┘

RESULT: 
✅ Race conditions prevented (row locking)
✅ Duplicate requests handled (idempotency)
✅ Quota consumed before expensive operations
✅ Failed requests refund quota
```

---

## 📊 Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                          iOS CLIENT                                 │
│                                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐            │
│  │DeviceIDMgr   │  │QuotaManager  │  │AIProcessing  │            │
│  │              │  │              │  │Service       │            │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘            │
└─────────┼──────────────────┼──────────────────┼───────────────────┘
          │                  │                  │
          │ device_id        │ user_id          │ image_data
          │                  │                  │
          ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     SUPABASE EDGE FUNCTIONS                         │
│                                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐            │
│  │get_quota     │  │consume_quota │  │process-*     │            │
│  │(wrapper)     │  │(wrapper)     │  │-reading      │            │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘            │
└─────────┼──────────────────┼──────────────────┼───────────────────┘
          │                  │                  │
          │ RPC call         │ RPC call         │ RPC calls
          │                  │                  │
          ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    POSTGRESQL DATABASE                              │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │ FUNCTIONS (RPC)                                              │ │
│  │  • create_guest_user(device_id) → user_id                    │ │
│  │  • get_quota(user_id) → JSON                                 │ │
│  │  • consume_quota(user_id) → JSON                             │ │
│  │  • upsert_subscription(...) → JSON                           │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │ TABLES                                                       │ │
│  │  • users (id, email, device_id, onboarding_completed)        │ │
│  │  • daily_quotas (user_id, date, free_readings_used)          │ │
│  │  • subscriptions (user_id, status, expires_at, product_id)   │ │
│  │  • readings (id, user_id, reading_type, result_text)         │ │
│  └──────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │ External API call
                              ▼
                    ┌──────────────────┐
                    │  GEMINI AI API   │
                    │  (Google)        │
                    └──────────────────┘
```

---

## 🔑 Key Component Interactions

### Quota Check Sequence

```
QuotaManager.fetchQuota()
    ↓
SupabaseService.supabase.rpc("get_quota", params: ["p_user_id": userId])
    ↓
[Network: POST /functions/v1/get_quota]
    ↓
Edge Function: get_quota/index.ts
    ↓
supabaseClient.rpc('get_quota', { p_user_id: activeUserId })
    ↓
PostgreSQL Function: get_quota(p_user_id UUID)
    ↓
Query: SELECT EXISTS(...) FROM subscriptions WHERE user_id = ? AND status = 'active'
    ↓
Query: SELECT free_readings_used FROM daily_quotas WHERE user_id = ? AND date = CURRENT_DATE
    ↓
Return: { quota_used: 1, quota_limit: 3, quota_remaining: 2, is_premium: false }
    ↓
Response propagates back through stack
    ↓
QuotaManager updates @Published properties
    ↓
UI updates automatically (SwiftUI)
```

### Reading Processing Sequence

```
AIProcessingService.processPalmReading()
    ↓
StorageService.uploadImage(imageData) → Returns URL
    ↓
FunctionService.invokeEdgeFunction("process-palm-reading", params)
    ↓
Edge Function: process-palm-reading/index.ts
    ↓
Step 1: supabase.rpc('get_quota', { p_user_id })
         → If quota_remaining <= 0: Return 429
    ↓
Step 2: Query users table for birth data
    ↓
Step 3: Fetch image from Storage and convert to base64
    ↓
Step 4: callGemini(prompt, base64Image) → Returns fortune text
    ↓
Step 5: INSERT INTO readings (user_id, result_text, ...)
    ↓
Step 6: supabase.rpc('consume_quota', { p_user_id })
         ⚠️ VULNERABILITY: Happens AFTER processing!
    ↓
Return: { success: true, result: "fortune text...", ... }
    ↓
AIProcessingService decodes FortuneResult
    ↓
UI displays reading
```

---

## 📈 Database Schema Relationships

```
┌──────────────────────────────────────────────────────────────────────┐
│                            users                                     │
│  • id (UUID, PK) ←─────────────────────────────┐                    │
│  • email (TEXT, UNIQUE)                        │                    │
│  • device_id (TEXT, UNIQUE)                    │                    │
│  • onboarding_completed (BOOLEAN)              │                    │
│  • birth_date, birth_time, birth_city          │                    │
│  • created_at, last_active_at                  │                    │
└──────────────────────────────────────────────────┬──────────────────┘
                                                   │
                    ┌──────────────────────────────┼──────────────────┐
                    │                              │                  │
                    ▼                              ▼                  ▼
         ┌───────────────────┐        ┌────────────────────┐  ┌──────────────┐
         │  daily_quotas     │        │  subscriptions     │  │  readings    │
         │  • user_id (FK)   │        │  • user_id (FK)    │  │  • user_id   │
         │  • date           │        │  • status          │  │  • result... │
         │  • free_readings_ │        │  • expires_at      │  └──────────────┘
         │    used           │        │  • product_id      │
         │  UNIQUE(user_id,  │        │  • transaction_id  │
         │         date)     │        └────────────────────┘
         └───────────────────┘

QUOTA QUERY:
  1. Check subscriptions → is_premium?
  2. Query daily_quotas → free_readings_used
  3. Calculate: 3 - free_readings_used = quota_remaining
```

---

## 🎯 Critical Code Locations

| Component | File | Line | Issue |
|-----------|------|------|-------|
| Race condition | `process-palm-reading/index.ts` | 90-162 | Check quota, then consume later |
| Guest auth vulnerability | `get_quota/index.ts` | 38-63 | No user_id verification |
| Silent failure | `process-palm-reading/index.ts` | 159-162 | Quota error logged, not thrown |
| No row locking | `fortunia.sql` | 173-217 | consume_quota() has no SELECT FOR UPDATE |
| Client cache issue | `QuotaManager.swift` | 38-46 | 5-min cache, no invalidation |
| Premium check redundancy | `20250126_update_quota_functions.sql` | 78-109 | 3 separate premium checks |

---

## 📚 Function Call Tree

```
App Launch
├─ DeviceIDManager.getOrCreateDeviceID()
├─ AuthService.createGuestUser(deviceId)
│  └─ Supabase RPC: create_guest_user(p_device_id)
│     └─ Database: INSERT INTO users (device_id, ...)
└─ QuotaManager.fetchQuota()
   └─ Supabase RPC: get_quota(p_user_id)
      └─ Database Function: get_quota(p_user_id)
         ├─ Query subscriptions (premium check)
         └─ Query daily_quotas (usage check)

User Takes Photo
├─ PhotoCaptureViewModel.processSelectedImage()
│  └─ StorageService.uploadImage(imageData)
│     └─ Supabase Storage: PUT /fortune-images/{path}
└─ AIProcessingService.processPalmReading()
   └─ FunctionService.invokeEdgeFunction("process-palm-reading")
      └─ Edge Function: process-palm-reading/index.ts
         ├─ Database RPC: get_quota(p_user_id)
         ├─ Database Query: SELECT * FROM users WHERE id = ?
         ├─ Storage: Fetch image
         ├─ External API: callGemini()
         ├─ Database: INSERT INTO readings
         └─ Database RPC: consume_quota(p_user_id) ⚠️
            └─ Database Function: consume_quota(p_user_id)
               ├─ Query daily_quotas
               ├─ Check quota_remaining > 0
               └─ UPDATE daily_quotas SET free_readings_used += 1
```

---

**End of Workflow Reference**

