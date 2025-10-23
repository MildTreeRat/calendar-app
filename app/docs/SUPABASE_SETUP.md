# Supabase Cloud Setup Guide

This document provides the complete setup instructions for your Supabase backend to support the calendar app's cloud sync functionality.

## Prerequisites

1. Create a Supabase account at https://supabase.com
2. Create a new project
3. Note your project URL and anon key (found in Project Settings > API)

## Database Schema Setup

### 1. Create Tables with Owner ID

Run these SQL commands in the Supabase SQL Editor (Dashboard > SQL Editor):

```sql
-- ============================================================================
-- Add owner_id to all user data tables
-- ============================================================================

-- Users table
ALTER TABLE "user" ADD COLUMN IF NOT EXISTS owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_user_owner ON "user"(owner_id, updated_at);

-- User profiles
ALTER TABLE user_profile ADD COLUMN IF NOT EXISTS owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_user_profile_owner ON user_profile(owner_id, updated_at);

-- Accounts
ALTER TABLE account ADD COLUMN IF NOT EXISTS owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_account_owner ON account(owner_id, updated_at);

-- Calendars
ALTER TABLE calendar ADD COLUMN IF NOT EXISTS owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_calendar_owner ON calendar(owner_id, updated_at);

-- Calendar memberships
ALTER TABLE calendar_membership ADD COLUMN IF NOT EXISTS owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_calendar_membership_owner ON calendar_membership(owner_id, updated_at);

-- Calendar groups
ALTER TABLE calendar_group ADD COLUMN IF NOT EXISTS owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_calendar_group_owner ON calendar_group(owner_id, updated_at);

-- Calendar group maps
ALTER TABLE calendar_group_map ADD COLUMN IF NOT EXISTS owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_calendar_group_map_owner ON calendar_group_map(owner_id, updated_at);

-- Events
ALTER TABLE event ADD COLUMN IF NOT EXISTS owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_event_owner ON event(owner_id, updated_at);

-- ICS sources
ALTER TABLE ics_source ADD COLUMN IF NOT EXISTS owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_ics_source_owner ON ics_source(owner_id, updated_at);

-- Task lists
ALTER TABLE task_list ADD COLUMN IF NOT EXISTS owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_task_list_owner ON task_list(owner_id, updated_at);

-- Tasks
ALTER TABLE task ADD COLUMN IF NOT EXISTS owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_task_owner ON task(owner_id, updated_at);

-- Color palettes
ALTER TABLE color_palette ADD COLUMN IF NOT EXISTS owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_color_palette_owner ON color_palette(owner_id, updated_at);

-- Palette colors
ALTER TABLE palette_color ADD COLUMN IF NOT EXISTS owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_palette_color_owner ON palette_color(owner_id, updated_at);
```

### 2. Create Updated_at Trigger

```sql
-- ============================================================================
-- Auto-update updated_at timestamp on row changes
-- ============================================================================

CREATE OR REPLACE FUNCTION touch_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = extract(epoch from now()) * 1000;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to all tables
CREATE TRIGGER _touch_user BEFORE UPDATE ON "user"
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TRIGGER _touch_user_profile BEFORE UPDATE ON user_profile
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TRIGGER _touch_account BEFORE UPDATE ON account
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TRIGGER _touch_calendar BEFORE UPDATE ON calendar
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TRIGGER _touch_calendar_membership BEFORE UPDATE ON calendar_membership
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TRIGGER _touch_calendar_group BEFORE UPDATE ON calendar_group
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TRIGGER _touch_calendar_group_map BEFORE UPDATE ON calendar_group_map
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TRIGGER _touch_event BEFORE UPDATE ON event
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TRIGGER _touch_ics_source BEFORE UPDATE ON ics_source
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TRIGGER _touch_task_list BEFORE UPDATE ON task_list
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TRIGGER _touch_task BEFORE UPDATE ON task
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TRIGGER _touch_color_palette BEFORE UPDATE ON color_palette
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TRIGGER _touch_palette_color BEFORE UPDATE ON palette_color
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
```

### 3. Enable Row Level Security (RLS)

```sql
-- ============================================================================
-- Enable RLS on all tables
-- ============================================================================

ALTER TABLE "user" ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profile ENABLE ROW LEVEL SECURITY;
ALTER TABLE account ENABLE ROW LEVEL SECURITY;
ALTER TABLE calendar ENABLE ROW LEVEL SECURITY;
ALTER TABLE calendar_membership ENABLE ROW LEVEL SECURITY;
ALTER TABLE calendar_group ENABLE ROW LEVEL SECURITY;
ALTER TABLE calendar_group_map ENABLE ROW LEVEL SECURITY;
ALTER TABLE event ENABLE ROW LEVEL SECURITY;
ALTER TABLE ics_source ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_list ENABLE ROW LEVEL SECURITY;
ALTER TABLE task ENABLE ROW LEVEL SECURITY;
ALTER TABLE color_palette ENABLE ROW LEVEL SECURITY;
ALTER TABLE palette_color ENABLE ROW LEVEL SECURITY;
```

### 4. Create RLS Policies

```sql
-- ============================================================================
-- RLS Policies: Users can only read/write their own data
-- ============================================================================

-- Users
CREATE POLICY p_user_rw ON "user"
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

-- User profiles
CREATE POLICY p_user_profile_rw ON user_profile
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

-- Accounts
CREATE POLICY p_account_rw ON account
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

-- Calendars
CREATE POLICY p_calendar_rw ON calendar
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

-- Calendar memberships
CREATE POLICY p_calendar_membership_rw ON calendar_membership
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

-- Calendar groups
CREATE POLICY p_calendar_group_rw ON calendar_group
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

-- Calendar group maps
CREATE POLICY p_calendar_group_map_rw ON calendar_group_map
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

-- Events
CREATE POLICY p_event_rw ON event
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

-- ICS sources
CREATE POLICY p_ics_source_rw ON ics_source
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

-- Task lists
CREATE POLICY p_task_list_rw ON task_list
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

-- Tasks
CREATE POLICY p_task_rw ON task
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

-- Color palettes
CREATE POLICY p_color_palette_rw ON color_palette
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

-- Palette colors
CREATE POLICY p_palette_color_rw ON palette_color
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());
```

## App Configuration

### 1. Create Environment Configuration

Create `lib/config/supabase_config.dart`:

```dart
class SupabaseConfig {
  static const String url = 'YOUR_SUPABASE_URL'; // e.g., https://xxxxx.supabase.co
  static const String anonKey = 'YOUR_SUPABASE_ANON_KEY';
}
```

**⚠️ IMPORTANT:** Never commit your actual keys to version control. Use environment variables or a `.env` file in production.

### 2. Initialize in main.dart

```dart
import 'package:flutter/material.dart';
import 'logging/logger.dart';
import 'services/supabase_service.dart';
import 'database/database.dart';
import 'config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logger
  await Logger.initialize();

  // Initialize Supabase
  await SupabaseService.initialize(
    supabaseUrl: SupabaseConfig.url,
    supabaseAnonKey: SupabaseConfig.anonKey,
  );

  // Initialize database
  final database = AppDatabase();

  runApp(MyApp(database: database));
}
```

## Testing the Setup

### 1. Test Authentication

```dart
final supabase = SupabaseService.instance;

// Sign up
final response = await supabase.signUpWithPassword(
  email: 'test@example.com',
  password: 'testpassword123',
);

// Sign in
final signInResponse = await supabase.signInWithPassword(
  email: 'test@example.com',
  password: 'testpassword123',
);

// Check auth status
print('Authenticated: ${supabase.isAuthenticated}');
print('User ID: ${supabase.currentUserId}');
```

### 2. Test Sync

```dart
final sync = SyncService(
  database: database,
  supabase: SupabaseService.instance,
  logger: Logger.instance,
);

// Perform sync
final result = await sync.sync();
print('Sync result: $result');
```

## Troubleshooting

### Issue: "new row violates row-level security policy"

**Solution:** Ensure the `owner_id` column is being set correctly in your upsert operations. The RLS policies require `owner_id = auth.uid()`.

### Issue: Sync not pulling data

**Solution:**
1. Check that you're authenticated: `SupabaseService.instance.isAuthenticated`
2. Verify RLS policies are correct
3. Check that `updated_at` timestamps are in milliseconds since epoch

### Issue: Conflict resolution not working

**Solution:** The current implementation uses last-write-wins. Check that `updated_at` values are being set correctly by the trigger.

## Migration Checklist

- [ ] Create Supabase project
- [ ] Run all SQL scripts in order (owner_id, triggers, RLS, policies)
- [ ] Create `supabase_config.dart` with your credentials
- [ ] Update `main.dart` to initialize Supabase
- [ ] Test authentication flow
- [ ] Test sync functionality
- [ ] Implement table-specific upsert logic in `sync_service.dart`
- [ ] Add background sync with WorkManager (Android) / Background Tasks (iOS)

## Security Best Practices

1. **Never expose service_role key** - Only use anon key in client apps
2. **Always use RLS** - Never disable row-level security in production
3. **Validate on server** - Don't trust client data
4. **Rate limit auth endpoints** - Prevent brute force attacks
5. **Log suspicious activity** - Monitor for unusual sync patterns

## Next Steps

After completing this setup:
1. Implement table-specific upsert logic in `SyncService._upsertLocalRow()`
2. Add repository layer hooks to call `SyncService.recordChange()` on local writes
3. Set up periodic background sync
4. Add conflict resolution UI for merge conflicts
5. Implement shared calendar feeds (.ics export)
