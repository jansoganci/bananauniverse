# Create Database Migration

## Task: Create and Apply Database Migration

### Context
Create a new database migration for schema changes with proper testing and rollback procedures.

### Steps
1. Create migration file
2. Write SQL with proper RLS
3. Test locally
4. Apply to production

### Commands
```bash
# Create new migration
supabase migration new descriptive_migration_name

# Example: Add new table
supabase migration new add_user_preferences_table

# Reset local database to test migration
supabase db reset

# Check migration status
supabase db status

# Apply to production (after testing)
supabase db push
```

### Migration Template
```sql
-- Migration: add_user_preferences_table
-- Description: Add table for storing user preferences

-- Create table
CREATE TABLE IF NOT EXISTS user_preferences (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  preferences JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Users can view own preferences" ON user_preferences
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own preferences" ON user_preferences
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own preferences" ON user_preferences
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Create indexes
CREATE INDEX idx_user_preferences_user_id ON user_preferences(user_id);

-- Create updated_at trigger
CREATE TRIGGER update_user_preferences_updated_at
  BEFORE UPDATE ON user_preferences
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
```

### Testing Checklist
- [ ] Migration applies without errors
- [ ] RLS policies work correctly
- [ ] Indexes created successfully
- [ ] Triggers function properly
- [ ] No breaking changes to existing queries
- [ ] Rollback migration works

### Rollback Plan
```bash
# Create rollback migration if needed
supabase migration new rollback_user_preferences_table

# Or rollback specific migration
supabase migration down <version>
```