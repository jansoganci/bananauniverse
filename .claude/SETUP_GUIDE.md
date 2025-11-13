# Complete Setup Guide

Step-by-step guide to set up BananaUniverse for development and production.

## Prerequisites

### Required Tools

- **Xcode 15.0+** (iOS development)
- **Supabase CLI** (backend setup)
- **Node.js 18+** (for Supabase CLI)
- **Git** (version control)

### Required Accounts

- **Supabase Account** (free tier works)
- **fal.ai Account** (for AI processing)
- **Adapty Account** (optional, for analytics)
- **App Store Connect** (for subscriptions)

---

## Step 1: Clone and Setup Repository

```bash
# Clone repository
git clone https://github.com/jansoganci/banana.universe.git
cd banana.universe

# Verify Xcode project opens
open BananaUniverse.xcodeproj
```

---

## Step 2: Supabase Setup

### 2.1 Create Supabase Project

1. Go to [supabase.com](https://supabase.com)
2. Create new project
3. Note down:
   - Project URL
   - Anon Key (public key)
   - Service Role Key (secret, for Edge Functions)

### 2.2 Install Supabase CLI

```bash
# Install via Homebrew (macOS)
brew install supabase/tap/supabase

# Or via npm
npm install -g supabase
```

### 2.3 Initialize Supabase Locally

```bash
# Link to your Supabase project
supabase link --project-ref your-project-ref

# Start local Supabase
supabase start

# This will output:
# - API URL: http://localhost:54321
# - Anon Key: (your local anon key)
# - Service Role Key: (your local service role key)
```

### 2.4 Run Database Migrations

```bash
# Apply all migrations
supabase db reset

# This creates all tables, functions, and RLS policies
```

### 2.5 Create Storage Bucket

1. Go to Supabase Dashboard → Storage
2. Create new bucket: `noname-banana-images-prod`
3. Set to **Public** (for public image URLs)
4. Configure RLS policies (if needed)

---

## Step 3: Configure iOS App

### 3.1 Update Info.plist

Add your Supabase credentials to `Info.plist`:

```xml
<key>SUPABASE_URL</key>
<string>https://your-project.supabase.co</string>

<key>SUPABASE_ANON_KEY</key>
<string>your-anon-key-here</string>
```

**Or via Build Settings:**

1. Select project in Xcode
2. Go to Build Settings
3. Add User-Defined Settings:
   - `INFOPLIST_KEY_SUPABASE_URL` = `your-project-url`
   - `INFOPLIST_KEY_SUPABASE_ANON_KEY` = `your-anon-key`

### 3.2 Verify Config.swift

Check that `Config.swift` reads from Info.plist correctly:

```swift
static let supabaseURL: String = {
    guard let url = infoPlistValue(for: "SUPABASE_URL") else {
        fatalError("SUPABASE_URL not found in Info.plist")
    }
    return url
}()
```

---

## Step 4: Deploy Edge Functions

### 4.1 Set Environment Variables

```bash
# Set fal.ai API key
supabase secrets set FAL_KEY=your-fal-ai-key

# Verify secrets
supabase secrets list
```

### 4.2 Deploy Process Image Function

```bash
# Deploy to production
supabase functions deploy process-image

# Verify deployment
supabase functions list
```

### 4.3 Test Edge Function Locally

```bash
# Serve locally
supabase functions serve process-image

# Test with curl
curl -X POST http://localhost:54321/functions/v1/process-image \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "https://example.com/test.jpg",
    "prompt": "Test prompt"
  }'
```

---

## Step 5: Configure fal.ai

### 5.1 Get API Key

1. Go to [fal.ai](https://fal.ai)
2. Sign up/login
3. Get API key from dashboard

### 5.2 Set in Supabase

```bash
supabase secrets set FAL_KEY=your-fal-ai-key
```

### 5.3 Verify in Edge Function

The Edge Function automatically uses `FAL_KEY` from environment variables.

---

## Step 6: Configure Adapty (Optional)

### 6.1 Create Adapty Project

1. Go to [adapty.io](https://adapty.io)
2. Create new project
3. Get API key

### 6.2 Configure Webhook

1. In Adapty dashboard, set webhook URL:
   ```
   https://your-project.supabase.co/functions/v1/sync-subscription
   ```

2. Deploy sync-subscription function (if exists):
   ```bash
   supabase functions deploy sync-subscription
   ```

### 6.3 Update iOS App

Add Adapty API key to `Config.swift` or Info.plist:

```swift
static let adaptyAPIKey = "your-adapty-key"
```

---

## Step 7: Configure StoreKit 2

### 7.1 Create Products in App Store Connect

1. Go to App Store Connect → Your App → In-App Purchases
2. Create subscription products:
   - **Weekly Pro**: `weekly_pro` ($4.99/week)
   - **Yearly Pro**: `yearly_pro` ($79.99/year)

### 7.2 Configure StoreKit Configuration File

1. In Xcode, add `BananaUniverse.storekit` file
2. Configure products:
   - Product IDs must match App Store Connect
   - Set prices and durations

### 7.3 Test in Xcode

1. Select scheme: "BananaUniverse (StoreKit Configuration)"
2. Run app
3. Test purchases in sandbox mode

---

## Step 8: Build and Run

### 8.1 Clean Build

```bash
# In Xcode: Cmd + Shift + K
```

### 8.2 Build Project

```bash
# In Xcode: Cmd + B
```

### 8.3 Run on Simulator

```bash
# In Xcode: Cmd + R
```

---

## Step 9: Verify Setup

### 9.1 Test Authentication

- [ ] Anonymous authentication works
- [ ] Email signup works
- [ ] Email login works
- [ ] Sign out works

### 9.2 Test Image Processing

- [ ] Upload image works
- [ ] Image processing completes
- [ ] Processed image displays
- [ ] Quota updates correctly

### 9.3 Test Quota System

- [ ] Free user gets 5 requests/day
- [ ] Premium user gets 3 requests/day
- [ ] Quota resets at midnight UTC
- [ ] Paywall shows when quota exceeded

### 9.4 Test Subscriptions

- [ ] Products load correctly
- [ ] Purchase flow works
- [ ] Subscription status syncs
- [ ] Premium features unlock

---

## Production Deployment

### 1. Update Environment Variables

```bash
# Set production secrets
supabase secrets set FAL_KEY=prod-key
supabase secrets set SUPABASE_URL=prod-url
```

### 2. Deploy Migrations

```bash
# Push migrations to production
supabase db push
```

### 3. Deploy Edge Functions

```bash
# Deploy all functions
supabase functions deploy
```

### 4. Archive iOS App

1. In Xcode: Product → Archive
2. Upload to App Store Connect
3. Submit for review

---

## Troubleshooting

### Common Issues

**Issue: Supabase connection fails**
- Check `SUPABASE_URL` and `SUPABASE_ANON_KEY` in Info.plist
- Verify network connectivity
- Check Supabase project is active

**Issue: Edge Function timeout**
- Check `FAL_KEY` is set correctly
- Verify fal.ai API is accessible
- Check function logs: `supabase functions logs process-image`

**Issue: Quota not updating**
- Check RLS policies are correct
- Verify `daily_quota` table exists
- Check function `consume_quota` is working

**Issue: Images not uploading**
- Check storage bucket exists: `noname-banana-images-prod`
- Verify bucket is public
- Check RLS policies on bucket

**Issue: Subscriptions not working**
- Verify products exist in App Store Connect
- Check product IDs match StoreKit configuration
- Test in sandbox mode first

---

## Environment-Specific Configuration

### Development

```swift
// Use local Supabase
static let supabaseURL = "http://localhost:54321"
static let supabaseAnonKey = "local-anon-key"
```

### Staging

```swift
// Use staging Supabase project
static let supabaseURL = "https://staging-project.supabase.co"
```

### Production

```swift
// Use production Supabase project
static let supabaseURL = "https://prod-project.supabase.co"
```

---

## Security Checklist

- [ ] Service role key is never exposed in client code
- [ ] RLS policies are enabled on all tables
- [ ] Edge Functions validate authentication
- [ ] API keys are stored securely (Info.plist, not hardcoded)
- [ ] Storage bucket has proper RLS policies
- [ ] Subscription validation happens server-side

---

## Next Steps

After setup is complete:

1. Review `ARCHITECTURE.md` for code structure
2. Read `DESIGN_SYSTEM.md` for UI guidelines
3. Check `WORKFLOWS.md` for development practices
4. Explore `API_REFERENCE.md` for API documentation

---

## Support

If you encounter issues:

1. Check Supabase logs: Dashboard → Logs
2. Check Edge Function logs: `supabase functions logs`
3. Review migration files in `supabase/migrations/`
4. Check Xcode console for iOS errors

