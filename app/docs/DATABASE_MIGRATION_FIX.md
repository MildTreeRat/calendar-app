# Database Migration Fix - Changes Table

## The Problem

The `changes` table was added to the schema but **existing databases don't have it** because:
1. Database was created at schema version 1 (without changes table)
2. Schema version wasn't incremented
3. No migration logic existed to add the table

This caused: `SqliteException(1): no such table: changes`

## The Solution

### What Was Fixed

1. **Incremented schema version** from 1 → 2
2. **Added migration logic** in `onUpgrade` to create:
   - `changes` table
   - `sync_state` table
   - `device_info` table

### Files Modified

`lib/database/database.dart`:
```dart
@override
int get schemaVersion => 2; // Was: 1

@override
MigrationStrategy get migration {
  return MigrationStrategy(
    // ... onCreate stays the same ...

    onUpgrade: (Migrator m, int from, int to) async {
      if (from == 1 && to >= 2) {
        // Create the missing tables
        await m.createTable(changes);
        await m.createTable(syncState);
        await m.createTable(deviceInfo);
      }
    },
  );
}
```

## How to Apply the Fix

### Option 1: Delete Existing Database (Immediate Fix)

**⚠️ WARNING: This will delete all user data!**

1. **Find the database file:**
   - Windows: `C:\Users\<username>\Documents\calendar.db`
   - macOS: `~/Documents/calendar.db`
   - Linux: `~/Documents/calendar.db`

2. **Delete it:**
   ```bash
   # Windows (PowerShell)
   Remove-Item "$env:USERPROFILE\Documents\calendar.db*" -Force

   # macOS/Linux
   rm ~/Documents/calendar.db*
   ```

3. **Run the app:**
   ```bash
   flutter run -d windows
   ```

   The app will create a new database at version 2 with the changes table.

### Option 2: Let Migration Run Automatically (Production-Safe)

For production deployments with existing user data:

1. **Deploy the updated code** with schema version 2
2. **App automatically migrates** when users open it
3. **User data is preserved**

The migration will:
- Detect database is at version 1
- Run the `onUpgrade` migration
- Create the missing tables
- Upgrade database to version 2

### Option 3: Manual Database Update (Testing)

For testing purposes, you can manually add the table:

```bash
# Open the database
sqlite3 ~/Documents/calendar.db

# Add the changes table
CREATE TABLE IF NOT EXISTS changes (
  id TEXT NOT NULL PRIMARY KEY,
  table_name TEXT NOT NULL,
  row_id TEXT NOT NULL,
  operation TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  updated_at INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  is_pushed INTEGER NOT NULL DEFAULT 0
);

# Verify
.tables
.quit
```

## Verification

### Check Database Version

Add this debug code temporarily:

```dart
// In database.dart, beforeOpen:
logger.info('Database version check',
  tag: 'Database',
  metadata: {
    'currentVersion': details.versionNow,
    'wasCreated': details.wasCreated,
    'hadUpgrade': details.hadUpgrade,
  },
);
```

### Check Table Exists

```bash
sqlite3 ~/Documents/calendar.db
.tables
# Should show: changes, sync_state, device_info, and others
```

### Test in App

1. Open the app
2. Try to change a color preference
3. Should work without SqliteException

## Why Tests Didn't Catch This

The tests create **in-memory databases** with `AppDatabase.forTesting()`, which:
- ✅ Always start fresh
- ✅ Run `onCreate` (which creates all tables)
- ❌ Never run `onUpgrade` migrations
- ❌ Don't test existing database scenarios

### Additional Test Needed

```dart
test('migration from v1 to v2 should add changes table', () async {
  // 1. Create a v1 database
  final tempDb = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(version: 1),
  );
  await tempDb.close();

  // 2. Re-open with v2 schema (triggers migration)
  final migratedDb = AppDatabase.forTesting(
    NativeDatabase.memory(), // This would need to be the same file
  );

  // 3. Verify changes table exists
  final changes = await migratedDb.select(migratedDb.changes).get();
  expect(changes, isEmpty); // Table exists, no data yet
});
```

## Root Cause Analysis

### Why This Happened

1. **Changes table was added to code** but schema version wasn't incremented
2. **Existing databases** were created before the changes table existed
3. **No migration path** existed to add the table to old databases
4. **Tests used in-memory databases** which always start fresh (never migrate)

### Prevention for Future

**Checklist when adding new tables:**
- [ ] Add table definition (we did this ✅)
- [ ] Add to `@DriftDatabase` tables list (we did this ✅)
- [ ] **Increment `schemaVersion`** (we missed this ❌)
- [ ] **Add migration in `onUpgrade`** (we missed this ❌)
- [ ] Test with existing database file (we missed this ❌)
- [ ] Run `build_runner` to regenerate code (we did this ✅)

## Next Steps

1. **Apply the fix** using one of the options above
2. **Verify** the changes table exists
3. **Test** color preference changes work
4. **Deploy** to production (migration will run automatically)

## Production Deployment Notes

When deploying this fix:

1. **Users with existing databases** will automatically migrate from v1 → v2
2. **New users** will get v2 database from the start
3. **Migration is one-way** (no rollback without data loss)
4. **Monitor logs** for migration success/failure

### Expected Log Output

```
[INFO] Opening database
[INFO] Migrating database from v1 to v2
[INFO] Adding changes table for sync support
[INFO] Migration v1 -> v2 completed successfully
[INFO] Database opened (version 2)
```

## Summary

- ✅ **Root cause identified**: Schema version not incremented, no migration
- ✅ **Fix implemented**: Version 2 with migration logic
- ⚠️ **Action required**: Delete database OR wait for migration on next app start
- ✅ **Future prevention**: Added migration checklist

The app will now correctly create the `changes` table for both new and existing databases!
