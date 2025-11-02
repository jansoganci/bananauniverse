# Deploy Edge Function

## Task: Deploy Supabase Edge Function

### Context
Deploy Edge Function to production with proper testing and monitoring setup.

### Steps
1. Test function locally first
2. Deploy to production  
3. Verify deployment success
4. Monitor for errors

### Commands
```bash
# Test locally
supabase functions serve process-image

# Test with sample request
curl -X POST http://localhost:54321/functions/v1/process-image \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d '{"image_url": "test.jpg", "tool_id": "upscale", "user_id": "test"}'

# Deploy to production
supabase functions deploy process-image

# Verify deployment
supabase functions list

# Monitor logs
supabase functions logs process-image --follow
```

### Post-Deployment Checklist
- [ ] Function appears in Supabase dashboard
- [ ] Test request succeeds in production
- [ ] Logs show no errors
- [ ] fal.ai integration working
- [ ] Database writes successful
- [ ] Response time < 35 seconds

### Rollback Plan
```bash
# If deployment fails, redeploy previous version
git checkout <previous-commit>
supabase functions deploy process-image
```