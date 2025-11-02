# 🔒 Security Remediation Guide

## Exposed Supabase Service Role Key - Remediation Steps

**Issue:** Supabase Service Role Key was exposed in commit `f601295b` in the following files:
- `run_tests_post043.sh` (line 9)
- `run_tests_1_3_to_1_5.sh` (line 13)
- `INTEGRATION_TEST_PLAN.md` (line 23)

**Status:** ✅ Keys removed from code, ⚠️ **URGENT: Key rotation required**

---

## Step 1: Rotate the Service Role Key (IMMEDIATE)

The exposed key is still valid until rotated. **Do this NOW:**

1. **Go to Supabase Dashboard:**
   - Navigate to: https://supabase.com/dashboard
   - Select your project: `jiorfutbmahpfgplkats`

2. **Rotate the Service Role Key:**
   - Go to: **Settings → API**
   - Scroll to **"Service Role Key"** section
   - Click **"Regenerate Key"** ⚠️
   - **Confirm** the regeneration

3. **Update Your Local Environment:**
   ```bash
   # Create/update .env file (not committed to git)
   echo "SUPABASE_SERVICE_ROLE_KEY=your-new-key-here" >> .env
   ```

4. **Update CI/CD Secrets:**
   - **GitHub Actions:** Settings → Secrets → Actions → Update `SUPABASE_SERVICE_ROLE_KEY`
   - **Vercel/Deployments:** Update environment variable in deployment settings
   - **Any other CI/CD:** Update secrets accordingly

5. **Update Edge Function Environment:**
   ```bash
   supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-new-key-here
   ```

---

## Step 2: Purge Keys from Git History

**⚠️ Warning:** This rewrites git history and requires force push. Coordinate with team first.

### Option A: Using git filter-repo (Recommended)

```bash
# Install git-filter-repo if needed
# brew install git-filter-repo  # macOS
# pip install git-filter-repo   # Python

# Remove keys from all commits in history
git filter-repo --path-glob '*.sh' --path-glob '*.md' \
  --invert-paths \
  --replace-text <(echo "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imppb3JmdXRibWFocGZncGxrYXRzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDMzMjE2MiwiZXhwIjoyMDc1OTA4MTYyfQ.REDACTED_KEY_REMOVED==REDACTED")

# Force push to remove from remote (⚠️ DANGER: Rewrites history)
git push origin --force --all
git push origin --force --tags
```

### Option B: Using BFG Repo-Cleaner

```bash
# Install BFG: brew install bfg  # macOS

# Create replacement file
echo "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imppb3JmdXRibWFocGZncGxrYXRzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDMzMjE2MiwiZXhwIjoyMDc1OTA4MTYyfQ.REDACTED_KEY_REMOVED==REDACTED" > /tmp/replacements.txt

# Clean repository
bfg --replace-text /tmp/replacements.txt

# Force push
git push origin --force --all
```

---

## Step 3: Verify Cleanup

```bash
# Search git history for any remaining keys
git log --all --full-history -p | grep -i "service.*role.*key\|REDACTED_KEY_REMOVED" || echo "✅ No keys found in history"

# Verify current files don't contain keys
grep -r "REDACTED_KEY_REMOVED" . --exclude-dir=.git || echo "✅ No keys in current files"
```

---

## Step 4: Set Up Secure Environment Variables

### Local Development

1. **Copy example file:**
   ```bash
   cp .env.example .env
   ```

2. **Add your keys to `.env`** (already in .gitignore):
   ```bash
   SUPABASE_URL=https://jiorfutbmahpfgplkats.supabase.co
   ANON_KEY=your-anon-key
   SUPABASE_SERVICE_ROLE_KEY=your-new-service-role-key
   ```

3. **Load in shell:**
   ```bash
   source .env
   export $(cat .env | xargs)
   ```

### CI/CD (GitHub Actions)

1. Go to: **Repository → Settings → Secrets → Actions**
2. Add/Update:
   - `SUPABASE_URL`
   - `ANON_KEY`
   - `SUPABASE_SERVICE_ROLE_KEY` (new rotated key)

3. Use in workflow:
   ```yaml
   env:
     SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
   ```

---

## Step 5: Security Best Practices Going Forward

✅ **DO:**
- Use environment variables for all secrets
- Store secrets in `.env` files (gitignored)
- Use GitHub Secrets for CI/CD
- Rotate keys immediately if exposed

❌ **DON'T:**
- Commit API keys, tokens, or secrets to git
- Hardcode secrets in scripts or code
- Share secrets in documentation
- Use exposed keys even after "removing" them

---

## Checklist

- [ ] Service Role Key rotated in Supabase dashboard
- [ ] Local `.env` file updated with new key
- [ ] CI/CD secrets updated (GitHub Actions, etc.)
- [ ] Edge Function environment updated
- [ ] Git history purged (if doing full cleanup)
- [ ] Verification checks passed
- [ ] Team notified about key rotation
- [ ] `.env` confirmed in `.gitignore`

---

## Notes

- **Key rotation is CRITICAL:** Even after removing from code, the exposed key remains valid until rotated
- **Git history purge:** Only do this if you're comfortable with force pushes and have team coordination
- **Alternative:** If you can't purge history immediately, rotate the key first, then plan history cleanup later

---

**Last Updated:** 2025-11-02  
**Status:** Keys removed from code ✅ | Key rotation pending ⚠️

