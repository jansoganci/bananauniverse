# Bug Analysis: "Unsupported URL" Error

**Issue:** The iOS app fails to load the result image, displaying an "unsupported URL" error.
**Evidence:**
- iOS Logs: `Error Domain=NSURLErrorDomain Code=-1002 "unsupported URL"`
- Failing URL: `processed/processed/503e74db-9bfc-4379-9b3b-fdf4b3effdec.jpg` (This is a relative path, not a valid URL scheme like `https://`).
- Webhook Logs: `Uploaded to storage ... data:{"fileName":"processed/503e74db-9bfc-4379-9b3b-fdf4b3effdec.jpg"}`
- Realtime Update: `"image_url": "processed/processed/503e74db-9bfc-4379-9b3b-fdf4b3effdec.jpg"`

**Root Cause Analysis:**
1.  **Double `processed/` prefix:** The file name in storage is `processed/503...jpg`. However, the `webhook-handler` updates the database with `processed/${fileName}`. Since `fileName` already contains `processed/`, the path stored in the DB becomes `processed/processed/503...jpg`.
2.  **Missing Signing Logic in Realtime/Get-Result:**
    - The iOS app receives the `image_url` via Supabase Realtime (WebSocket).
    - The value in the DB is a *storage path*, not a *public URL*.
    - The iOS app tries to load this path directly into `AsyncImage` or `Kingfisher`, which fails because it's not a valid URL (`https://...`).
    - The `get-result` Edge Function *does* have logic to sign the URL, but the **Realtime** subscription sends the raw DB row *directly* to the client without invoking the Edge Function.

**Solution Plan:**
1.  **Fix `webhook-handler`:** Prevent double prefixing. If `fileName` already has `processed/`, don't add it again.
2.  **Fix iOS Client:**
    - The iOS client must detect if the `image_url` is a storage path (does not start with `http`).
    - If it is a path, it must request a Signed URL from Supabase Storage *before* trying to display it.
    - Alternatively, we can force the `ResultViewLoader` to call `get-result` (which signs the URL) instead of relying solely on Realtime, OR implement signing in the iOS view model upon receiving the Realtime update.

**Immediate Fixes Required:**
1.  Modify `supabase/functions/webhook-handler/index.ts` to fix the path construction.
2.  Modify `BananaUniverse/Features/ImageProcessing/ViewModels/ImageProcessingViewModel.swift` to sign the URL when receiving a Realtime update.

## Proposed Changes

### 1. Webhook Handler (Backend)
*File:* `supabase/functions/webhook-handler/index.ts`
*Change:*
```typescript
// Before:
const storagePath = `processed/${fileName}`;

// After:
const storagePath = fileName.startsWith('processed/') ? fileName : `processed/${fileName}`;
```

### 2. iOS ViewModel (Frontend)
*File:* `BananaUniverse/Features/ImageProcessing/ViewModels/ImageProcessingViewModel.swift`
*Change:*
When `handleProcessingComplete` is called with a path:
1. Check if `imageUrl` starts with `http`.
2. If NOT, assume it's a storage path.
3. Call `SupabaseService.shared.createSignedUrl(path: imageUrl)` to get a valid `https` URL.
4. Pass this signed URL to the view.

This explains why `get-result` logs weren't showing errors—it wasn't even being called! The app was using the Realtime update which contains the raw path.

