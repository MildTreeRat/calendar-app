# Cloud Sync Quick Start Guide

Get your calendar app syncing with the cloud in under 30 minutes!

## Step 1: Setup Supabase (10 minutes)

### 1.1 Create Account & Project
1. Go to https://supabase.com
2. Sign up (free tier is fine)
3. Create a new project
4. Note your **Project URL** and **anon key** from Settings > API

### 1.2 Run SQL Scripts
In the Supabase SQL Editor (Dashboard > SQL Editor), run these scripts in order:

**Script 1: Add owner_id columns**
```sql
-- Run this for EACH table you want to sync
-- Example for events:
ALTER TABLE event ADD COLUMN IF NOT EXISTS owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_event_owner ON event(owner_id, updated_at);
```

**Script 2: Updated_at trigger**
```sql
CREATE OR REPLACE FUNCTION touch_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = extract(epoch from now()) * 1000;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER _touch_event BEFORE UPDATE ON event
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
```

**Script 3: Row Level Security**
```sql
ALTER TABLE event ENABLE ROW LEVEL SECURITY;

CREATE POLICY p_event_rw ON event
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());
```

> 📘 **Full SQL scripts** for all tables are in `SUPABASE_SETUP.md`

## Step 2: Configure App (5 minutes)

### 2.1 Update Supabase Config
Edit `lib/config/supabase_config.dart`:

```dart
class SupabaseConfig {
  static const String url = 'https://your-project-id.supabase.co';  // 👈 Your project URL
  static const String anonKey = 'eyJhbGc...';  // 👈 Your anon key
}
```

### 2.2 Update main.dart
Replace your `main()` function:

```dart
import 'package:flutter/material.dart';
import 'logging/logger.dart';
import 'services/supabase_service.dart';
import 'services/sync_service.dart';
import 'database/database.dart';
import 'config/supabase_config.dart';
import 'screens/auth_screen.dart';
import 'screens/database_demo.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logger
  await Logger.initialize();

  // Initialize Supabase
  try {
    await SupabaseService.initialize(
      supabaseUrl: SupabaseConfig.url,
      supabaseAnonKey: SupabaseConfig.anonKey,
    );
  } catch (e) {
    print('Supabase init failed: $e');
    // Continue anyway (offline mode)
  }

  // Initialize database
  final database = AppDatabase();

  // Create sync service
  SyncService? syncService;
  try {
    syncService = SyncService(
      database: database,
      supabase: SupabaseService.instance,
      logger: Logger.instance,
    );
  } catch (e) {
    print('Sync service unavailable: $e');
  }

  runApp(MyApp(
    database: database,
    syncService: syncService,
  ));
}

class MyApp extends StatelessWidget {
  final AppDatabase database;
  final SyncService? syncService;

  const MyApp({
    super.key,
    required this.database,
    this.syncService,
  });

  @override
  Widget build(BuildContext context) {
    // Check if authenticated
    bool isAuthenticated = false;
    try {
      isAuthenticated = SupabaseService.instance.isAuthenticated;
    } catch (e) {
      // Service not initialized
    }

    return MaterialApp(
      title: 'Calendar App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: isAuthenticated
          ? DatabaseDemoScreen(database: database)
          : const AuthScreen(),
      routes: {
        '/home': (context) => DatabaseDemoScreen(database: database),
        '/auth': (context) => const AuthScreen(),
      },
    );
  }
}
```

## Step 3: Test Authentication (5 minutes)

### 3.1 Run the app
```bash
cd app
flutter run -d windows  # or your platform
```

### 3.2 Sign up a test user
1. App should show `AuthScreen` on first launch
2. Click "Sign Up"
3. Enter email: `test@example.com`
4. Enter password: `testpass123`
5. Click "Sign Up"
6. Check email for verification (for production; dev mode may auto-verify)

### 3.3 Sign in
1. Click "Sign In" toggle
2. Enter same credentials
3. Click "Sign In"
4. Should navigate to home screen

## Step 4: Test Sync (10 minutes)

### 4.1 Create Test Button in UI
Add this to your `DatabaseDemoScreen` or wherever you want to test:

```dart
// In your screen's build method
ElevatedButton(
  onPressed: () async {
    final sync = SyncService(
      database: widget.database,
      supabase: SupabaseService.instance,
      logger: Logger.instance,
    );

    final result = await sync.sync();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sync: $result'),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );
  },
  child: const Text('Sync Now'),
)
```

### 4.2 Test Sync Flow
1. Click "Sync Now" button
2. Check logs for sync activity
3. Go to Supabase dashboard > Table Editor
4. Verify data appears in your tables

### 4.3 Test Multi-Device Sync
1. Sign in on second device with same credentials
2. Create data on device 1, click "Sync Now"
3. Click "Sync Now" on device 2
4. Data should appear on device 2!

## Troubleshooting

### "Not authenticated" error
- Verify you signed in successfully
- Check: `SupabaseService.instance.isAuthenticated`
- Check logs for auth errors

### "new row violates row-level security policy"
- Make sure `owner_id` column exists on table
- Verify RLS policy is created
- Check that policy uses `auth.uid()`

### Data not syncing
1. Check network connectivity
2. Verify Supabase URL and anon key are correct
3. Check logs with tag 'Sync'
4. Verify `updated_at` column exists and has trigger

### Build errors
```bash
# Regenerate database code
dart run build_runner build --delete-conflicting-outputs

# Clean and reinstall
flutter clean
flutter pub get
```

## What's Next?

Now that sync is working, implement:

1. **Table-specific upsert logic** (see `SYNC_IMPLEMENTATION_SUMMARY.md`)
2. **Repository layer** to auto-record changes
3. **Background sync** for automatic syncing
4. **Sync status UI** (loading indicators, last sync time)
5. **Conflict resolution UI** (when needed)

## Quick Reference

### Check Auth Status
```dart
final isAuth = SupabaseService.instance.isAuthenticated;
final userId = SupabaseService.instance.currentUserId;
```

### Manual Sync
```dart
final sync = SyncService(...);
final result = await sync.sync();
print(result); // SyncResult(pulled: 5, pushed: 3, duration: 2s)
```

### Check Pending Changes
```dart
final pending = await syncService.getPendingChangesCount();
print('Pending: $pending changes');
```

### Sign Out
```dart
await SupabaseService.instance.signOut();
Navigator.pushReplacementNamed(context, '/auth');
```

## Success! 🎉

You now have:
- ✅ Cloud authentication
- ✅ Bidirectional sync (pull & push)
- ✅ Offline-first architecture
- ✅ Row-level security
- ✅ Multi-device support

For full implementation details, see:
- `SUPABASE_SETUP.md` - Complete backend setup
- `CLOUD_SYNC.md` - Architecture deep dive
- `SYNC_IMPLEMENTATION_SUMMARY.md` - What's done and what's next
