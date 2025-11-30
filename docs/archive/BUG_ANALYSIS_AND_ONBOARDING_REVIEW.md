# Bug Analysis & Onboarding Review

## 1. Image Processing Failure (422 Error)
**Issue:** Fal.ai returned a `file_download_error` because it received a raw storage path (`uploads/...`) instead of a publicly accessible (or signed) URL.
**Evidence:** 
```json
"image_urls": [
    "uploads/705048225038102432/0E29CDC3-06E1-467A-B862-ABB3E28DF278.jpg"
]
```
**Root Cause:** 
In `submit-job/index.ts`, the logic to convert paths to Signed URLs is present, but it seems the request body provided by the user log indicates that the *raw path* was passed. 
If the code `const signedImageUrls = await Promise.all(...)` executed correctly, `image_urls` sent to Fal.ai should have been signed.
However, looking closer at `submit-job/index.ts`:
```typescript
// Normalize image URLs (support both single and array)
const normalizedImageUrls = image_urls || (image_url ? [image_url] : []);
```
Then later:
```typescript
const signedImageUrls = await Promise.all(image_urls.map(async (urlOrPath) => { ...
```
**Bug Found:** The variable `image_urls` in the `Promise.all` map might be referring to the raw input `image_urls` which could be undefined if `normalizedImageUrls` was derived from `image_url`.
*Correction:* The code uses `image_urls` (the raw input param) instead of `normalizedImageUrls`. If the client sent `image_url` (singular), then `image_urls` (plural) is undefined, and `image_urls.map` would crash or behave unexpectedly if not handled.
*Wait,* the user log shows `image_urls` (plural) WAS sent. So `image_urls.map` should work.
**Real Issue:** The input provided in the prompt (`input: { ... "image_urls": ["uploads/..."] ... }`) is what Fal.ai *received*. This means `submit-job` sent "uploads/..." to Fal.ai.
This implies the `createSignedUrl` function might have returned the path itself, or the logic `if (urlOrPath.startsWith('http'))` failed?
No, `uploads/...` does not start with `http`.
**Likely Suspect:** The `createSignedUrl` function in `submit-job` might be failing to match the path correctly or returning the original string on error (though the code says it throws). 
**Hypothesis:** The buckets are now private (RLS). The Edge Function uses `SUPABASE_SERVICE_ROLE_KEY`. It *should* have access.
**Critical Fix:** We need to ensure `submit-job` strictly validates that `signedUrl` is returned and log exactly what it sends to Fal.ai.

## 2. Credit Refund Failure
**Issue:** Credits are not refunded when Fal.ai fails.
**Evidence:**
```
"error": "Could not find the function public.add_credits(p_amount, p_device_id, p_idempotency_key, p_user_id) in the schema cache"
```
**Root Cause:** The database function `add_credits` does not exist. We removed it in favor of `submit_job_atomic` (which handles deduction), but we forgot to re-add a refund mechanism or kept the old `add_credits` call in the error handler without defining the function.
**Solution:** We must create the `add_credits` RPC to allow the system to return credits on failure.

## 3. Anonymous Auth Failure (500 Error)
**Issue:** `signInAnonymously` fails with "Database error creating anonymous user".
**Evidence:** 
Xcode logs: `api(message: "Database error creating anonymous user", errorCode: Auth.ErrorCode(rawValue: "unexpected_failure")`
**Root Cause:** This is often caused by a database trigger on the `auth.users` table that is failing.
*Investigation:* Did we add a trigger to `auth.users`? We added `cleanup-anonymous-users` cron job, but that's a scheduled task.
*Alternative:* It could be related to the `captcha` settings if enabled in the dashboard but not supported by the client.
*However*, the user mentioned "I went to supabase -> settings -> auth -> and activate anon users".
**Action:** Check for any triggers on `auth.users`. If none, this might be a transient Supabase issue or a configuration mismatch. But mostly likely, it's a **trigger** failing.

## 4. Onboarding Analysis
**Files Analyzed:** `BananaUniverseApp.swift`, `OnboardingViewModel.swift`

**1. Are onboarding screens designed for our process?**
*   **Yes.** The screens cover:
    *   **Welcome:** Basic intro.
    *   **How It Works:** Explains the process.
    *   **Credits:** "Start with 10 Free Credits" - matches the 10 credits we give.
    *   **Data Policy:** "Important: Save Your Images" - matches the new Snapchat-style logic (save or lose).
*   *Verdict:* The content is aligned with the current app logic.

**2. Do first-time users see it?**
*   **Yes.** `BananaUniverseApp.swift` uses `@AppStorage("hasSeenOnboarding")`.
*   Logic:
    ```swift
    if !hasSeenOnboarding {
        showOnboarding = true
    }
    ```
*   This ensures any user who hasn't set this flag (new installs) sees it.

**3. Do users see it again if they skip/finish?**
*   **No.**
*   Logic in `OnboardingViewModel.swift`:
    ```swift
    func complete() { ... } // Dismisses sheet
    func skip() { ... } // Dismisses sheet
    ```
    And `BananaUniverseApp.swift` only shows it if `!hasSeenOnboarding`.
*   *Correction:* The `hasSeenOnboarding` flag is set to `true` in `OnboardingView.onAppear` (referenced in comments). If the user *sees* it, they won't see it again, even if they force quit.
*   *Precaution:* If a user deletes and reinstalls the app, `AppStorage` (UserDefaults) is wiped. They **will** see onboarding again. However, their `StableID` might persist in Keychain/iCloud, so they will log in as the *same* user (restoring credits), but technically they are a "new install" so showing onboarding again is correct behavior.

## Recommended Actions (Do Not Implement Yet)

1.  **Fix `submit-job`:** Ensure `image_urls` map correctly handles the input and `createSignedUrl` works. The log suggests the input to Fal was raw paths.
2.  **Create `add_credits` RPC:** This is critical for refunds.
3.  **Investigate Auth 500:** Check `auth.users` triggers.

