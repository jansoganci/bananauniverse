# Credit Loading Flow Analysis

## When App Opens - Step by Step

### Step 1: App Launch (BananaUniverseApp.swift)
```swift
.task {
    await CreditManager.shared.initializeNewUser()
}
```
**What happens:** App calls `initializeNewUser()` when ContentView appears

---

### Step 2: CreditManager Initialization (Singleton)
```swift
private init() {
    loadUserState()           // Loads user state from UserDefaults
    loadCachedQuota()         // ⚡ LOADS FROM CACHE FIRST
    scheduleBackgroundRefresh()
    QuotaCache.shared.migrateFromV1IfNeeded()
}
```
**What happens:**
- `loadCachedQuota()` reads from UserDefaults cache
- Sets `creditsRemaining = cached.creditsRemaining` (e.g., 3 credits)
- **UI IMMEDIATELY SHOWS CACHED VALUE** (3 credits)
- This happens **synchronously** - no network call yet

**From your logs:**
```
💾 [CACHE] Loaded: 3 credits, stale: true
📊 [CREDITS] Balance: 10 → 3
📱 [CREDITS] Loaded from cache: 3 credits
```

---

### Step 3: Backend Request (Async)
```swift
func initializeNewUser() async {
    await loadQuota()  // Makes network call
}
```

**What happens:**
1. Calls `QuotaService.shared.getQuota()` 
2. Makes RPC call to backend: `get_credits(p_user_id, p_device_id)`
3. Backend returns credit balance (e.g., 0 credits)

**From your logs:**
```
❌ [CREDITS] Load failed: Network error  // First attempt failed
🔄 [CREDITS] Backend sync: 3 → 0        // Later attempt succeeded
```

---

### Step 4: Update Frontend (When Backend Responds)
```swift
await updateCredits(remaining: creditInfo.creditsRemaining)
```

**What happens:**
1. `updateCredits()` is called with backend value (e.g., 0)
2. Saves to cache: `QuotaCache.shared.save(creditsRemaining: 0)`
3. Updates UI: `creditsRemaining = 0` (triggers `@Published` update)

**From your logs:**
```
💾 [CACHE] Saved: 0 credits
📊 [CREDITS] Balance: 3 → 0
```

---

## The Problem: Two-Step Loading

### Current Flow:
```
1. App Opens
   ↓
2. Load Cache (INSTANT) → UI shows 3 credits ⚡
   ↓
3. Request Backend (ASYNC) → Network call
   ↓
4. Backend Responds → UI updates to 0 credits
```

### Issues:
1. **UI shows stale cache first** (3 credits)
2. **Network might fail** → UI stays with stale cache
3. **User sees wrong number** until backend responds
4. **No loading indicator** - user doesn't know it's syncing

---

## What Should Happen

### Option 1: Show Loading State
```
1. App Opens
   ↓
2. Show "Loading..." or spinner
   ↓
3. Request Backend
   ↓
4. Backend Responds → Show actual credits
```

### Option 2: Optimistic UI (Current, but better)
```
1. App Opens
   ↓
2. Show cached value (optimistic)
   ↓
3. Request Backend in background
   ↓
4. Silently update when backend responds
   ↓
5. If network fails, keep cached value but mark as "stale"
```

---

## Current Implementation Details

### When Frontend Updates:
- **Immediately:** From cache (synchronous)
- **Later:** From backend response (async, when network succeeds)

### Does Frontend Update?
✅ **YES** - But in two steps:
1. First: Shows cached value (instant)
2. Second: Updates to backend value (when network responds)

### The Problem:
- If network fails, frontend keeps showing **stale cache**
- User doesn't know it's stale
- User might try to use credits that don't exist

---

## Recommendations

1. **Add Loading Indicator:**
   - Show spinner while fetching from backend
   - Hide when backend responds

2. **Show Stale Indicator:**
   - If cache is stale, show "Syncing..." badge
   - Or show cached value with warning icon

3. **Better Error Handling:**
   - If network fails, show "Unable to sync credits"
   - Let user retry manually

4. **Refresh Before Critical Actions:**
   - ✅ Already fixed: Refresh before generate button
   - This ensures backend balance is checked

