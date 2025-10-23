import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/ics_export_event.dart';

void main() {
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

    test('IcsExportRequest toJson matches Rust ExportRequest structure', () {
      final events = [
        IcsExportEvent(
          id: 'evt1',
          title: 'Event 1',
          startMs: 1729526400000,
          endMs: 1729530000000,
          allDay: false,
        ),
        IcsExportEvent(
          id: 'evt2',
          uid: 'evt2@test.com',
          title: 'Event 2',
          startMs: 1729612800000,
          endMs: 1729616400000,
          allDay: true,
        ),
      ];

      final request = IcsExportRequest(
        prodId: '-//Test//Calendar 1.0//EN',
        calName: 'Test Calendar',
        events: events,
      );

      final json = request.toJson();

      expect(json['prod_id'], '-//Test//Calendar 1.0//EN'); // snake_case
      expect(json['cal_name'], 'Test Calendar'); // snake_case
      expect(json['events'], isA<List>());
      expect(json['events'].length, 2);
      expect(json['events'][0]['id'], 'evt1');
      expect(json['events'][1]['id'], 'evt2');
      expect(json['events'][1]['uid'], 'evt2@test.com');
    });
  });
}
