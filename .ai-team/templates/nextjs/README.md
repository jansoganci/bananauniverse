# 🚀 Next.js + Supabase Starter Template

**Production-ready authentication and credit system for solo developers**

Clone this, customize 10%, deploy in 30 minutes.

---

## 🎯 What You Get

This template provides everything you need to start building your Supabase-powered web app:

### ✅ **Authentication (Ready to Use)**
- Email/Password login with Supabase Auth
- Email verification built-in
- Password reset flow
- Protected routes with middleware
- Session management (client + server)

### ✅ **Credit System Integration**
- Real-time credit balance display
- Credit badge component with auto-updates
- API helpers for credit operations
- Connects to your Supabase backend

### ✅ **Server + Client Components**
- Server-side auth checks (fast, secure)
- Client-side auth context (reactive)
- Proper cookie handling
- Next.js 14 App Router patterns

### ✅ **Copy-Paste Ready**
- 9 files total
- No configuration needed
- Just update environment variables
- Deploy to Vercel in one click

---

## 📁 What's Included

```
nextjs/
├── lib/
│   ├── supabase-client.ts       # Browser client + auth helpers
│   └── supabase-server.ts       # Server component client
├── middleware.ts                 # Route protection
├── components/
│   ├── AuthProvider.tsx         # Auth context for client
│   └── CreditBadge.tsx          # Real-time credit display
├── app/
│   ├── (auth)/
│   │   ├── login/page.tsx       # Login page
│   │   └── signup/page.tsx      # Signup page
│   └── dashboard/page.tsx       # Protected route example
└── README.md                     # You are here
```

**9 files. 30 minutes. Production-ready.**

---

## 🚀 Quick Start (30 minutes)

### Step 1: Copy Files (5 min)

```bash
# Copy all template files to your Next.js project
cp -r nextjs/* your-nextjs-app/

# Or manually copy each file to the correct location
```

### Step 2: Install Dependencies (5 min)

```bash
cd your-nextjs-app

npm install @supabase/ssr @supabase/supabase-js
```

### Step 3: Add Environment Variables (2 min)

Create `.env.local`:

```env
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
```

**Get these from:** Supabase Dashboard → Settings → API

### Step 4: Update Imports (5 min)

All template files use `@/` imports. Make sure your `tsconfig.json` has:

```json
{
  "compilerOptions": {
    "paths": {
      "@/*": ["./*"]
    }
  }
}
```

### Step 5: Wrap App with AuthProvider (3 min)

Update your `app/layout.tsx`:

```tsx
import { AuthProvider } from '@/components/AuthProvider'

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>
        <AuthProvider>
          {children}
        </AuthProvider>
      </body>
    </html>
  )
}
```

### Step 6: Test (10 min)

```bash
npm run dev
```

Visit:
- `http://localhost:3000/signup` - Create account
- `http://localhost:3000/login` - Sign in
- `http://localhost:3000/dashboard` - Protected page (redirects if not logged in)

**Done! 🎉**

---

## 📚 Usage Examples

### Using Auth in Client Components

```tsx
'use client'
import { useAuth } from '@/components/AuthProvider'

export function MyComponent() {
  const { user, loading } = useAuth()

  if (loading) return <div>Loading...</div>
  if (!user) return <div>Please sign in</div>

  return <div>Hello {user.email}!</div>
}
```

### Using Auth in Server Components

```tsx
import { getUser } from '@/lib/supabase-server'
import { redirect } from 'next/navigation'

export default async function ProfilePage() {
  const user = await getUser()

  if (!user) {
    redirect('/login')
  }

  return <div>Server-side auth: {user.email}</div>
}
```

### Calling Your Edge Functions

```tsx
'use client'
import { api } from '@/lib/supabase-client'

// Deduct credits
await api.updateCredits('deduct', 5, 'Video generation')

// Generate video (custom function)
const result = await api.generateVideo('A cool video', 'theme-123')

// Call any Edge Function
const data = await api.invoke('my-function', { foo: 'bar' })
```

### Displaying Credits

```tsx
import { CreditBadge } from '@/components/CreditBadge'

export function Header() {
  return (
    <header>
      <nav>
        <CreditBadge /> {/* Shows: "42 credits" with auto-update */}
      </nav>
    </header>
  )
}
```

---

## 🔒 Protected Routes

The middleware automatically protects these routes:

- `/dashboard/*` - Redirects to `/login` if not authenticated
- `/profile/*` - Redirects to `/login` if not authenticated
- `/settings/*` - Redirects to `/login` if not authenticated

**To add more protected routes**, edit `middleware.ts`:

```typescript
const protectedPaths = ['/dashboard', '/profile', '/settings', '/admin']
```

---

## 🎨 Customization

### Change Redirect After Login

Edit `app/(auth)/login/page.tsx`:

```typescript
const redirectTo = searchParams.get('redirect') || '/my-custom-page'
```

### Add More Auth Methods

```typescript
// lib/supabase-client.ts
export const auth = {
  signInWithGoogle: async () => {
    return await supabase.auth.signInWithOAuth({ provider: 'google' })
  },
  // ... add more
}
```

### Style the Pages

All pages use Tailwind CSS. Customize classes directly:

```tsx
// Change button color in login/page.tsx
className="bg-blue-600 hover:bg-blue-700"
// To:
className="bg-purple-600 hover:bg-purple-700"
```

---

## 🚀 Deploy to Vercel (5 minutes)

1. **Push to GitHub**
   ```bash
   git add .
   git commit -m "Add Next.js starter template"
   git push
   ```

2. **Import to Vercel**
   - Go to [vercel.com](https://vercel.com)
   - Click "Import Project"
   - Select your repository
   - Add environment variables (copy from `.env.local`)
   - Click "Deploy"

3. **Done!** Your app is live.

---

## 🔗 Connect to Backend

This frontend template works with the Supabase backend templates:

**Backend Setup (if not done yet):**
1. Run migrations from `templates/supabase/migrations/`
2. Deploy Edge Functions from `templates/supabase/functions/`
3. Update environment variables

**See:** `templates/README.md` for complete backend setup

---

## 📖 How It Works

### Authentication Flow

1. **User signs up** → Supabase creates account + sends verification email
2. **User logs in** → JWT stored in cookies (httpOnly, secure)
3. **Middleware checks auth** → Refreshes session, protects routes
4. **Components use auth** → Via `useAuth()` hook or `getUser()` function

### Credit System Flow

1. **Component mounts** → Fetch credits from `users` table
2. **Subscribe to changes** → Real-time updates via Supabase Realtime
3. **Display badge** → Auto-updates when credits change
4. **Call Edge Function** → Credits deducted in backend, UI updates instantly

### Server vs Client

**Server Components (default):**
- Use `createClient()` from `supabase-server.ts`
- Fast, secure, no JavaScript sent to browser
- Good for: Data fetching, auth checks, initial page load

**Client Components ('use client'):**
- Use `supabase` from `supabase-client.ts`
- Interactive, reactive
- Good for: Forms, real-time updates, user interactions

---

## 🎯 Next Steps

### Phase 1: Setup (Current)
- [x] Copy template files ✅
- [x] Add environment variables ✅
- [x] Test authentication ✅
- [ ] **YOU: Customize styling** ← Next!
- [ ] **YOU: Add your features**

### Phase 2: Customize
- [ ] Update branding and colors
- [ ] Add your logo
- [ ] Customize email templates in Supabase
- [ ] Add profile page
- [ ] Add settings page

### Phase 3: Deploy
- [ ] Push to GitHub
- [ ] Deploy to Vercel
- [ ] Set up custom domain
- [ ] Configure production environment variables

---

## 🛠 Troubleshooting

**"Cannot find module '@/lib/supabase-client'"**
- Check `tsconfig.json` has `"@/*": ["./*"]` in paths
- Restart your dev server

**"Invalid JWT"**
- Check environment variables are correct
- Make sure you're using the **anon key**, not the service role key

**Protected routes not redirecting**
- Check `middleware.ts` is in the root of your app
- Verify the `matcher` config includes your routes

**Credits not updating**
- Check Realtime is enabled in Supabase Dashboard → Database → Replication
- Verify `users` table has RLS policies allowing SELECT

**TypeScript errors**
- Run `npm install --save-dev @types/node`
- Update `tsconfig.json` with correct types

---

## 📚 Additional Resources

- [Next.js 14 Docs](https://nextjs.org/docs)
- [Supabase Auth Docs](https://supabase.com/docs/guides/auth)
- [Supabase SSR Guide](https://supabase.com/docs/guides/auth/server-side)
- [Backend Templates](../README.md) - Complete Supabase backend setup

---

## 🤝 Philosophy

**Clone, don't generate.**

Veteran developers ship 50-60 apps because they have templates. This is your template.

- ✅ Copy-paste ready code
- ✅ Battle-tested patterns
- ✅ Minimal customization (change 10%, keep 90%)
- ✅ Deploy in 30 minutes, not 30 hours

**This is NOT for building Uber, Airbnb, or Amazon.**

This is for solo developers who want to ship sustainable, secure systems quickly.

---

## 📄 License

Proprietary - All rights reserved. AI Team of Jans © 2025

---

## 🚀 Ready to Build?

1. **Copy the files** (5 min)
2. **Add environment variables** (2 min)
3. **Test locally** (10 min)
4. **Customize** (as needed)
5. **Deploy** (5 min)
6. **Ship your app** 🎉

**Total time: 30 minutes from zero to deployed authentication.**

---

**Built for: Solo developers who want to move fast**
**Goal: Stop reinventing auth, ship production code**
**Time to deploy: 30 minutes**

Happy Building! 🚀✨
