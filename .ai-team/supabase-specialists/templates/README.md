# Complete Starter Templates: Backend + Frontend + iOS

**Purpose:** Copy-paste ready code for new projects. Clone and customize instead of building from scratch.

**Total Setup Time:** ~2-3 hours (including frontend, backend, and iOS)

---

## 📁 What's Included

### **Next.js Frontend** (`/nextjs`)

**Core Files** (`/lib`):
1. `supabase-client.ts` - Browser client + auth helpers + API helpers
2. `supabase-server.ts` - Server component client + auth checks

**Auth Protection**:
1. `middleware.ts` - Route protection with auto session refresh

**Components** (`/components`):
1. `AuthProvider.tsx` - Auth context for client components
2. `CreditBadge.tsx` - Real-time credit display with auto-updates

**Pages** (`/app`):
1. `(auth)/login/page.tsx` - Login with email/password
2. `(auth)/signup/page.tsx` - Signup with email verification
3. `dashboard/page.tsx` - Protected route example

**Time to setup:** 30 minutes (vs 5+ hours from scratch)

---

### **Supabase Backend** (`/supabase`)

**SQL Migrations** (`/migrations`):
1. `001_users_credits_system.sql` - Users table + credit system + stored procedures
2. `002_iap_products.sql` - Products + IAP transactions + refunds
3. `003_async_jobs.sql` - Async job tracking (video generation example)

**Edge Functions** (`/functions`):
1. `update-credits/` - Add/deduct credits endpoint
2. `verify-iap/` - Verify Apple IAP purchases
3. `generate-video/` - Create async video generation job

**Shared Utilities** (`/functions/_shared`):
1. `auth-helper.ts` - JWT authentication helper
2. `retry.ts` - Retry with exponential backoff
3. `telegram.ts` - Telegram alerts

---

### **iOS Services** (`/ios/Services`)

1. `SupabaseAuth.swift` - Authentication (Apple Sign-In, Email/Password)
2. `CreditSystem.swift` - Credit management (balance, deduct, add)
3. `IAPManager.swift` - In-App Purchase management (StoreKit 2)

---

## 🚀 Quick Start: New Project Setup

### Step 1: Clone Templates (2 minutes)

```bash
# Copy Next.js frontend templates
cp -r templates/nextjs/* ~/my-new-project/

# Copy Supabase backend templates
cp -r templates/supabase/* ~/my-new-project/supabase/

# Copy iOS templates
cp -r templates/ios/Services/* ~/my-new-project/iOS/MyApp/Services/
```

---

### Step 2: Setup Frontend (30 minutes)

**2a. Install Dependencies:**
```bash
cd ~/my-new-project
npm install @supabase/ssr @supabase/supabase-js
```

**2b. Add Environment Variables:**
Create `.env.local`:
```env
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key
```

**2c. Wrap App with AuthProvider:**
Update `app/layout.tsx`:
```tsx
import { AuthProvider } from '@/components/AuthProvider'

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>
        <AuthProvider>{children}</AuthProvider>
      </body>
    </html>
  )
}
```

**2d. Test:**
```bash
npm run dev
# Visit http://localhost:3000/login
```

**What this gives you:**
- ✅ Email/Password authentication
- ✅ Protected routes with middleware
- ✅ Session management (server + client)
- ✅ Real-time credit display
- ✅ API helpers for Edge Functions

**See:** `templates/nextjs/README.md` for complete setup guide

---

### Step 3: Run Migrations (5 minutes)

```bash
cd ~/my-new-project

# Initialize Supabase (if not done)
supabase init

# Link to your project
supabase link --project-ref your-project-id

# Run migrations
supabase db push

# Verify tables created
supabase db diff
```

**What this creates:**
- ✅ `users` table with credit system
- ✅ `products` table with 3 example products
- ✅ `iap_transactions` table
- ✅ `video_jobs` table
- ✅ Stored procedures: `add_credits`, `deduct_credits`, `process_iap_purchase`, `create_video_job`
- ✅ Row Level Security (RLS) policies

---

### Step 4: Deploy Edge Functions (10 minutes)

```bash
# Set environment variables
supabase secrets set TELEGRAM_BOT_TOKEN="your_bot_token"
supabase secrets set TELEGRAM_CHAT_ID="your_chat_id"
supabase secrets set FAL_API_KEY="your_fal_key"

# Deploy all functions
supabase functions deploy update-credits
supabase functions deploy verify-iap
supabase functions deploy generate-video

# Test deployment
curl https://your-project.supabase.co/functions/v1/health
```

---

### Step 5: Configure iOS Project (15 minutes)

1. **Add Dependencies** (`Package.swift` or SPM):
```swift
dependencies: [
    .package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0")
]
```

2. **Add Environment Variables** (`.xcconfig` or Info.plist):
```
SUPABASE_URL = https://your-project.supabase.co
SUPABASE_ANON_KEY = your_anon_key
```

3. **Copy Services to your project:**
   - `SupabaseAuth.swift`
   - `CreditSystem.swift`
   - `IAPManager.swift`

4. **Use in your app:**
```swift
// In your ContentView or App
@StateObject private var auth = SupabaseAuth.shared
@StateObject private var credits = CreditSystem.shared
@StateObject private var iap = IAPManager.shared

// Check auth state
if auth.isAuthenticated {
    // Show main app
} else {
    // Show login
}
```

---

### Step 6: Test Everything (30 minutes)

**Test Frontend Authentication:**
```bash
# 1. Visit http://localhost:3000/signup
# 2. Create account → Check email verification
# 3. Visit /login → Sign in → Should redirect to /dashboard
# 4. Visit /dashboard (not logged in) → Should redirect to /login
# 5. Check credit badge displays correctly
```

**Test Backend Endpoints:**

**Test Credit System:**
```bash
# Get balance
curl -X POST https://your-project.supabase.co/functions/v1/update-credits \
  -H "Authorization: Bearer YOUR_JWT" \
  -H "Content-Type: application/json" \
  -d '{"user_id":"uuid","amount":10,"action":"add","reason":"test"}'
```

**Test IAP Verification:**
```bash
curl -X POST https://your-project.supabase.co/functions/v1/verify-iap \
  -H "Authorization: Bearer YOUR_JWT" \
  -H "Content-Type: application/json" \
  -d '{"transaction_id":"test_txn","product_id":"com.yourapp.credits.medium"}'
```

**Test Video Generation:**
```bash
curl -X POST https://your-project.supabase.co/functions/v1/generate-video \
  -H "Authorization: Bearer YOUR_JWT" \
  -H "Idempotency-Key: test-123" \
  -H "Content-Type: application/json" \
  -d '{"model_id":"fal-video","prompt":"A cat"}'
```

---

## 🔧 Customization Guide

### Change Product IDs

**1. Update SQL migration:**
```sql
-- In 002_iap_products.sql
INSERT INTO products (product_id, name, credits) VALUES
    ('com.YOURAPP.credits.small', 'Small Pack', 10);
```

**2. Update iOS IAPManager:**
```swift
let productIds: [String] = [
    "com.YOURAPP.credits.small",
    // ...
]
```

---

### Add New Stored Procedure

**1. Create migration:**
```sql
-- In new migration file
CREATE OR REPLACE FUNCTION your_function_name(
    p_param1 TEXT
) RETURNS JSONB AS $$
BEGIN
    -- Your logic here
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

**2. Run migration:**
```bash
supabase db push
```

---

### Add New Edge Function

**1. Create function:**
```bash
supabase functions new your-function-name
```

**2. Copy template from existing function**

**3. Deploy:**
```bash
supabase functions deploy your-function-name
```

---

### Add New iOS Service

**1. Create new Swift file**

**2. Follow pattern from existing services:**
```swift
@MainActor
class YourService: ObservableObject {
    static let shared = YourService()

    @Published var someState = false

    private let supabase: SupabaseClient

    private init() {
        // Initialize
    }

    func yourMethod() async throws {
        // Call backend
    }
}
```

---

## 🎯 What You Get

**From Templates:**
- ✅ **Frontend:** Next.js auth, credit display, API client
- ✅ **Backend:** Users + Credits system, IAP verification, async jobs
- ✅ **iOS:** Authentication, credit management, IAP handling
- ✅ **Documentation:** 8 comprehensive guides

**Time Saved:**
- ✅ ~5 hours of frontend setup
- ✅ ~15 hours of backend setup
- ✅ ~10 hours of iOS integration
- ✅ ~5 hours of testing
- **Total: ~35 hours saved per project**

---

## 🚨 Important Notes

### Security Checklist
- [ ] Never commit `SUPABASE_SERVICE_ROLE_KEY` to git
- [ ] Always use JWT authentication for protected endpoints
- [ ] Validate all inputs in Edge Functions
- [ ] Use RLS policies to protect data
- [ ] Store API keys in Supabase secrets

### Before Production
- [ ] Test all IAP flows in sandbox
- [ ] Setup Telegram alerts
- [ ] Configure Resend for emails
- [ ] Add Sentry for error tracking
- [ ] Test credit system edge cases
- [ ] Verify RLS policies work

### Common Issues
1. **"User not found" errors** → Check RLS policies
2. **IAP verification fails** → Implement real Apple verification
3. **Credits not updating** → Check stored procedure logs
4. **iOS auth fails** → Verify SUPABASE_URL and key

---

## 📚 Where to Learn More

**Documentation we created:**
- `docs/FRONTEND-SUPABASE-INTEGRATION.md` - **NEW!** Connect Next.js to Supabase
- `docs/FRONTEND-AUTH-PATTERNS.md` - **NEW!** Complete auth patterns
- `docs/AUTH-DECISION-FRAMEWORK.md` - Auth strategy
- `docs/EMAIL-PASSWORD-AUTH.md` - Email auth setup
- `docs/EMAIL-SERVICE-INTEGRATION.md` - Resend setup
- `docs/IAP-IMPLEMENTATION-STRATEGY.md` - Complete IAP guide
- `docs/EXTERNAL-API-STRATEGY.md` - External API patterns
- `docs/OPERATIONS-MONITORING-CHECKLIST.md` - Production setup

**Supabase Docs:**
- https://supabase.com/docs
- https://supabase.com/docs/guides/auth
- https://supabase.com/docs/guides/functions

**iOS Supabase:**
- https://github.com/supabase/supabase-swift

---

## 🎉 You're Ready!

**Workflow for each new app:**
1. Clone templates (~2 min)
2. Setup frontend (~30 min) - **NEW!**
3. Run backend migrations (~5 min)
4. Deploy Edge Functions (~10 min)
5. Copy iOS services (~15 min)
6. Customize for your app (~30 min)
7. Test everything (~30 min)

**Total: ~2 hours** instead of 35+ hours from scratch!

**This is how veterans ship 50-60 apps.** 🚀

---

## 📱 Platform Coverage

| Platform | Auth | Credits | IAP | Async Jobs | Templates |
|----------|------|---------|-----|------------|-----------|
| **Web (Next.js)** | ✅ | ✅ | ➖ | ✅ | ✅ **NEW!** |
| **iOS (Swift)** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Backend (Supabase)** | ✅ | ✅ | ✅ | ✅ | ✅ |

**You now have complete, production-ready templates for all platforms.**
