# Quick Start Guide - Quota Test Suite

## 🚀 Run Tests in 30 Seconds

### Step 1: Choose Your Environment

**Local Development:**
```bash
# Start Supabase locally
supabase start

# Run tests
./tests/curl_quota_suite.sh
```

**Production/Remote:**
```bash
# Set your Supabase URL
export SUPABASE_URL=https://your-project.supabase.co

# Get anon key from Supabase dashboard
# Edit tests/curl_quota_suite.sh line 182:
# Replace "anon_key_replace_me" with your actual anon key

# Run tests
./tests/curl_quota_suite.sh
```

### Step 2: Verify Results

Look for these patterns in output:

**✅ Success Indicators:**
- `✅ HTTP Status: 200` (for tests 1, 2, 6, 7)
- `⚠️ HTTP Status: 429` (for test 3 - quota exceeded)
- `quota_used = 1` (test 1)
- `idempotent = true` (test 2)

**❌ Failure Indicators:**
- `❌ HTTP Status: 5xx` (server errors)
- `Connection refused` (Supabase not running)
- `401 Unauthorized` (wrong anon key)

### Step 3: Check Database (Optional)

```sql
-- In Supabase SQL Editor:
SELECT * FROM daily_quotas 
WHERE device_id LIKE 'test_device%'
ORDER BY created_at DESC LIMIT 5;
```

---

## 🎯 What Each Test Verifies

| Test | What It Tests | Success = |
|------|--------------|-----------|
| 1 | Basic quota consumption | HTTP 200, quota incremented |
| 2 | Idempotency | Same request ID doesn't charge again |
| 3 | Quota limits | 6th request returns 429 |
| 4 | Auto-refund on failure | Failed request triggers refund |
| 5 | Refund limits | Only 2 refunds/day allowed |
| 6 | Premium bypass | Premium users bypass quota |
| 7 | Record initialization | RPC creates missing records |

---

## 🔧 Troubleshooting

**Problem**: "bash: ./tests/curl_quota_suite.sh: Permission denied"  
**Solution**: `chmod +x tests/curl_quota_suite.sh`

**Problem**: "Connection refused"  
**Solution**: Start local Supabase: `supabase start`

**Problem**: "401 Unauthorized" in Test 7  
**Solution**: Update anon key in script (line 182)

**Problem**: Tests pass but quota doesn't increment  
**Solution**: Check migrations applied: `supabase db reset`

---

## 📊 Example Output

```
═══════════════════════════════════════════════════════════════
  QUOTA SYSTEM TEST SUITE
  Base URL: http://localhost:54321
═══════════════════════════════════════════════════════════════

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TEST 1: Basic Consumption - First Request
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ HTTP Status: 200

Quota Info:
{
  "success": true,
  "quota_info": {
    "quota_used": 1,
    "quota_limit": 5,
    "quota_remaining": 4
  }
}
```

---

## ⚡ Pro Tips

1. **Clean slate**: Run `supabase db reset` before tests
2. **Verbose logging**: Add `-v` flag to curl commands for debugging
3. **CI/CD**: Tests return exit code 0 on success
4. **Multiple runs**: Each test uses unique device IDs for isolation

---

## 🆘 Need Help?

Check the detailed README: `tests/README.md`

