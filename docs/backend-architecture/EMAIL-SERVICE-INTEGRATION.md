# Email Service Integration with Resend

**Purpose:** Simple, secure email integration for Supabase backends using Resend (free tier: 3,000 emails/month).

**Generated:** 2025-01-15

**Target:** Solo developers, vibe coders, sustainable systems

---

## 🎯 Why Resend?

**Simple choice for solo devs:**
- ✅ Free tier: 3,000 emails/month (plenty for MVP)
- ✅ 5-minute setup
- ✅ Clean API
- ✅ Works perfectly with Supabase Auth
- ✅ No credit card required for free tier
- ✅ Great deliverability

**Not Choosing:**
- ❌ SendGrid (more complex, enterprise focus)
- ❌ AWS SES (harder setup, AWS complexity)
- ❌ Mailgun (overkill for simple needs)

---

## 📋 Setup Checklist

### Step 1: Create Resend Account (2 minutes)

- [ ] Go to https://resend.com
- [ ] Sign up (free, no credit card)
- [ ] Verify your email
- [ ] Copy your API key from dashboard

### Step 2: Connect Resend to Supabase (3 minutes)

- [ ] Open your Supabase project dashboard
- [ ] Go to **Authentication → Email Templates**
- [ ] Click **Settings** tab
- [ ] Find **SMTP Settings** section
- [ ] Enter Resend SMTP credentials:

```
SMTP Host: smtp.resend.com
SMTP Port: 587
SMTP Username: resend
SMTP Password: <YOUR_RESEND_API_KEY>
Sender Email: noreply@yourdomain.com (or onboarding@resend.dev for testing)
Sender Name: Your App Name
```

- [ ] Click **Save**
- [ ] Send test email to verify

### Step 3: Configure Email Templates (5 minutes)

Supabase has **3 built-in email templates**. Customize them:

#### A. Confirm Signup (Email Verification)

Default template location: **Authentication → Email Templates → Confirm Signup**

**Simple Template:**
```html
<h2>Welcome to {{ .SiteURL }}!</h2>
<p>Click the link below to verify your email:</p>
<p><a href="{{ .ConfirmationURL }}">Verify Email</a></p>
<p>If you didn't sign up, ignore this email.</p>
```

- [ ] Customize with your app name and branding
- [ ] Keep it simple and clean
- [ ] Test by signing up a new user

#### B. Magic Link (Optional, for passwordless login)

Default template location: **Authentication → Email Templates → Magic Link**

**Simple Template:**
```html
<h2>Sign in to {{ .SiteURL }}</h2>
<p>Click the link below to sign in:</p>
<p><a href="{{ .ConfirmationURL }}">Sign In</a></p>
<p>This link expires in 1 hour.</p>
<p>If you didn't request this, ignore this email.</p>
```

- [ ] Customize if you want passwordless login
- [ ] Otherwise, skip this (not needed for basic email/password)

#### C. Reset Password

Default template location: **Authentication → Email Templates → Reset Password**

**Simple Template:**
```html
<h2>Reset Your Password</h2>
<p>Click the link below to reset your password:</p>
<p><a href="{{ .ConfirmationURL }}">Reset Password</a></p>
<p>This link expires in 1 hour.</p>
<p>If you didn't request this, ignore this email.</p>
```

- [ ] Customize with your app name
- [ ] Keep it simple
- [ ] Test by using "Forgot Password"

### Step 4: Add Custom Transactional Emails (Optional)

For emails NOT handled by Supabase Auth (purchase confirmations, low balance warnings), create simple templates:

#### Purchase Confirmation Email

Create a simple function to send via Resend API:

```typescript
// _shared/email.ts
import { createClient } from '@supabase/supabase-js'

export async function sendPurchaseConfirmation(
  userEmail: string,
  productName: string,
  credits: number
) {
  const resendApiKey = Deno.env.get('RESEND_API_KEY')!

  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${resendApiKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      from: 'noreply@yourdomain.com',
      to: userEmail,
      subject: 'Purchase Confirmed',
      html: `
        <h2>Thank you for your purchase!</h2>
        <p>You've successfully purchased: <strong>${productName}</strong></p>
        <p>Credits added: <strong>${credits}</strong></p>
        <p>Start creating now!</p>
      `
    })
  })

  if (!response.ok) {
    console.error('Failed to send email:', await response.text())
  }
}
```

**Usage in IAP verification:**
```typescript
// After successful purchase
await sendPurchaseConfirmation(
  user.email,
  '50 Credit Pack',
  50
)
```

#### Low Balance Warning Email

```typescript
export async function sendLowBalanceWarning(
  userEmail: string,
  creditsRemaining: number
) {
  const resendApiKey = Deno.env.get('RESEND_API_KEY')!

  await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${resendApiKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      from: 'noreply@yourdomain.com',
      to: userEmail,
      subject: 'Running Low on Credits',
      html: `
        <h2>You're running low on credits</h2>
        <p>You have <strong>${creditsRemaining} credits</strong> remaining.</p>
        <p>Purchase more to keep creating!</p>
        <p><a href="https://yourapp.com/store">Get More Credits</a></p>
      `
    })
  })
}
```

**Trigger automatically when credits < 5:**
```typescript
// After deducting credits
if (user.credits_remaining < 5 && user.credits_remaining > 0) {
  await sendLowBalanceWarning(user.email, user.credits_remaining)
}
```

### Step 5: Store Resend API Key in Supabase Secrets

```bash
# Add to Supabase secrets (if sending custom emails)
supabase secrets set RESEND_API_KEY="re_your_api_key_here"
```

- [ ] Run command in terminal
- [ ] Verify secret is set in Supabase dashboard

### Step 6: Test Email Delivery

**Test Supabase Auth Emails:**
- [ ] Sign up new user → Should receive verification email
- [ ] Use "Forgot Password" → Should receive reset email
- [ ] Check spam folder if not received
- [ ] Verify links work correctly

**Test Custom Emails (if added):**
```bash
# Test purchase confirmation
curl -X POST "https://your-project.supabase.co/functions/v1/test-email" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email":"your@email.com"}'
```

- [ ] Send test email
- [ ] Check inbox
- [ ] Verify formatting looks good
- [ ] Check spam score (Resend dashboard)

---

## 🔐 Security Checklist

- [ ] Never expose Resend API key to client
- [ ] Store API key in Supabase secrets only
- [ ] Use server-side Edge Functions for custom emails
- [ ] Rate limit email sending (prevent abuse)
- [ ] Validate email addresses before sending
- [ ] Don't send sensitive data in emails (only confirmation links)

---

## 📊 Email Event Tracking (Optional)

Resend provides basic analytics:
- Opens
- Clicks
- Bounces
- Spam complaints

**Access via Resend Dashboard:**
- [ ] Log in to Resend
- [ ] Go to **Emails** tab
- [ ] View delivery status
- [ ] Check bounce rate (<5% is good)

**No code needed** - Resend tracks automatically.

---

## 💰 Free Tier Limits

**Resend Free Tier:**
- 3,000 emails/month
- 100 emails/day
- All features included

**When to Upgrade:**
- >3,000 emails/month = $20/month for 50,000 emails
- For most MVPs, free tier is enough for 6-12 months

**Monitor Usage:**
- [ ] Check Resend dashboard monthly
- [ ] Get notified at 80% usage
- [ ] Upgrade when needed

---

## 🚨 Common Issues & Fixes

### Issue 1: Emails Going to Spam

**Fix:**
- [ ] Use custom domain (not @resend.dev) - improves deliverability
- [ ] Add SPF and DKIM records (Resend provides instructions)
- [ ] Keep subject lines simple (no "FREE" or "$$")
- [ ] Don't send too many emails at once

### Issue 2: Emails Not Sending

**Check:**
- [ ] SMTP settings correct in Supabase
- [ ] Resend API key valid
- [ ] Sender email verified in Resend
- [ ] Check Resend logs for errors

### Issue 3: Verification Links Not Working

**Fix:**
- [ ] Check redirect URL in Supabase Auth settings
- [ ] Ensure {{ .ConfirmationURL }} is in template
- [ ] Verify URL scheme matches (http vs https)

---

## 📋 Email Strategy for Solo Devs

**Always Send:**
- ✅ Email verification (security)
- ✅ Password reset (required)
- ✅ Purchase confirmation (user expects it)

**Optional (Add When Needed):**
- Welcome email (high engagement, but can skip for MVP)
- Low balance warning (reduces churn, add after launch)
- Weekly digest (nice-to-have, add much later)

**Never Send:**
- ❌ Marketing emails (without consent)
- ❌ Daily notifications (annoying)
- ❌ Multiple reminders (spammy)

---

## ✅ Final Setup Summary

**Total Setup Time: ~15 minutes**

1. Create Resend account (2 min)
2. Connect to Supabase SMTP (3 min)
3. Customize email templates (5 min)
4. Add custom email function (5 min, optional)
5. Test email delivery (5 min)

**What You Get:**
- ✅ Email verification (automatic)
- ✅ Password reset (automatic)
- ✅ Purchase confirmations (simple function)
- ✅ Low balance warnings (simple function)
- ✅ 3,000 emails/month free
- ✅ Great deliverability
- ✅ No maintenance needed

**You're done!** Supabase + Resend handles everything securely and sustainably.

---

**This template provides a simple, secure email integration for solo developers using Resend and Supabase Auth.**
