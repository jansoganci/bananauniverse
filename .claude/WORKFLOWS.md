# Development Workflows

## Git Workflow

### Feature Development
```bash
# 1. Create feature branch
git checkout -b feature/quota-improvements

# 2. Make changes
# 3. Commit with conventional format
git commit -m "feat: improve quota system performance"

# 4. Push and create PR
git push -u origin feature/quota-improvements
```

### Commit Convention
- `feat:` - New features
- `fix:` - Bug fixes  
- `refactor:` - Code refactoring
- `docs:` - Documentation updates
- `test:` - Test additions/updates
- `chore:` - Maintenance tasks

## iOS Development

### Build & Test
```bash
# Clean build
cmd + Shift + K

# Build project
cmd + B

# Run on simulator
cmd + R

# Run tests (if available)
cmd + U
```

### Debugging
1. Use Xcode debugger for UI issues
2. Check console for SwiftUI state warnings
3. Use Instruments for performance profiling
4. Monitor memory usage during image processing

## Supabase Development

### Local Setup
```bash
# Start local Supabase
supabase start

# Reset database with all migrations
supabase db reset

# View local dashboard
open http://localhost:54323
```

### Database Migrations
```bash
# Create new migration
supabase migration new add_quota_optimizations

# Apply specific migration
supabase migration up 20241101123456

# Rollback migration
supabase migration down

# Deploy to production
supabase db push
```

### Edge Functions

#### Development
```bash
# Serve locally
supabase functions serve process-image

# Test with curl
curl -X POST http://localhost:54321/functions/v1/process-image \
  -H "Content-Type: application/json" \
  -d '{"image_url": "test.jpg", "tool_id": "upscale"}'
```

#### Deployment
```bash
# Deploy function
supabase functions deploy process-image

# View logs
supabase functions logs process-image --follow

# Set secrets
supabase secrets set FAL_KEY=your-key
```

## Testing Procedures

### Manual Testing Checklist

#### Navigation
- [ ] Tool card tap → Chat opens with correct tool
- [ ] Back navigation preserves state
- [ ] Tab switching works correctly
- [ ] Deep links function properly

#### Quota System
- [ ] Free user: 5 requests/day limit
- [ ] Premium user: 100 requests/day limit
- [ ] Quota resets at midnight UTC
- [ ] Paywall shows when quota exceeded
- [ ] Anonymous/authenticated users tracked separately

#### Image Processing
- [ ] Upload works for various image formats
- [ ] Processing completes within 35 seconds
- [ ] Results display correctly
- [ ] Error handling for network failures
- [ ] Memory usage stays reasonable

#### Authentication
- [ ] Anonymous authentication works
- [ ] Email signup/login flows
- [ ] Premium status sync from Adapty
- [ ] Session persistence across app launches

### Database Testing
```bash
# Test RLS policies
SELECT * FROM daily_quota WHERE user_id = 'test-user';

# Verify quota calculations
SELECT remaining_requests FROM daily_quota 
WHERE user_id = auth.uid() AND date = CURRENT_DATE;

# Check migration integrity
SELECT * FROM supabase_migrations.schema_migrations 
ORDER BY version DESC LIMIT 5;
```

## Deployment Process

### Production Deployment

#### 1. Pre-deployment Checks
- [ ] All tests pass locally
- [ ] Migrations tested on staging
- [ ] Edge functions work correctly
- [ ] RLS policies validated
- [ ] Performance benchmarks met

#### 2. Database Migration
```bash
# Apply migrations to production
supabase db push

# Verify migration success
supabase db status
```

#### 3. Edge Function Deployment
```bash
# Deploy all functions
supabase functions deploy

# Verify deployment
supabase functions list
```

#### 4. iOS App Release
- Update version in Xcode
- Archive and upload to App Store Connect
- Submit for review

### Rollback Procedures

#### Database Rollback
```bash
# Rollback specific migration
supabase migration down <version>

# Verify rollback
supabase db status
```

#### Function Rollback
```bash
# Redeploy previous version
git checkout <previous-commit>
supabase functions deploy process-image
```

## Monitoring & Debugging

### Supabase Monitoring
- Check dashboard for function errors
- Monitor database performance
- Review RLS policy violations
- Track API usage metrics

### iOS Monitoring
- Xcode organizer for crash reports
- TestFlight feedback
- App Store Connect analytics
- Custom logging for critical paths

### Performance Optimization
- Profile image processing pipeline
- Monitor memory usage during AI processing
- Optimize database queries
- Cache frequently accessed data

## Emergency Procedures

### Critical Bug in Production
1. Identify scope of issue
2. Create hotfix branch
3. Implement minimal fix
4. Test thoroughly
5. Deploy via emergency release
6. Monitor post-deployment

### Database Issues
1. Check Supabase dashboard status
2. Review recent migrations
3. Check RLS policy changes
4. Rollback if necessary
5. Contact Supabase support if needed

### Edge Function Failures
1. Check function logs
2. Verify environment variables
3. Test locally
4. Redeploy if needed
5. Implement circuit breaker if persistent