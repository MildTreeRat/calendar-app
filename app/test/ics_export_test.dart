import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:app/database/database.dart';
import 'package:app/models/ics_export_event.dart';
import 'package:app/services/ics_export_service.dart';
import 'package:app/repositories/events_repository.dart';
import 'package:app/repositories/calendars_repository.dart';
import 'package:app/utils/id_generator.dart';
import 'package:app/logging/logger.dart';

void main() {
  late AppDatabase db;
  late IcsExportService exportService;
  late EventsRepository eventsRepo;
  late CalendarsRepository calendarsRepo;
  late String testCalendarId;
  late String testUserId;

  setUp(() async {
    // Initialize logger for tests
    await Logger.initialize();

    // Create in-memory database
    db = AppDatabase.forTesting(
      NativeDatabase.memory(),
    );
    exportService = IcsExportService(db: db);
    eventsRepo = EventsRepository(db: db);
    calendarsRepo = CalendarsRepository(db: db);

    // Create test user and calendar
    testUserId = IdGenerator.generateUlid();
    final accountId = IdGenerator.generateUlid();

    testCalendarId = await calendarsRepo
        .insert(
          accountId: accountId,
          userId: testUserId,
          name: 'Test Calendar',
          color: '#FF5722',
          source: 'local',
        )
        .then((cal) => cal.id);

    // Create calendar membership
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.calendarMemberships).insert(CalendarMembershipsCompanion.insert(
          calendarId: testCalendarId,
          userId: testUserId,
          visible: const Value(true),
          createdAt: now,
          updatedAt: now,
        ));
  });

  tearDown(() async {
    await db.close();
  });

  group('IcsExportEvent Model Tests', () {
    test('toJson converts all fields correctly with snake_case', () {
      final event = IcsExportEvent(
        id: 'test-id',
        uid: 'test-uid@example.com',
        calendarName: 'Work',
        title: 'Team Meeting',
        description: 'Weekly sync',
        location: 'Office',
        startMs: 1729526400000,
        endMs: 1729530000000,
        tzid: 'America/New_York',
        allDay: false,
        rrule: 'FREQ=WEEKLY;BYDAY=MO',
        exdates: [1730131200000],
        rdates: [1730390400000],
      );

      final json = event.toJson();

      expect(json['id'], 'test-id');
      expect(json['uid'], 'test-uid@example.com');
      expect(json['calendar_name'], 'Work'); // snake_case
      expect(json['title'], 'Team Meeting');
      expect(json['description'], 'Weekly sync');
      expect(json['location'], 'Office');
      expect(json['start_ms'], 1729526400000); // snake_case
      expect(json['end_ms'], 1729530000000); // snake_case
      expect(json['tzid'], 'America/New_York');
      expect(json['all_day'], false); // snake_case
      expect(json['rrule'], 'FREQ=WEEKLY;BYDAY=MO');
      expect(json['exdates'], [1730131200000]);
      expect(json['rdates'], [1730390400000]);
    });

    test('toJson omits null optional fields', () {
      final event = IcsExportEvent(
        id: 'test-id',
        title: 'Simple Event',
        startMs: 1729526400000,
        endMs: 1729530000000,
        allDay: false,
      );

      final json = event.toJson();

      expect(json.containsKey('uid'), false);
      expect(json.containsKey('calendar_name'), false);
      expect(json.containsKey('description'), false);
      expect(json.containsKey('location'), false);
      expect(json.containsKey('tzid'), false);
      expect(json.containsKey('rrule'), false);
      expect(json.containsKey('exdates'), false);
      expect(json.containsKey('rdates'), false);
    });
  });

  group('DB Row to IcsExportEvent Mapping', () {
    test('maps database event to export event preserving all fields', () async {
      // Insert test event
      final eventId = await eventsRepo.insert(
        calendarId: testCalendarId,
        uid: 'test-uid@example.com',
        title: 'Database Event',
        description: 'Test description',
        location: 'Test location',
        startMs: 1729526400000,
        endMs: 1729530000000,
        tzid: 'America/New_York',
        allDay: false,
        rrule: 'FREQ=DAILY',
        exdates: jsonEncode([1729612800000]),
        rdates: jsonEncode([1729699200000]),
      ).then((e) => e.id);

      // Query back
      final events = await eventsRepo.getWindow(
        testUserId,
        1729526400000 - 1000,
        1729530000000 + 1000,
      );

      expect(events.length, 1);
      final event = events.first;

      // Map to export event
      final exportEvent = IcsExportEvent(
        id: event.id,
        uid: event.uid,
        calendarName: 'Test Calendar',
        title: event.title,
        description: event.description,
        location: event.location,
        startMs: event.startMs,
        endMs: event.endMs,
        tzid: event.tzid,
        allDay: event.allDay,
        rrule: event.rrule,
        exdates: event.exdates != null ? (jsonDecode(event.exdates!) as List).cast<int>() : null,
        rdates: event.rdates != null ? (jsonDecode(event.rdates!) as List).cast<int>() : null,
      );

      // Verify all fields
      expect(exportEvent.id, eventId);
      expect(exportEvent.uid, 'test-uid@example.com');
      expect(exportEvent.title, 'Database Event');
      expect(exportEvent.description, 'Test description');
      expect(exportEvent.location, 'Test location');
      expect(exportEvent.startMs, 1729526400000);
      expect(exportEvent.endMs, 1729530000000);
      expect(exportEvent.tzid, 'America/New_York');
      expect(exportEvent.allDay, false);
      expect(exportEvent.rrule, 'FREQ=DAILY');
      expect(exportEvent.exdates, [1729612800000]);
      expect(exportEvent.rdates, [1729699200000]);
    });

    test('handles all-day events correctly', () async {
      await eventsRepo.insert(
        calendarId: testCalendarId,
        uid: 'all-day@test.com',
        title: 'All Day Event',
        startMs: 1729468800000,
        endMs: 1729555200000,
        tzid: 'UTC',
        allDay: true,
      );

      final events = await eventsRepo.getWindow(
        testUserId,
        1729468800000 - 1000,
        1729555200000 + 1000,
      );

      expect(events.first.allDay, true);
    });
  });

  group('ICS Export Service Integration', () {
    test('exports events to file successfully', () async {
      // Insert test events
      await eventsRepo.insert(
        calendarId: testCalendarId,
        uid: 'event1@test.com',
        title: 'Event 1',
        startMs: 1729526400000,
        endMs: 1729530000000,
        tzid: 'UTC',
        allDay: false,
      );

      await eventsRepo.insert(
        calendarId: testCalendarId,
        uid: 'event2@test.com',
        title: 'Event 2',
        startMs: 1729612800000,
        endMs: 1729616400000,
        tzid: 'UTC',
        allDay: false,
      );

      // Export
      final filePath = await exportService.exportToIcs(
        calendarIds: [testCalendarId],
        calName: 'Test Calendar',
      );

      // Verify file exists
      final file = File(filePath);
      expect(file.existsSync(), true);

      // Verify file content
      final content = await file.readAsString();
      expect(content.contains('BEGIN:VCALENDAR'), true);
      expect(content.contains('END:VCALENDAR'), true);
      expect(content.contains('BEGIN:VEVENT'), true);
      expect(content.contains('UID:event1@test.com'), true);
      expect(content.contains('UID:event2@test.com'), true);
      expect(content.contains('SUMMARY:Event 1'), true);
      expect(content.contains('SUMMARY:Event 2'), true);

      // Cleanup
      await file.delete();
    });

    test('exports with date range filter', () async {
      // Insert events at different times
      await eventsRepo.insert(
        calendarId: testCalendarId,
        uid: 'early@test.com',
        title: 'Early Event',
        startMs: 1729000000000,
        endMs: 1729003600000,
        tzid: 'UTC',
        allDay: false,
      );

      await eventsRepo.insert(
        calendarId: testCalendarId,
        uid: 'middle@test.com',
        title: 'Middle Event',
        startMs: 1729526400000,
        endMs: 1729530000000,
        tzid: 'UTC',
        allDay: false,
      );

      await eventsRepo.insert(
        calendarId: testCalendarId,
        uid: 'late@test.com',
        title: 'Late Event',
        startMs: 1730000000000,
        endMs: 1730003600000,
        tzid: 'UTC',
        allDay: false,
      );

      // Export only middle event
      final filePath = await exportService.exportToIcs(
        calendarIds: [testCalendarId],
        startMs: 1729500000000,
        endMs: 1729600000000,
        calName: 'Test Calendar',
      );

      final content = await File(filePath).readAsString();
      expect(content.contains('UID:middle@test.com'), true);
      expect(content.contains('UID:early@test.com'), false);
      expect(content.contains('UID:late@test.com'), false);

      await File(filePath).delete();
    });

    test('exports empty calendar successfully', () async {
      final filePath = await exportService.exportToIcs(
        calendarIds: [testCalendarId],
        calName: 'Empty Calendar',
      );

      final content = await File(filePath).readAsString();
      expect(content.contains('BEGIN:VCALENDAR'), true);
      expect(content.contains('END:VCALENDAR'), true);
      expect(content.contains('X-WR-CALNAME:Empty Calendar'), true);
      expect(content.contains('BEGIN:VEVENT'), false);

      await File(filePath).delete();
    });

    test('preserves UIDs in export', () async {
      const testUid = 'stable-uid-12345@test.com';
      await eventsRepo.insert(
        calendarId: testCalendarId,
        uid: testUid,
        title: 'UID Test Event',
        startMs: 1729526400000,
        endMs: 1729530000000,
        tzid: 'UTC',
        allDay: false,
      );

      final filePath = await exportService.exportToIcs(
        calendarIds: [testCalendarId],
        calName: 'Test',
      );

      final content = await File(filePath).readAsString();
      expect(content.contains('UID:$testUid'), true);

      await File(filePath).delete();
    });

    test('correctly converts milliseconds to ISO timestamps', () async {
      // Known timestamp: 2024-10-21 10:00:00 UTC
      const startMs = 1729508400000;
      const endMs = 1729512000000; // 1 hour later

      await eventsRepo.insert(
        calendarId: testCalendarId,
        uid: 'time-test@test.com',
        title: 'Time Test',
        startMs: startMs,
        endMs: endMs,
        tzid: 'UTC',
        allDay: false,
      );

      final filePath = await exportService.exportToIcs(
        calendarIds: [testCalendarId],
        calName: 'Test',
      );

      final content = await File(filePath).readAsString();
      // Should contain UTC timestamp in format: 20241021T100000Z
      expect(content.contains('DTSTART:20241021T100000Z'), true);
      expect(content.contains('DTEND:20241021T110000Z'), true);

      await File(filePath).delete();
    });

    test('handles recurring events with exceptions', () async {
      await eventsRepo.insert(
        calendarId: testCalendarId,
        uid: 'recurring@test.com',
        title: 'Recurring Event',
        startMs: 1729526400000,
        endMs: 1729530000000,
        tzid: 'UTC',
        allDay: false,
        rrule: 'FREQ=WEEKLY;BYDAY=MO,WE,FR',
        exdates: jsonEncode([1729612800000, 1729699200000]),
        rdates: jsonEncode([1729785600000]),
      );

      final filePath = await exportService.exportToIcs(
        calendarIds: [testCalendarId],
        calName: 'Test',
      );

      final content = await File(filePath).readAsString();
      expect(content.contains('RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR'), true);
      expect(content.contains('EXDATE:'), true);
      expect(content.contains('RDATE:'), true);

      await File(filePath).delete();
    });
  });

  group('Filename Generation', () {
    test('generates timestamped filename', () async {
      final filePath = await exportService.exportToIcs(
        calendarIds: [testCalendarId],
        calName: 'Test Calendar',
      );

      final filename = filePath.split(Platform.pathSeparator).last;
      expect(filename.startsWith('calendar-export_'), true);
      expect(filename.endsWith('.ics'), true);
      expect(filename.contains('Test-Calendar'), true);

      await File(filePath).delete();
    });

    test('sanitizes calendar name in filename', () async {
      final filePath = await exportService.exportToIcs(
        calendarIds: [testCalendarId],
        calName: 'My Calendar! @#\$%',
      );

      final filename = filePath.split(Platform.pathSeparator).last;
      // Special characters should be removed
      expect(filename.contains('!'), false);
      expect(filename.contains('@'), false);
      expect(filename.contains('#'), false);
      expect(filename.contains('\$'), false);

      await File(filePath).delete();
    });
  });
}
