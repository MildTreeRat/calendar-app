import 'dart:io';
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../logging/logger.dart';

// Table imports
part 'tables/users.dart';
part 'tables/accounts.dart';
part 'tables/calendars.dart';
part 'tables/events.dart';
part 'tables/tasks.dart';
part 'tables/colors.dart';
part 'tables/ics_sources.dart';
part 'tables/sync.dart';

// Generated code
part 'database.g.dart';

@DriftDatabase(tables: [
  Users,
  UserProfiles,
  Accounts,
  Calendars,
  CalendarMemberships,
  CalendarGroups,
  CalendarGroupMaps,
  Events,
  TaskLists,
  Tasks,
  ColorPalettes,
  PaletteColors,
  IcsSources,
  SyncState,
  Changes,
  DeviceInfo,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  // Test constructor for in-memory databases
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2; // Incremented to add changes table

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        final logger = Logger.instance;
        logger.info('Creating database schema v2', tag: 'Database');
        await m.createAll();

        // Create indexes for performance
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_event_cal_time ON events(calendar_id, start_ms)'
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_membership_user ON calendar_memberships(user_id, visible)'
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_event_time_range ON events(start_ms, end_ms)'
        );

        logger.info('Database schema created successfully', tag: 'Database');
      },
      onUpgrade: (Migrator m, int from, int to) async {
        final logger = Logger.instance;
        logger.info('Migrating database from v$from to v$to', tag: 'Database');

        // Migration from v1 to v2: Add changes, sync_state, and device_info tables
        if (from == 1 && to >= 2) {
          logger.info('Adding changes table for sync support', tag: 'Database');

          // Create changes table
          await m.createTable(changes);

          // Create sync_state table if it doesn't exist
          await m.createTable(syncState);

          // Create device_info table if it doesn't exist
          await m.createTable(deviceInfo);

          logger.info('Migration v1 -> v2 completed successfully', tag: 'Database');
        }
      },
      beforeOpen: (details) async {
        final logger = Logger.instance;

        // Enable foreign keys
        await customStatement('PRAGMA foreign_keys = ON');

        if (details.wasCreated) {
          logger.info('Database created, running seed data', tag: 'Database');
          await _seedDatabase();
        }

        logger.info('Database opened (version ${details.versionNow})',
          tag: 'Database',
          metadata: {
            'wasCreated': details.wasCreated,
            'hadUpgrade': details.hadUpgrade,
          },
        );
      },
    );
  }

  /// Seed initial data
  Future<void> _seedDatabase() async {
    final logger = Logger.instance;

    try {
      // Create default user
      final userId = _generateId();
      await into(users).insert(
        UsersCompanion.insert(
          id: userId,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          metadata: Value('{}'),
        ),
      );

      // Create user profile
      await into(userProfiles).insert(
        UserProfilesCompanion.insert(
          userId: userId,
          displayName: const Value('User'),
          email: const Value(null),
          tzid: Value(DateTime.now().timeZoneName),
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          metadata: Value('{}'),
        ),
      );

      // Create default local account
      final accountId = _generateId();
      await into(accounts).insert(
        AccountsCompanion.insert(
          id: accountId,
          userId: userId,
          provider: 'local',
          subject: userId,
          label: const Value('Local'),
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          metadata: Value('{}'),
        ),
      );

      // Create "Planning" calendar
      final calendarId = _generateId();
      await into(calendars).insert(
        CalendarsCompanion.insert(
          id: calendarId,
          accountId: Value(accountId),
          userId: userId,
          name: 'Planning',
          color: const Value('#4285F4'),
          source: 'local',
          readOnly: const Value(false),
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          metadata: Value('{}'),
        ),
      );

      // Create calendar membership
      await into(calendarMemberships).insert(
        CalendarMembershipsCompanion.insert(
          userId: userId,
          calendarId: calendarId,
          visible: const Value(true),
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      // Create default color palette
      final paletteId = _generateId();
      await into(colorPalettes).insert(
        ColorPalettesCompanion.insert(
          id: paletteId,
          userId: userId,
          name: 'Default',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          metadata: Value('{}'),
        ),
      );

      // Add default colors to palette
      final defaultColors = [
        '#4285F4', // Blue
        '#EA4335', // Red
        '#FBBC04', // Yellow
        '#34A853', // Green
        '#FF6D01', // Orange
        '#46BDC6', // Cyan
        '#7BAAF7', // Light Blue
        '#F439A0', // Pink
      ];

      for (var i = 0; i < defaultColors.length; i++) {
        await into(paletteColors).insert(
          PaletteColorsCompanion.insert(
            id: _generateId(),
            paletteId: paletteId,
            ordinal: i,
            hex: defaultColors[i],
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }

      logger.info('Database seeded successfully',
        tag: 'Database',
        metadata: {
          'userId': userId,
          'calendarId': calendarId,
          'paletteId': paletteId,
        },
      );
    } catch (e, stack) {
      logger.error('Failed to seed database',
        tag: 'Database',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Generate ULID-style ID (timestamp + random)
  String _generateId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999); // 0 to 999999
    return '${timestamp}_$random';
  }
}

/// Open database connection
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final logger = Logger.instance;
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'calendar.db'));

    logger.info('Opening database',
      tag: 'Database',
      metadata: {'path': file.path},
    );

    // Configure SQLite for better performance
    return NativeDatabase.createInBackground(
      file,
      setup: (database) {
        // Enable WAL mode for better concurrency
        database.execute('PRAGMA journal_mode = WAL');
        database.execute('PRAGMA synchronous = NORMAL');
        database.execute('PRAGMA temp_store = MEMORY');
        database.execute('PRAGMA mmap_size = 30000000000');
      },
    );
  });
}
