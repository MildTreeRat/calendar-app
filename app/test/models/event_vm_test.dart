import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/event_vm.dart';

void main() {
  group('EventVM Lane Assignment', () {
    test('Single event gets lane 0', () {
      final events = [
        EventVM(
          id: '1',
          calendarId: 'cal1',
          title: 'Event 1',
          start: DateTime(2025, 10, 17, 10, 0),
          end: DateTime(2025, 10, 17, 11, 0),
          tzid: 'UTC',
          allDay: false,
          color: '#FF0000',
        ),
      ];

      final assigned = assignLanes(events);

      expect(assigned[0].lane, 0);
      expect(assigned[0].totalLanes, 1);
    });

    test('Two non-overlapping events get same lane', () {
      final events = [
        EventVM(
          id: '1',
          calendarId: 'cal1',
          title: 'Event 1',
          start: DateTime(2025, 10, 17, 10, 0),
          end: DateTime(2025, 10, 17, 11, 0),
          tzid: 'UTC',
          allDay: false,
          color: '#FF0000',
        ),
        EventVM(
          id: '2',
          calendarId: 'cal1',
          title: 'Event 2',
          start: DateTime(2025, 10, 17, 11, 0),
          end: DateTime(2025, 10, 17, 12, 0),
          tzid: 'UTC',
          allDay: false,
          color: '#00FF00',
        ),
      ];

      final assigned = assignLanes(events);

      expect(assigned[0].lane, 0);
      expect(assigned[1].lane, 0);
    });

    test('Two overlapping events get different lanes', () {
      final events = [
        EventVM(
          id: '1',
          calendarId: 'cal1',
          title: 'Event 1',
          start: DateTime(2025, 10, 17, 10, 0),
          end: DateTime(2025, 10, 17, 11, 30),
          tzid: 'UTC',
          allDay: false,
          color: '#FF0000',
        ),
        EventVM(
          id: '2',
          calendarId: 'cal1',
          title: 'Event 2',
          start: DateTime(2025, 10, 17, 11, 0),
          end: DateTime(2025, 10, 17, 12, 0),
          tzid: 'UTC',
          allDay: false,
          color: '#00FF00',
        ),
      ];

      final assigned = assignLanes(events);

      expect(assigned[0].lane, 0);
      expect(assigned[1].lane, 1);
      expect(assigned[0].totalLanes, 2);
      expect(assigned[1].totalLanes, 2);
    });

    test('Three overlapping events get three lanes', () {
      final events = [
        EventVM(
          id: '1',
          calendarId: 'cal1',
          title: 'Event 1',
          start: DateTime(2025, 10, 17, 10, 0),
          end: DateTime(2025, 10, 17, 12, 0),
          tzid: 'UTC',
          allDay: false,
          color: '#FF0000',
        ),
        EventVM(
          id: '2',
          calendarId: 'cal1',
          title: 'Event 2',
          start: DateTime(2025, 10, 17, 10, 30),
          end: DateTime(2025, 10, 17, 11, 30),
          tzid: 'UTC',
          allDay: false,
          color: '#00FF00',
        ),
        EventVM(
          id: '3',
          calendarId: 'cal1',
          title: 'Event 3',
          start: DateTime(2025, 10, 17, 11, 0),
          end: DateTime(2025, 10, 17, 13, 0),
          tzid: 'UTC',
          allDay: false,
          color: '#0000FF',
        ),
      ];

      final assigned = assignLanes(events);

      expect(assigned[0].lane, 0);
      expect(assigned[1].lane, 1);
      expect(assigned[2].lane, 2);
      expect(assigned.every((e) => e.totalLanes == 3), true);
    });

    test('Complex overlapping pattern assigns correctly', () {
      // Event 1: 10:00-11:00
      // Event 2: 10:30-11:30 (overlaps 1)
      // Event 3: 11:00-12:00 (overlaps 2, not 1)
      // Event 4: 12:00-13:00 (no overlap)

      final events = [
        EventVM(
          id: '1',
          calendarId: 'cal1',
          title: 'Event 1',
          start: DateTime(2025, 10, 17, 10, 0),
          end: DateTime(2025, 10, 17, 11, 0),
          tzid: 'UTC',
          allDay: false,
          color: '#FF0000',
        ),
        EventVM(
          id: '2',
          calendarId: 'cal1',
          title: 'Event 2',
          start: DateTime(2025, 10, 17, 10, 30),
          end: DateTime(2025, 10, 17, 11, 30),
          tzid: 'UTC',
          allDay: false,
          color: '#00FF00',
        ),
        EventVM(
          id: '3',
          calendarId: 'cal1',
          title: 'Event 3',
          start: DateTime(2025, 10, 17, 11, 0),
          end: DateTime(2025, 10, 17, 12, 0),
          tzid: 'UTC',
          allDay: false,
          color: '#0000FF',
        ),
        EventVM(
          id: '4',
          calendarId: 'cal1',
          title: 'Event 4',
          start: DateTime(2025, 10, 17, 12, 0),
          end: DateTime(2025, 10, 17, 13, 0),
          tzid: 'UTC',
          allDay: false,
          color: '#FFFF00',
        ),
      ];

      final assigned = assignLanes(events);

      expect(assigned[0].lane, 0); // Event 1: lane 0
      expect(assigned[1].lane, 1); // Event 2: lane 1 (overlaps 1)
      expect(assigned[2].lane, 0); // Event 3: lane 0 (1 ended, can reuse)
      expect(assigned[3].lane, 0); // Event 4: lane 0 (no overlap)
    });
  });

  group('EventVM groupByDate', () {
    test('Groups events by date correctly', () {
      final events = [
        EventVM(
          id: '1',
          calendarId: 'cal1',
          title: 'Event 1',
          start: DateTime(2025, 10, 17, 10, 0),
          end: DateTime(2025, 10, 17, 11, 0),
          tzid: 'UTC',
          allDay: false,
          color: '#FF0000',
        ),
        EventVM(
          id: '2',
          calendarId: 'cal1',
          title: 'Event 2',
          start: DateTime(2025, 10, 17, 14, 0),
          end: DateTime(2025, 10, 17, 15, 0),
          tzid: 'UTC',
          allDay: false,
          color: '#00FF00',
        ),
        EventVM(
          id: '3',
          calendarId: 'cal1',
          title: 'Event 3',
          start: DateTime(2025, 10, 18, 10, 0),
          end: DateTime(2025, 10, 18, 11, 0),
          tzid: 'UTC',
          allDay: false,
          color: '#0000FF',
        ),
      ];

      final grouped = groupByDate(events);

      expect(grouped.length, 2);
      expect(grouped[DateTime(2025, 10, 17)]?.length, 2);
      expect(grouped[DateTime(2025, 10, 18)]?.length, 1);
    });

    test('All-day events come first within a day', () {
      final events = [
        EventVM(
          id: '1',
          calendarId: 'cal1',
          title: 'Timed Event',
          start: DateTime(2025, 10, 17, 10, 0),
          end: DateTime(2025, 10, 17, 11, 0),
          tzid: 'UTC',
          allDay: false,
          color: '#FF0000',
        ),
        EventVM(
          id: '2',
          calendarId: 'cal1',
          title: 'All-Day Event',
          start: DateTime(2025, 10, 17, 0, 0),
          end: DateTime(2025, 10, 17, 23, 59),
          tzid: 'UTC',
          allDay: true,
          color: '#00FF00',
        ),
      ];

      final grouped = groupByDate(events);
      final dayEvents = grouped[DateTime(2025, 10, 17)]!;

      expect(dayEvents[0].allDay, true);
      expect(dayEvents[1].allDay, false);
    });
  });

  group('EventVM helpers', () {
    test('minutesFromMidnight calculates correctly', () {
      final event = EventVM(
        id: '1',
        calendarId: 'cal1',
        title: 'Event',
        start: DateTime(2025, 10, 17, 14, 30),
        end: DateTime(2025, 10, 17, 15, 0),
        tzid: 'UTC',
        allDay: false,
        color: '#FF0000',
      );

      expect(event.minutesFromMidnight, 14 * 60 + 30);
    });

    test('durationMinutes calculates correctly', () {
      final event = EventVM(
        id: '1',
        calendarId: 'cal1',
        title: 'Event',
        start: DateTime(2025, 10, 17, 10, 0),
        end: DateTime(2025, 10, 17, 11, 30),
        tzid: 'UTC',
        allDay: false,
        color: '#FF0000',
      );

      expect(event.durationMinutes, 90);
    });
  });
}
