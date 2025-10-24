# Cloud Sync Implementation

This document explains the cloud sync architecture and how to use it.

## Architecture Overview

```
┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│   Flutter App   │ ───► │  Local SQLite   │ ◄─── │     Supabase    │
│  (UI + Logic)   │      │   (Drift ORM)   │      │   (PostgreSQL)  │
└─────────────────┘      └─────────────────┘      └─────────────────┘
         │                        │                         │
         │                        │                         │
         ▼                        ▼                         ▼
   User Actions            Offline-First             Cloud Storage
   (CRUD ops)              Source of Truth           + Auth + RLS
```

## Key Concepts

### 1. Offline-First Design

- **SQLite is the source of truth** on device
- App works fully offline
- Changes are queued in the `changes` table (outbox pattern)
- Sync happens when network is available

### 2. Delta Sync

- Only rows modified since last sync are transferred
- Uses `updated_at` timestamps for change detection
- Pagination prevents memory issues with large datasets

### 3. Conflict Resolution

- **Last Write Wins (LWW)** by default
- `updated_at` timestamp determines winner
- `device_id` breaks ties (deterministic)
- Future: Three-way merge for complex conflicts

### 4. Soft Deletes

- Rows are never hard-deleted during sync
- `deleted_at` timestamp marks deletion
- Allows sync of deletions across devices
- Cleanup happens periodically (configurable)

## Sync Flow

### Pull Phase (Server → Device)

```
1. Get last_pull_ms from sync_state table
2. Query Supabase for rows where updated_at > last_pull_ms
3. Upsert rows into local SQLite (by id)
4. Apply soft deletes (where deleted_at != null)
5. Update sync_state.last_pull_ms = max(updated_at)
```

### Push Phase (Device → Server)

```
1. Get unpushed changes from outbox (where is_pushed = false)
2. For each change:
   a. Add owner_id and device_id metadata
   b. Upsert to Supabase (insert or update by id)
   c. Handle conflict: server returns 409 if stale
3. Mark changes as pushed (is_pushed = true)
4. Update sync_state.last_push_ms = now()
```

## Tables

### Local (SQLite) Only

- **sync_state**: Tracks last pull/push timestamps per table
- **changes**: Outbox of pending changes (operations waiting to sync)
- **device_info**: Stores device_id and other device metadata

### Synced Tables

All user data tables are synced:
- user, user_profile
- account
- calendar, calendar_membership, calendar_group, calendar_group_map
- event
- task_list, task
- color_palette, palette_color
- ics_source

## Usage

### 1. Initialize Services

```dart
import 'package:app/services/supabase_service.dart';
import 'package:app/services/sync_service.dart';
import 'package:app/config/supabase_config.dart';

// In main() or app startup
await SupabaseService.initialize(
  supabaseUrl: SupabaseConfig.url,
  supabaseAnonKey: SupabaseConfig.anonKey,
);

final syncService = SyncService(
  database: appDatabase,
  supabase: SupabaseService.instance,
  logger: Logger.instance,
);
```

### 2. Authenticate User

```dart
final supabase = SupabaseService.instance;

// Sign up new user
await supabase.signUpWithPassword(
  email: 'user@example.com',
  password: 'securepassword',
);

// Sign in existing user
await supabase.signInWithPassword(
  email: 'user@example.com',
  password: 'securepassword',
);

// Check auth status
if (supabase.isAuthenticated) {
  print('User ID: ${supabase.currentUserId}');
}
```

### 3. Perform Sync

```dart
// Manual sync (all tables)
final result = await syncService.sync();
print('Sync result: $result');

// Sync specific tables only
await syncService.sync(tables: ['calendar', 'event']);

// WiFi-only sync
await syncService.sync(wifiOnly: true);
```

### 4. Record Local Changes

When you modify data locally, record it in the outbox:

```dart
// After inserting a new event
await syncService.recordChange(
  table: 'event',
  rowId: event.id,
  operation: 'insert',
  payload: {
    'id': event.id,
    'title': event.title,
    'start_time': event.startTime,
    // ... all event fields
  },
);

// After updating an event
await syncService.recordChange(
  table: 'event',
  rowId: event.id,
  operation: 'update',
  payload: eventToJson(event),
);

// After deleting an event (soft delete)
await syncService.recordChange(
  table: 'event',
  rowId: event.id,
  operation: 'delete',
  payload: {'id': event.id},
);
```

### 5. Check Sync Status

```dart
// Get count of pending changes
final pendingCount = await syncService.getPendingChangesCount();
print('Changes waiting to sync: $pendingCount');

// Clean up old pushed changes (optional, runs automatically)
await syncService.cleanupOutbox(maxAge: Duration(days: 7));
```

## Background Sync

### Android (WorkManager)

```dart
// In main.dart or sync setup
import 'package:workmanager/workmanager.dart';

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Initialize services
    await Logger.initialize();
    await SupabaseService.initialize(...);

    final db = AppDatabase();
    final sync = SyncService(database: db, ...);

    // Perform sync
    await sync.sync();

    return true;
  });
}

// Register periodic sync (every 15 minutes)
await Workmanager().initialize(callbackDispatcher);
await Workmanager().registerPeriodicTask(
  'sync-task',
  'sync',
  frequency: Duration(minutes: 15),
  constraints: Constraints(
    networkType: NetworkType.connected,
  ),
);
```

### iOS (Background Tasks)

```swift
// In AppDelegate.swift
import BackgroundTasks

func application(_ application: UIApplication,
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    BGTaskScheduler.shared.register(
        forTaskWithIdentifier: "com.yourapp.sync",
        using: nil
    ) { task in
        self.handleSync(task: task as! BGProcessingTask)
    }

    scheduleSync()
    return true
}

func scheduleSync() {
    let request = BGProcessingTaskRequest(identifier: "com.yourapp.sync")
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
    request.requiresNetworkConnectivity = true

    try? BGTaskScheduler.shared.submit(request)
}
```

## Security

### Row Level Security (RLS)

All data is protected by Supabase RLS policies:

```sql
CREATE POLICY p_event_rw ON event
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());
```

This ensures:
- Users can only read/write their own data
- No user can access another user's data
- Enforced at the database level (not just app)

### Authentication

- Uses Supabase Auth (email/password, OAuth)
- JWT tokens stored securely in keychain/keystore
- Tokens auto-refresh (handled by supabase_flutter)
- Device ID stored in secure storage (flutter_secure_storage)

### Network Security

- All traffic over HTTPS
- Credentials never logged (PII redaction in logger)
- Anon key is safe to bundle in app (RLS provides security)

## Monitoring & Debugging

### Check Sync Logs

```dart
// Logs are automatically written with tag 'Sync'
// Filter logs:
grep -r "tag.*Sync" logs/

// View last sync:
tail -f logs/app_$(date +%Y-%m-%d).log | grep Sync
```

### Inspect Local Database

```bash
# Open SQLite database
sqlite3 ~/Documents/calendar.db

# Check sync state
SELECT * FROM sync_state;

# Check pending changes
SELECT table_name, operation, COUNT(*)
FROM changes
WHERE is_pushed = 0
GROUP BY table_name, operation;

# Check device ID
SELECT * FROM device_info WHERE key = 'device_id';
```

### Test Sync Manually

```dart
// In your test or debug code
final sync = SyncService(/* ... */);

// Test pull
final pullCount = await sync._pullTable('event');
print('Pulled $pullCount events');

// Test push
final pushCount = await sync._pushTable('event');
print('Pushed $pushCount events');
```

## Troubleshooting

### Sync Not Working

1. **Check authentication**: `SupabaseService.instance.isAuthenticated`
2. **Check network**: Use `connectivity_plus` to verify connection
3. **Check RLS policies**: Verify in Supabase dashboard
4. **Check logs**: Look for error messages with tag 'Sync'
5. **Verify timestamps**: Ensure `updated_at` is in milliseconds

### Conflicts

- Current implementation: Last Write Wins
- Check `updated_at` timestamps in logs
- Use `device_id` to identify source of changes

### Data Not Appearing

1. **Check owner_id**: Must match `auth.uid()` in Supabase
2. **Check deleted_at**: Soft-deleted rows won't appear
3. **Verify table-specific upsert**: Implement in `_upsertLocalRow()`

## Next Steps

### Immediate TODOs

1. **Implement table-specific upsert logic** in `SyncService._upsertLocalRow()`
   - Currently just logs, needs actual Drift insert/update
   - Must handle all 13 synced tables

2. **Add repository hooks** to auto-record changes
   - Wrap all CRUD operations
   - Call `syncService.recordChange()` after writes

3. **Setup background sync**
   - Android: WorkManager
   - iOS: Background Tasks
   - Configure retry logic and exponential backoff

### Future Enhancements

- Three-way merge for conflicts (base, local, remote)
- Conflict resolution UI for user to choose
- Batch sync optimization (combine related changes)
- Compression for large payloads
- Delta patches instead of full row sync
- Shared calendars (multi-user collaboration)
- Public .ics feed generation

## Resources

- [Supabase Setup Guide](./SUPABASE_SETUP.md)
- [Drift Documentation](https://drift.simonbinder.eu/)
- [Supabase Flutter Docs](https://supabase.com/docs/reference/dart/introduction)
- [Offline-First Architecture](https://martinfowler.com/articles/patterns-of-distributed-systems/offline-first.html)
