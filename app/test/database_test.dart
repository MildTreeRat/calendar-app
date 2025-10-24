import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/database/database.dart';
import 'package:app/logging/logger.dart';
import 'package:matcher/matcher.dart' as matcher;

void main() {
  late AppDatabase database;

  setUpAll(() async {
    // Initialize logger for tests (silent)
    await Logger.initialize(
      config: const LoggerConfig(
        level: LogLevel.error, // Only errors
        console: false, // No console output during tests
      ),
    );
  });

  setUp(() {
    // Create in-memory database for testing
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  group('Database Initialization', () {
    test('should create all tables without errors', () async {
      // Just accessing the database should trigger onCreate
      final users = await database.select(database.users).get();
      expect(users, isNotEmpty); // Should have seeded default user
    });

    test('should seed default user with profile', () async {
      final users = await database.select(database.users).get();
      expect(users.length, 1);
      expect(users.first.id, isNotEmpty); // Dynamic ID

      final profiles = await database.select(database.userProfiles).get();
      expect(profiles.length, 1);
      expect(profiles.first.userId, users.first.id); // Should match user
      expect(profiles.first.displayName, 'User');
    });

    test('should seed default calendar', () async {
      final calendars = await database.select(database.calendars).get();
      expect(calendars.length, 1);
      expect(calendars.first.name, 'Planning');
    });

    test('should seed default color palette', () async {
      final palettes = await database.select(database.colorPalettes).get();
      expect(palettes.length, 1);
      expect(palettes.first.name, 'Default');

      final colors = await database.select(database.paletteColors).get();
      expect(colors.length, greaterThan(0));
    });
  });

  group('Users and Profiles', () {
    test('should create user and profile', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final userId = 'test-user-${DateTime.now().millisecondsSinceEpoch}';

      await database.into(database.users).insert(UsersCompanion(
            id: Value(userId),
            createdAt: Value(now),
            updatedAt: Value(now),
          ));

      await database.into(database.userProfiles).insert(UserProfilesCompanion(
            userId: Value(userId),
            displayName: const Value('Test User'),
            email: const Value('test@example.com'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ));

      final user = await (database.select(database.users)
            ..where((u) => u.id.equals(userId)))
          .getSingle();
      expect(user.id, userId);

      final profile = await (database.select(database.userProfiles)
            ..where((p) => p.userId.equals(userId)))
          .getSingle();
      expect(profile.displayName, 'Test User');
      expect(profile.email, 'test@example.com');
    });

    test('should soft delete user', () async {
      final users = await database.select(database.users).get();
      final userId = users.first.id;
      final now = DateTime.now().millisecondsSinceEpoch;

      await (database.update(database.users)
            ..where((u) => u.id.equals(userId)))
          .write(UsersCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ));

      final user = await (database.select(database.users)
            ..where((u) => u.id.equals(userId)))
          .getSingle();
      expect(user.deletedAt, matcher.isNotNull);
    });
  });

  group('Accounts', () {
    test('should create Google account', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final users = await database.select(database.users).get();
      final userId = users.first.id;

      final accountId = 'account-${DateTime.now().millisecondsSinceEpoch}';
      await database.into(database.accounts).insert(AccountsCompanion(
            id: Value(accountId),
            userId: Value(userId),
            provider: const Value('google'),
            subject: const Value('google-user-123'),
            label: const Value('Google Account'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ));

      final account = await (database.select(database.accounts)
            ..where((a) => a.id.equals(accountId)))
          .getSingle();
      expect(account.provider, 'google');
      expect(account.subject, 'google-user-123');
    });

    test('should prevent duplicate provider/subject', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final users = await database.select(database.users).get();
      final userId = users.first.id;

      await database.into(database.accounts).insert(AccountsCompanion(
            id: Value('account-1-$now'),
            userId: Value(userId),
            provider: const Value('apple'),
            subject: const Value('apple-user-xyz'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ));

      // Try to insert duplicate
      expect(
        database.into(database.accounts).insert(AccountsCompanion(
              id: Value('account-2-$now'),
              userId: Value(userId),
              provider: const Value('apple'),
              subject: const Value('apple-user-xyz'),
              createdAt: Value(now),
              updatedAt: Value(now),
            )),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  group('Calendars', () {
    test('should create calendar with membership', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final users = await database.select(database.users).get();
      final userId = users.first.id;

      final calendarId = 'calendar-${DateTime.now().millisecondsSinceEpoch}';
      await database.into(database.calendars).insert(CalendarsCompanion(
            id: Value(calendarId),
            userId: Value(userId),
            source: const Value('local'),
            name: const Value('Work Calendar'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ));

      await database.into(database.calendarMemberships).insert(
            CalendarMembershipsCompanion(
              userId: Value(userId),
              calendarId: Value(calendarId),
              visible: const Value(true),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      final calendar = await (database.select(database.calendars)
            ..where((c) => c.id.equals(calendarId)))
          .getSingle();
      expect(calendar.name, 'Work Calendar');

      final membership = await (database.select(database.calendarMemberships)
            ..where((m) => m.calendarId.equals(calendarId)))
          .getSingle();
      expect(membership.visible, true);
    });
  });

  group('Events', () {
    test('should create event with recurrence', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final calendars = await database.select(database.calendars).get();
      final calendarId = calendars.first.id;

      final eventId = 'event-${DateTime.now().millisecondsSinceEpoch}';
      await database.into(database.events).insert(EventsCompanion(
            id: Value(eventId),
            calendarId: Value(calendarId),
            uid: const Value('event@example.com'),
            title: const Value('Team Meeting'),
            rrule: const Value('FREQ=WEEKLY;BYDAY=MO'),
            startMs: Value(now),
            endMs: Value(now + 3600000), // +1 hour
            createdAt: Value(now),
            updatedAt: Value(now),
          ));

      final event = await (database.select(database.events)
            ..where((e) => e.id.equals(eventId)))
          .getSingle();
      expect(event.title, 'Team Meeting');
      expect(event.rrule, 'FREQ=WEEKLY;BYDAY=MO');
    });

    test('should store exception dates as JSON', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final calendars = await database.select(database.calendars).get();
      final calendarId = calendars.first.id;

      final eventId = 'event-ex-$now';
      final exdates = '["2025-01-06", "2025-01-13"]';

      await database.into(database.events).insert(EventsCompanion(
            id: Value(eventId),
            calendarId: Value(calendarId),
            uid: Value('event-ex@example.com'),
            title: const Value('Recurring Event'),
            rrule: const Value('FREQ=WEEKLY'),
            exdates: Value(exdates),
            startMs: Value(now),
            endMs: Value(now + 3600000),
            createdAt: Value(now),
            updatedAt: Value(now),
          ));

      final event = await (database.select(database.events)
            ..where((e) => e.id.equals(eventId)))
          .getSingle();
      expect(event.exdates, exdates);
    });
  });

  group('Tasks', () {
    test('should create task list and tasks', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final users = await database.select(database.users).get();
      final userId = users.first.id;

      final listId = 'tasklist-$now';
      await database.into(database.taskLists).insert(TaskListsCompanion(
            id: Value(listId),
            userId: Value(userId),
            source: const Value('local'),
            name: const Value('Todo'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ));

      final taskId = 'task-$now';
      await database.into(database.tasks).insert(TasksCompanion(
            id: Value(taskId),
            taskListId: Value(listId),
            title: const Value('Buy groceries'),
            priority: const Value(1),
            createdAt: Value(now),
            updatedAt: Value(now),
          ));

      final task = await (database.select(database.tasks)
            ..where((t) => t.id.equals(taskId)))
          .getSingle();
      expect(task.title, 'Buy groceries');
      expect(task.priority, 1);
    });

    test('should mark task as completed', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final users = await database.select(database.users).get();
      final userId = users.first.id;

      final listId = 'list-complete-$now';
      await database.into(database.taskLists).insert(TaskListsCompanion(
            id: Value(listId),
            userId: Value(userId),
            source: const Value('local'),
            name: const Value('Chores'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ));

      final taskId = 'task-complete-$now';
      await database.into(database.tasks).insert(TasksCompanion(
            id: Value(taskId),
            taskListId: Value(listId),
            title: const Value('Clean room'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ));

      final completedTime = DateTime.now().millisecondsSinceEpoch;
      await (database.update(database.tasks)
            ..where((t) => t.id.equals(taskId)))
          .write(TasksCompanion(
        completedMs: Value(completedTime),
        updatedAt: Value(completedTime),
      ));

      final task = await (database.select(database.tasks)
            ..where((t) => t.id.equals(taskId)))
          .getSingle();
      expect(task.completedMs, matcher.isNotNull);
    });
  });

  group('Color Palettes', () {
    test('should create palette with colors', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final users = await database.select(database.users).get();
      final userId = users.first.id;

      final paletteId = 'palette-$now';
      await database.into(database.colorPalettes).insert(ColorPalettesCompanion(
            id: Value(paletteId),
            userId: Value(userId),
            name: const Value('Custom'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ));

      // Add 3 colors
      for (int i = 0; i < 3; i++) {
        await database.into(database.paletteColors).insert(PaletteColorsCompanion(
              id: Value('color-$now-$i'),
              paletteId: Value(paletteId),
              ordinal: Value(i),
              hex: Value('#${(i + 1).toString().padLeft(6, '0')}'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ));
      }

      final colors = await (database.select(database.paletteColors)
            ..where((c) => c.paletteId.equals(paletteId))
            ..orderBy([(c) => OrderingTerm.asc(c.ordinal)]))
          .get();
      expect(colors.length, 3);
      expect(colors[0].hex, '#000001');
      expect(colors[1].hex, '#000002');
      expect(colors[2].hex, '#000003');
    });
  });

  group('ICS Sources', () {
    test('should create ICS subscription', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final calendars = await database.select(database.calendars).get();
      final calendarId = calendars.first.id;

      final sourceId = 'source-$now';
      await database.into(database.icsSources).insert(IcsSourcesCompanion(
            id: Value(sourceId),
            calendarId: Value(calendarId),
            url: const Value('https://calendar.example.com/events.ics'),
            etag: const Value('abc123'),
            lastFetchMs: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ));

      final source = await (database.select(database.icsSources)
            ..where((s) => s.id.equals(sourceId)))
          .getSingle();
      expect(source.url, 'https://calendar.example.com/events.ics');
      expect(source.etag, 'abc123');
    });
  });

  group('Foreign Key Constraints', () {
    test('should cascade delete user profile when user deleted', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final userId = 'cascade-user-$now';

      await database.into(database.users).insert(UsersCompanion(
            id: Value(userId),
            createdAt: Value(now),
            updatedAt: Value(now),
          ));

      await database.into(database.userProfiles).insert(UserProfilesCompanion(
            userId: Value(userId),
            displayName: const Value('Cascade Test'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ));

      await (database.delete(database.users)..where((u) => u.id.equals(userId)))
          .go();

      final profiles = await (database.select(database.userProfiles)
            ..where((p) => p.userId.equals(userId)))
          .get();
      expect(profiles.isEmpty, true);
    });

    test('should cascade delete calendar events when calendar deleted',
        () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final users = await database.select(database.users).get();
      final userId = users.first.id;

      final calendarId = 'cascade-cal-$now';
      await database.into(database.calendars).insert(CalendarsCompanion(
            id: Value(calendarId),
            userId: Value(userId),
            source: const Value('local'),
            name: const Value('Temp Calendar'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ));

      final eventId = 'cascade-event-$now';
      await database.into(database.events).insert(EventsCompanion(
            id: Value(eventId),
            calendarId: Value(calendarId),
            uid: Value('cascade@example.com'),
            title: const Value('Temp Event'),
            startMs: Value(now),
            endMs: Value(now + 3600000),
            createdAt: Value(now),
            updatedAt: Value(now),
          ));

      await (database.delete(database.calendars)
            ..where((c) => c.id.equals(calendarId)))
          .go();

      final events = await (database.select(database.events)
            ..where((e) => e.calendarId.equals(calendarId)))
          .get();
      expect(events.isEmpty, true);
    });
  });

  group('Metadata JSON Validation', () {
    test('should accept valid JSON metadata', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final userId = 'json-user-$now';

      await database.into(database.users).insert(UsersCompanion(
            id: Value(userId),
            createdAt: Value(now),
            updatedAt: Value(now),
            metadata: const Value('{"key": "value", "count": 42}'),
          ));

      final user = await (database.select(database.users)
            ..where((u) => u.id.equals(userId)))
          .getSingle();
      expect(user.metadata, '{"key": "value", "count": 42}');
    });

    test('should reject invalid JSON metadata', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final userId = 'bad-json-$now';

      expect(
        database.into(database.users).insert(UsersCompanion(
              id: Value(userId),
              createdAt: Value(now),
              updatedAt: Value(now),
              metadata: const Value('not valid json {'),
            )),
        throwsA(isA<SqliteException>()),
      );
    });
  });
}
