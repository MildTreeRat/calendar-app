# Cloud Sync Implementation Summary

## What's Been Built

We've successfully implemented the foundation for **offline-first cloud sync** using Supabase as the backend. Here's what's ready:

### ✅ Completed Components

#### 1. **Dependencies Added** (`pubspec.yaml`)
- `supabase_flutter`: Supabase client SDK for auth and database access
- `flutter_secure_storage`: Secure device ID storage
- `connectivity_plus`: Network connectivity detection

#### 2. **Database Tables** (`lib/database/tables/sync.dart`)
- **SyncState**: Tracks `last_pull_ms` and `last_push_ms` per table
- **Changes**: Outbox for pending local changes (operation, payload, timestamps)
- **DeviceInfo**: Stores persistent device ID for conflict resolution

#### 3. **Services Layer**

**DeviceIdService** (`lib/services/device_id_service.dart`)
- Generates and persists UUIDv4 device ID
- Uses secure storage (keychain/keystore)
- Caches in memory for performance

**SupabaseService** (`lib/services/supabase_service.dart`)
- Initializes Supabase with project credentials
- Auth methods: `signInWithPassword()`, `signUpWithPassword()`, `signOut()`, `resetPassword()`
- Auth state listener
- Database access helpers
- Comprehensive logging

**SyncService** (`lib/services/sync_service.dart`)
- **Pull logic**: Server → Device (delta sync with pagination)
- **Push logic**: Device → Server (outbox pattern)
- Conflict resolution (Last Write Wins)
- Per-table sync with foreign key ordering
- Change recording for outbox
- Sync state management
- Pending changes tracking
- Outbox cleanup

#### 4. **UI Components**

**AuthScreen** (`lib/screens/auth_screen.dart`)
- Email/password sign in/sign up
- Password visibility toggle
- Form validation
- Forgot password flow
- Error handling and loading states
- Responsive design (max 400px width)

#### 5. **Documentation**

**SUPABASE_SETUP.md** (`docs/SUPABASE_SETUP.md`)
- Complete SQL scripts for Supabase setup
- `owner_id` column additions
- `updated_at` trigger function
- Row Level Security (RLS) policies
- Indexes for performance
- Testing instructions
- Troubleshooting guide

**CLOUD_SYNC.md** (`docs/CLOUD_SYNC.md`)
- Architecture overview
- Sync flow diagrams
- Usage examples
- Background sync setup (Android/iOS)
- Security best practices
- Monitoring and debugging
- Troubleshooting guide

**SupabaseConfig** (`lib/config/supabase_config.dart`)
- Configuration template for credentials
- Security warnings

---

## What Still Needs to be Done

### 🔨 Critical Implementation Tasks

#### 1. **Table-Specific Upsert Logic** ⚠️ REQUIRED
**Location**: `SyncService._upsertLocalRow()` in `lib/services/sync_service.dart`

Currently this method just logs. You need to implement actual Drift insert/update logic for each table:

```dart
Future<void> _upsertLocalRow(String table, Map<String, dynamic> row) async {
  final deletedAt = row['deleted_at'] as int?;

  switch (table) {
    case 'user':
      await _db.into(_db.users).insertOnConflictUpdate(
        UsersCompanion.insert(
          id: row['id'],
          displayName: row['display_name'],
          email: row['email'],
          // ... map all fields
          updatedAt: row['updated_at'],
          deletedAt: Value(deletedAt),
        ),
      );
      break;

    case 'event':
      await _db.into(_db.events).insertOnConflictUpdate(
        EventsCompanion.insert(
          id: row['id'],
          calendarId: row['calendar_id'],
          title: Value(row['title']),
          // ... map all fields
          updatedAt: row['updated_at'],
          deletedAt: Value(deletedAt),
        ),
      );
      break;

    // Repeat for all 13 synced tables...
  }
}
```

#### 2. **Repository Layer with Change Tracking** ⚠️ REQUIRED
Create repository classes that wrap database operations and automatically record changes:

**Example**: `lib/repositories/events_repository.dart`
```dart
class EventsRepository {
  final AppDatabase _db;
  final SyncService _sync;

  EventsRepository(this._db, this._sync);

  Future<void> insertEvent(EventsCompanion event) async {
    // Insert into local database
    await _db.into(_db.events).insert(event);

    // Record change for sync
    await _sync.recordChange(
      table: 'event',
      rowId: event.id.value,
      operation: 'insert',
      payload: _eventToJson(event),
    );
  }

  Future<void> updateEvent(String id, EventsCompanion event) async {
    await (_db.update(_db.events)..where((t) => t.id.equals(id)))
      .write(event);

    await _sync.recordChange(
      table: 'event',
      rowId: id,
      operation: 'update',
      payload: _eventToJson(event),
    );
  }

  Future<void> deleteEvent(String id) async {
    // Soft delete
    await (_db.update(_db.events)..where((t) => t.id.equals(id)))
      .write(EventsCompanion(deletedAt: Value(DateTime.now().millisecondsSinceEpoch)));

    await _sync.recordChange(
      table: 'event',
      rowId: id,
      operation: 'delete',
      payload: {'id': id},
    );
  }
}
```

Create similar repositories for:
- UsersRepository
- CalendarsRepository
- TasksRepository
- ColorPalettesRepository
- etc.

#### 3. **Supabase Backend Setup** ⚠️ REQUIRED
Follow the instructions in `docs/SUPABASE_SETUP.md`:

1. Create Supabase project at https://supabase.com
2. Run all SQL scripts (owner_id, triggers, RLS, policies)
3. Copy your project URL and anon key
4. Update `lib/config/supabase_config.dart`:
   ```dart
   static const String url = 'https://your-project.supabase.co';
   static const String anonKey = 'eyJhbGc...'; // Your actual anon key
   ```

#### 4. **Initialize Services in main.dart** ⚠️ REQUIRED
```dart
import 'package:flutter/material.dart';
import 'logging/logger.dart';
import 'services/supabase_service.dart';
import 'services/sync_service.dart';
import 'database/database.dart';
import 'config/supabase_config.dart';
import 'screens/auth_screen.dart';

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

  // Create sync service
  final syncService = SyncService(
    database: database,
    supabase: SupabaseService.instance,
    logger: Logger.instance,
  );

  runApp(MyApp(
    database: database,
    syncService: syncService,
  ));
}

class MyApp extends StatelessWidget {
  final AppDatabase database;
  final SyncService syncService;

  const MyApp({
    super.key,
    required this.database,
    required this.syncService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calendar App',
      home: SupabaseService.instance.isAuthenticated
          ? HomePage(database: database, syncService: syncService)
          : const AuthScreen(),
      routes: {
        '/home': (context) => HomePage(database: database, syncService: syncService),
        '/auth': (context) => const AuthScreen(),
      },
    );
  }
}
```

### 📱 Optional Enhancements

#### 5. **Background Sync** (Recommended)
- **Android**: Implement with `workmanager` package
- **iOS**: Configure Background Tasks in Xcode
- See `docs/CLOUD_SYNC.md` for detailed setup

#### 6. **Sync UI Indicators** (Recommended)
```dart
// Show sync status in app bar
StreamBuilder<bool>(
  stream: syncService.isSyncingStream,
  builder: (context, snapshot) {
    return snapshot.data == true
      ? CircularProgressIndicator()
      : Icon(Icons.cloud_done);
  },
)
```

#### 7. **Conflict Resolution UI** (Future)
- Currently uses Last Write Wins automatically
- Could add UI for user to choose which version to keep

#### 8. **Shared Calendars** (Future)
- Add `shared_feed` table
- Create Supabase Edge Function for `.ics` serving
- Token-based read-only access

---

## Testing Your Implementation

### 1. **Run Code Generation**
```bash
cd app
dart run build_runner build --delete-conflicting-outputs
```

### 2. **Install Dependencies**
```bash
flutter pub get
```

### 3. **Setup Supabase**
Follow `docs/SUPABASE_SETUP.md`

### 4. **Test Authentication**
```dart
// In your debug/test code
final supabase = SupabaseService.instance;

// Test sign up
await supabase.signUpWithPassword(
  email: 'test@example.com',
  password: 'testpass123',
);

// Test sign in
await supabase.signInWithPassword(
  email: 'test@example.com',
  password: 'testpass123',
);

print('Authenticated: ${supabase.isAuthenticated}');
```

### 5. **Test Sync**
```dart
final sync = SyncService(
  database: database,
  supabase: SupabaseService.instance,
  logger: Logger.instance,
);

// Perform full sync
final result = await sync.sync();
print(result); // SyncResult(pulled: 0, pushed: 5, duration: 2s)

// Check pending changes
final pending = await sync.getPendingChangesCount();
print('Pending: $pending');
```

---

## File Structure

```
lib/
├── config/
│   └── supabase_config.dart          ✅ Config template
├── database/
│   ├── database.dart                 ✅ Updated with sync tables
│   └── tables/
│       └── sync.dart                 ✅ SyncState, Changes, DeviceInfo
├── screens/
│   └── auth_screen.dart              ✅ Sign in/sign up UI
└── services/
    ├── device_id_service.dart        ✅ Device ID management
    ├── supabase_service.dart         ✅ Auth and database access
    └── sync_service.dart             ✅ Pull/push sync logic

docs/
├── SUPABASE_SETUP.md                 ✅ Backend setup guide
└── CLOUD_SYNC.md                     ✅ Sync architecture docs
```

---

## Key Design Decisions

### Why Supabase?
- Built on PostgreSQL (SQL you already know)
- Built-in auth with JWT
- Row Level Security (secure by default)
- Real-time subscriptions (future enhancement)
- Auto-generated REST API

### Why Offline-First?
- App works without internet
- Better UX (instant feedback)
- Handles network flakiness
- Reduces server load
- Users own their data

### Why Outbox Pattern?
- Reliable change tracking
- Retry failed syncs
- Audit trail
- Easy debugging
- Can batch operations

### Why Last Write Wins?
- Simple to implement
- Works for most use cases
- Deterministic (device_id tiebreaker)
- Can upgrade to 3-way merge later

---

## Next Steps

1. **Implement table-specific upserts** in `_upsertLocalRow()` (1-2 hours)
2. **Create repository layer** with change tracking (2-4 hours)
3. **Setup Supabase project** and run SQL scripts (30 minutes)
4. **Update config** with your Supabase credentials (5 minutes)
5. **Initialize in main.dart** (15 minutes)
6. **Test auth flow** (15 minutes)
7. **Test sync** with real data (30 minutes)
8. **Add background sync** (2-4 hours)

**Total estimated time**: 1-2 days of focused work

---

## Questions?

Refer to:
- `docs/SUPABASE_SETUP.md` - Backend setup
- `docs/CLOUD_SYNC.md` - Architecture and usage
- Supabase docs: https://supabase.com/docs
- Drift docs: https://drift.simonbinder.eu

## You're Ready! 🚀

The foundation is solid. Once you complete the critical tasks above, you'll have a production-ready offline-first calendar app with cloud sync!
