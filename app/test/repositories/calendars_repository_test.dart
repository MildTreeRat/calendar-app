import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/database/database.dart';
import 'package:app/repositories/calendars_repository.dart';
import 'package:app/logging/logger.dart';
import 'package:matcher/matcher.dart' as matcher;

void main() {
  late AppDatabase database;
  late CalendarsRepository repository;
  late String userId;
  late String accountId;

  setUpAll(() async {
    await Logger.initialize(
      config: const LoggerConfig(
        level: LogLevel.error,
        console: false,
      ),
    );
  });

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = CalendarsRepository(db: database);

    // Get seeded user and account
    final users = await database.select(database.users).get();
    userId = users.first.id;

    final accounts = await database.select(database.accounts).get();
    accountId = accounts.first.id;
  });

  tearDown(() async {
    await database.close();
  });

  group('CalendarsRepository - CRUD Operations', () {
    test('should create calendar and record change in changes table', () async {
      final calendar = await repository.insert(
        accountId: accountId,
        userId: userId,
        name: 'Test Calendar',
        color: '#FF0000',
        source: 'local',
      );

      expect(calendar.name, 'Test Calendar');
      expect(calendar.color, '#FF0000');
      expect(calendar.userId, userId);

      // **CRITICAL**: Verify change was recorded in changes table
      final changes = await database.select(database.changes).get();
      final calendarChanges = changes.where((c) =>
        c.tableNameCol == 'calendar' &&
        c.rowId == calendar.id &&
        c.operation == 'INSERT'
      ).toList();

      expect(calendarChanges.length, 1,
        reason: 'Should record calendar creation in changes table - this prevents sync bugs!');
      expect(calendarChanges.first.isPushed, false);
    });

    test('should update calendar and record change in changes table', () async {
      final calendar = await repository.insert(
        accountId: accountId,
        userId: userId,
        name: 'Original Name',
        color: '#FF0000',
        source: 'local',
      );

      // Clear initial changes
      await database.delete(database.changes).go();

      await repository.update(
        id: calendar.id,
        name: 'Updated Name',
        color: '#00FF00',
      );

      final updated = await repository.getById(calendar.id);
      expect(updated?.name, 'Updated Name');
      expect(updated?.color, '#00FF00');

      // **CRITICAL**: Verify update was recorded
      final changes = await database.select(database.changes).get();
      final updateChanges = changes.where((c) =>
        c.tableNameCol == 'calendar' &&
        c.rowId == calendar.id &&
        c.operation == 'UPDATE'
      ).toList();

      expect(updateChanges.length, 1,
        reason: 'Should record calendar update in changes table');
    });

    test('should soft delete calendar and record change in changes table', () async {
      final calendar = await repository.insert(
        accountId: accountId,
        userId: userId,
        name: 'To Delete',
        color: '#0000FF',
        source: 'local',
      );

      // Clear initial changes
      await database.delete(database.changes).go();

      await repository.softDelete(calendar.id);

      final deleted = await repository.getById(calendar.id);
      expect(deleted, matcher.isNotNull); // Still exists but marked deleted
      expect(deleted!.metadata, contains('deleted'));

      // **CRITICAL**: Verify deletion was recorded
      final changes = await database.select(database.changes).get();
      final deleteChanges = changes.where((c) =>
        c.tableNameCol == 'calendar' &&
        c.rowId == calendar.id &&
        c.operation == 'DELETE'
      ).toList();

      expect(deleteChanges.length, 1,
        reason: 'Should record calendar deletion in changes table');
    });

    test('should list calendars for user', () async {
      await repository.insert(
        accountId: accountId,
        userId: userId,
        name: 'Calendar 1',
        color: '#FF0000',
        source: 'local',
      );

      await repository.insert(
        accountId: accountId,
        userId: userId,
        name: 'Calendar 2',
        color: '#00FF00',
        source: 'local',
      );

      final calendars = await repository.getByUser(userId);

      // Should include the seeded "Planning" calendar + 2 new ones
      expect(calendars.length, greaterThanOrEqualTo(3));

      final newCalendars = calendars.where((c) =>
        c.name == 'Calendar 1' || c.name == 'Calendar 2'
      ).toList();
      expect(newCalendars.length, 2);
    });

    test('should toggle calendar visibility and record changes', () async {
      final calendar = await repository.insert(
        accountId: accountId,
        userId: userId,
        name: 'Visibility Test',
        color: '#FF00FF',
        source: 'local',
      );

      // Create membership
      await database.into(database.calendarMemberships).insert(
        CalendarMembershipsCompanion(
          userId: Value(userId),
          calendarId: Value(calendar.id),
          visible: const Value(true),
          createdAt: Value(DateTime.now().millisecondsSinceEpoch),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

      // Clear initial changes
      await database.delete(database.changes).go();

      // Toggle off
      await repository.setVisible(
        userId: userId,
        calendarId: calendar.id,
        visible: false,
      );

      final membership1 = await (database.select(database.calendarMemberships)
        ..where((m) => m.calendarId.equals(calendar.id) & m.userId.equals(userId)))
        .getSingle();
      expect(membership1.visible, false);

      // Verify change recorded
      final changes1 = await database.select(database.changes).get();
      expect(changes1.length, 1, reason: 'Should record visibility change');
      expect(changes1.first.tableNameCol, 'calendar_membership');
      expect(changes1.first.operation, 'UPDATE');

      // Toggle back on
      await repository.setVisible(
        userId: userId,
        calendarId: calendar.id,
        visible: true,
      );

      final membership2 = await (database.select(database.calendarMemberships)
        ..where((m) => m.calendarId.equals(calendar.id) & m.userId.equals(userId)))
        .getSingle();
      expect(membership2.visible, true);

      // Should have 2 changes now
      final changes2 = await database.select(database.changes).get();
      expect(changes2.length, 2, reason: 'Should have recorded both visibility toggles');
    });
  });

  group('CalendarsRepository - Edge Cases', () {
    test('should handle non-existent calendar gracefully', () async {
      final calendar = await repository.getById('non-existent-id');
      expect(calendar, matcher.isNull);
    });

    test('should get calendars by account', () async {
      await repository.insert(
        accountId: accountId,
        userId: userId,
        name: 'Account Calendar 1',
        color: '#111111',
        source: 'local',
      );

      await repository.insert(
        accountId: accountId,
        userId: userId,
        name: 'Account Calendar 2',
        color: '#222222',
        source: 'local',
      );

      final calendars = await repository.getByAccount(accountId);
      expect(calendars.length, greaterThanOrEqualTo(3)); // Including Planning
    });

    test('should get visible calendars only', () async {
      // Create two calendars
      final cal1 = await repository.insert(
        accountId: accountId,
        userId: userId,
        name: 'Visible Calendar',
        color: '#AAAAAA',
        source: 'local',
      );

      final cal2 = await repository.insert(
        accountId: accountId,
        userId: userId,
        name: 'Hidden Calendar',
        color: '#BBBBBB',
        source: 'local',
      );

      // Create memberships
      await database.into(database.calendarMemberships).insert(
        CalendarMembershipsCompanion(
          userId: Value(userId),
          calendarId: Value(cal1.id),
          visible: const Value(true),
          createdAt: Value(DateTime.now().millisecondsSinceEpoch),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

      await database.into(database.calendarMemberships).insert(
        CalendarMembershipsCompanion(
          userId: Value(userId),
          calendarId: Value(cal2.id),
          visible: const Value(false),
          createdAt: Value(DateTime.now().millisecondsSinceEpoch),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

      final visible = await repository.getVisibleCalendars(userId);
      final visibleIds = visible.map((c) => c.id).toList();

      expect(visibleIds, contains(cal1.id));
      expect(visibleIds, isNot(contains(cal2.id)));
    });
  });

  group('CalendarsRepository - Changes Table Integration (Critical for Sync)', () {
    test('should record all operations in changes table', () async {
      // Create
      final calendar = await repository.insert(
        accountId: accountId,
        userId: userId,
        name: 'Change Tracking',
        color: '#ABCDEF',
        source: 'local',
      );

      // Update
      await repository.update(
        id: calendar.id,
        name: 'Updated Name',
      );

      // Delete
      await repository.softDelete(calendar.id);

      // Verify all changes recorded
      final allChanges = await (database.select(database.changes)
        ..where((c) => c.tableNameCol.equals('calendar') & c.rowId.equals(calendar.id))
        ..orderBy([(c) => OrderingTerm.asc(c.createdAt)]))
        .get();

      expect(allChanges.length, 3,
        reason: 'Should have 3 changes: INSERT, UPDATE, DELETE');

      expect(allChanges[0].operation, 'INSERT');
      expect(allChanges[1].operation, 'UPDATE');
      expect(allChanges[2].operation, 'DELETE');

      // All should be unpushed
      expect(allChanges.every((c) => !c.isPushed), true,
        reason: 'New changes should not be marked as pushed');
    });

    test('changes table should have valid structure', () async {
      final calendar = await repository.insert(
        accountId: accountId,
        userId: userId,
        name: 'Structure Test',
        color: '#FFFFFF',
        source: 'local',
      );

      final changes = await (database.select(database.changes)
        ..where((c) => c.rowId.equals(calendar.id)))
        .get();

      expect(changes.length, 1);
      final change = changes.first;

      // Verify all required fields
      expect(change.id, isNotEmpty, reason: 'Change ID should not be empty');
      expect(change.tableNameCol, 'calendar');
      expect(change.rowId, calendar.id);
      expect(change.operation, 'INSERT');
      expect(change.payloadJson, isNotEmpty);
      expect(change.createdAt, greaterThan(0));
      expect(change.updatedAt, greaterThan(0));
      expect(change.isPushed, false);
    });

    test('should handle concurrent operations to changes table', () async {
      // Create multiple calendars in quick succession
      final futures = <Future<Calendar>>[];
      for (int i = 0; i < 10; i++) {
        futures.add(repository.insert(
          accountId: accountId,
          userId: userId,
          name: 'Concurrent $i',
          color: '#${i.toString().padLeft(6, '0')}',
          source: 'local',
        ));
      }

      await Future.wait(futures);

      // Verify all changes were recorded
      final changes = await (database.select(database.changes)
        ..where((c) => c.tableNameCol.equals('calendar')))
        .get();

      expect(changes.length, greaterThanOrEqualTo(10),
        reason: 'All concurrent operations should be recorded in changes table');
    });

    test('REGRESSION: changes table must exist (caught color preference bug)', () async {
      // This test ensures the changes table exists and is accessible
      // It would have caught the production bug where selecting a color failed

      // Try to insert directly into changes table
      final testId = 'test-${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now().millisecondsSinceEpoch;

      expect(
        () async => await database.into(database.changes).insert(
          ChangesCompanion(
            id: Value(testId),
            tableNameCol: const Value('test_table'),
            rowId: const Value('test_row_id'),
            operation: const Value('INSERT'),
            payloadJson: const Value('{}'),
            updatedAt: Value(now),
            createdAt: Value(now),
            isPushed: const Value(false),
          ),
        ),
        returnsNormally,
        reason: 'Should be able to insert into changes table without SqliteException',
      );

      // Verify it was inserted
      final change = await (database.select(database.changes)
        ..where((c) => c.id.equals(testId)))
        .getSingleOrNull();

      expect(change, matcher.isNotNull,
        reason: 'Changes table should exist and be queryable');
      expect(change!.tableNameCol, 'test_table');
    });
  });
}
