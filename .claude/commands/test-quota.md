# Test Quota System

## Task: Validate Quota System Functionality

### Context
Test the quota system to ensure proper counting, limits, and premium user handling.

### Test Scenarios

#### 1. Free User Quota (5 requests/day)
```bash
# Test with anonymous user
curl -X POST http://localhost:54321/functions/v1/process-image \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d '{
    "image_url": "test.jpg",
    "tool_id": "upscale",
    "user_id": null,
    "session_id": "test-session-123"
  }'
```

#### 2. Premium User Quota (100 requests/day)
```bash
# Test with authenticated premium user
curl -X POST http://localhost:54321/functions/v1/process-image \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_USER_JWT" \
  -d '{
    "image_url": "test.jpg", 
    "tool_id": "upscale",
    "user_id": "premium-user-id"
  }'
```

#### 3. Quota Exceeded Response
```bash
# Make 6 requests as free user to trigger limit
for i in {1..6}; do
  curl -X POST http://localhost:54321/functions/v1/process-image \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer YOUR_ANON_KEY" \
    -d '{
      "image_url": "test.jpg",
      "tool_id": "upscale", 
      "session_id": "test-session-quota"
    }'
  echo "Request $i completed"
done
```

### Database Queries for Testing

#### Check Current Quota Usage
```sql
-- Check quota for specific user
SELECT 
  user_id,
  session_id,
  date,
  requests_made,
  remaining_requests,
  is_premium
FROM daily_quota 
WHERE user_id = 'test-user-id' 
  AND date = CURRENT_DATE;

-- Check anonymous quota
SELECT 
  session_id,
  date,
  requests_made,
  remaining_requests,
  is_premium
FROM daily_quota 
WHERE session_id = 'test-session-123' 
  AND date = CURRENT_DATE;
```

#### Reset Quota for Testing
```sql
-- Reset specific user quota
DELETE FROM daily_quota 
WHERE user_id = 'test-user-id' 
  AND date = CURRENT_DATE;

-- Reset anonymous quota  
DELETE FROM daily_quota 
WHERE session_id = 'test-session-123' 
  AND date = CURRENT_DATE;
```

### iOS App Testing

#### Free User Flow
1. Launch app (anonymous)
2. Process 5 images successfully
3. Attempt 6th image → should show paywall
4. Verify quota badge shows "5/5"

#### Premium User Flow  
1. Sign in with premium account
2. Process multiple images
3. Verify quota badge shows correct count
4. Ensure no paywall appears

#### Quota Reset Testing
1. Change device date to next day
2. Verify quota resets to 0/5 or 0/100
3. Test processing works again

### Test Checklist
- [ ] Free users limited to 5 requests/day
- [ ] Premium users get 100 requests/day
- [ ] Anonymous users tracked by session_id
- [ ] Authenticated users tracked by user_id
- [ ] Quota resets at midnight UTC
- [ ] Paywall shows when quota exceeded
- [ ] Badge displays correct usage
- [ ] Database RLS policies enforced
- [ ] No quota leakage between users
- [ ] Premium status sync works

### Expected Responses

#### Success Response
```json
{
  "success": true,
  "image_url": "https://storage.url/processed.jpg",
  "quota_used": 3,
  "quota_limit": 5,
  "is_premium": false
}
```

#### Quota Exceeded Response
```json
{
  "success": false,
  "error": "Daily quota exceeded",
  "quota_used": 5,
  "quota_limit": 5,
  "is_premium": false
}
```

### Debug Commands
```bash
# Check Edge Function logs
supabase functions logs process-image --follow

# Monitor database in real-time
psql postgresql://postgres:password@localhost:54322/postgres
\watch 1 SELECT * FROM daily_quota WHERE date = CURRENT_DATE;

# Reset local database completely
supabase db reset
```