# Debug Edge Function

## Task: Debug Supabase Edge Function Issues

### Context
Troubleshoot Edge Function problems including performance, errors, and integration issues.

### Common Issues & Solutions

#### 1. Function Timeout (>35 seconds)
```typescript
// Add timeout handling
const controller = new AbortController();
setTimeout(() => controller.abort(), 30000); // 30s timeout

const response = await fetch(fal_url, {
  method: 'POST',
  headers: { 'Authorization': `Key ${fal_key}` },
  body: JSON.stringify(payload),
  signal: controller.signal
});
```

#### 2. Memory Issues with Large Images
```typescript
// Check image size before processing
const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB
if (imageSize > MAX_FILE_SIZE) {
  return new Response(
    JSON.stringify({ error: 'Image too large' }), 
    { status: 400 }
  );
}
```

#### 3. Database Connection Errors
```typescript
// Add proper error handling
try {
  const { data, error } = await supabase
    .from('daily_quota')
    .select('*')
    .eq('user_id', user_id);
    
  if (error) {
    console.error('Database error:', error);
    throw error;
  }
} catch (err) {
  console.error('Supabase error:', err);
  return new Response(
    JSON.stringify({ error: 'Database unavailable' }),
    { status: 500 }
  );
}
```

### Debugging Commands

#### View Function Logs
```bash
# Real-time logs
supabase functions logs process-image --follow

# Recent logs only
supabase functions logs process-image

# Logs with specific time range
supabase functions logs process-image --since="2024-11-01 10:00:00"
```

#### Test Function Locally
```bash
# Start local development
supabase start
supabase functions serve process-image

# Test with verbose curl
curl -v -X POST http://localhost:54321/functions/v1/process-image \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d @test-payload.json
```

#### Test Payload Example
```json
{
  "image_url": "https://example.com/test-image.jpg",
  "tool_id": "upscale",
  "user_id": "test-user-123",
  "session_id": "test-session-456"
}
```

### Performance Debugging

#### Add Performance Timing
```typescript
console.time('total-processing');
console.time('fal-api-call');

// fal.ai API call
const response = await fetch(fal_url, options);

console.timeEnd('fal-api-call');
console.time('database-write');

// Database operations
await supabase.from('processed_images').insert(data);

console.timeEnd('database-write');
console.timeEnd('total-processing');
```

#### Monitor Resource Usage
```typescript
// Log memory usage
const memUsage = Deno.memoryUsage();
console.log('Memory usage:', {
  rss: Math.round(memUsage.rss / 1024 / 1024) + 'MB',
  heapUsed: Math.round(memUsage.heapUsed / 1024 / 1024) + 'MB'
});
```

### Error Handling Patterns

#### Structured Error Response
```typescript
function createErrorResponse(error: string, statusCode: number = 500) {
  return new Response(
    JSON.stringify({ 
      success: false,
      error,
      timestamp: new Date().toISOString()
    }),
    { 
      status: statusCode,
      headers: { 'Content-Type': 'application/json' }
    }
  );
}
```

#### Input Validation
```typescript
function validateInput(body: any) {
  const required = ['tool_id'];
  const missing = required.filter(field => !body[field]);
  
  if (missing.length > 0) {
    throw new Error(`Missing required fields: ${missing.join(', ')}`);
  }
  
  if (!body.user_id && !body.session_id) {
    throw new Error('Either user_id or session_id required');
  }
}
```

### Database Debugging

#### Check RLS Policies
```sql
-- Verify RLS is enabled
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename IN ('daily_quota', 'processed_images');

-- Check policy details
SELECT * FROM pg_policies 
WHERE tablename = 'daily_quota';
```

#### Test Quota Logic
```sql
-- Simulate quota check
WITH quota_check AS (
  SELECT 
    COALESCE(requests_made, 0) as current_requests,
    CASE 
      WHEN is_premium THEN 100 
      ELSE 5 
    END as limit
  FROM daily_quota 
  WHERE user_id = 'test-user' AND date = CURRENT_DATE
)
SELECT 
  current_requests,
  limit,
  (current_requests < limit) as can_process
FROM quota_check;
```

### Deployment Debugging

#### Verify Deployment
```bash
# Check function status
supabase functions list

# Verify environment variables
supabase secrets list

# Test production endpoint
curl -X POST https://your-project.supabase.co/functions/v1/process-image \
  -H "Authorization: Bearer YOUR_KEY" \
  -d @test-payload.json
```

#### Environment Variables Check
```typescript
// Verify required env vars
const requiredEnvVars = ['FAL_KEY', 'SUPABASE_URL'];
const missing = requiredEnvVars.filter(key => !Deno.env.get(key));

if (missing.length > 0) {
  console.error('Missing environment variables:', missing);
  return createErrorResponse('Server configuration error', 500);
}
```

### Debug Checklist
- [ ] Function deploys without errors
- [ ] Environment variables are set
- [ ] Database connections work
- [ ] RLS policies allow access
- [ ] fal.ai API responds correctly
- [ ] Response times < 35 seconds
- [ ] Memory usage stays reasonable
- [ ] Error handling works properly
- [ ] Quota logic functions correctly
- [ ] Logs provide useful information

### Emergency Fixes

#### Quick Rollback
```bash
# Rollback to previous working version
git log --oneline -10  # Find last working commit
git checkout <commit-hash>
supabase functions deploy process-image
```

#### Disable Function Temporarily
```bash
# Remove function temporarily
supabase functions delete process-image

# Redeploy when fixed
supabase functions deploy process-image
```