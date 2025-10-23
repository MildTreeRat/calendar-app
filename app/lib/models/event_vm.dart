import 'package:flutter/material.dart';
import '../database/database.dart';

/// View model for rendering events in UI with layout information
class EventVM {
  final String id;
  final String calendarId;
  final String title;
  final String? description;
  final String? location;
  final DateTime start;
  final DateTime end;
  final String tzid;
  final bool allDay;
  final String color;
  final int lane;
  final int totalLanes;

  EventVM({
    required this.id,
    required this.calendarId,
    required this.title,
    this.description,
    this.location,
    required this.start,
    required this.end,
    required this.tzid,
    required this.allDay,
    required this.color,
    this.lane = 0,
    this.totalLanes = 1,
  });

  /// Create from database Event with color resolution
  factory EventVM.fromEvent(Event event, {required String color}) {
    return EventVM(
      id: event.id,
      calendarId: event.calendarId,
      title: event.title,
      description: event.description,
      location: event.location,
      start: DateTime.fromMillisecondsSinceEpoch(event.startMs, isUtc: true).toLocal(),
      end: DateTime.fromMillisecondsSinceEpoch(event.endMs, isUtc: true).toLocal(),
      tzid: event.tzid ?? 'UTC',
      allDay: event.allDay,
      color: color,
    );
  }

  /// Copy with lane assignment
  EventVM withLane(int lane, int totalLanes) {
    return EventVM(
      id: id,
      calendarId: calendarId,
      title: title,
      description: description,
      location: location,
      start: start,
      end: end,
      tzid: tzid,
      allDay: allDay,
      color: color,
      lane: lane,
      totalLanes: totalLanes,
    );
  }

  /// Get start minutes from midnight (for week view positioning)
  int get minutesFromMidnight {
    return start.hour * 60 + start.minute;
  }

  /// Get duration in minutes
  int get durationMinutes {
    return end.difference(start).inMinutes;
  }

  /// Get contrasting text color for this event's background
  Color get textColor {
    final hex = color.replaceAll('#', '');
    final r = int.parse(hex.substring(0, 2), radix: 16);
    final g = int.parse(hex.substring(2, 4), radix: 16);
    final b = int.parse(hex.substring(4, 6), radix: 16);

    // Calculate relative luminance
    final luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;

    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  /// Get background color as Flutter Color
  Color get backgroundColor {
    final hex = color.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}

/// Slot for lane assignment algorithm
class EventSlot {
  final EventVM event;
  final int startMs;
  final int endMs;
  int lane = 0;

  EventSlot(this.event)
      : startMs = event.start.millisecondsSinceEpoch,
        endMs = event.end.millisecondsSinceEpoch;
}

/// Assign non-overlapping lanes to events for rendering
/// Returns events with lane assignments and total lane count per event
List<EventVM> assignLanes(List<EventVM> events) {
  if (events.isEmpty) return events;

  // Create slots
  final slots = events.map((e) => EventSlot(e)).toList();

  // Sort by start time, then by duration (longer first)
  slots.sort((a, b) {
    final cmp = a.startMs.compareTo(b.startMs);
    if (cmp != 0) return cmp;
    return b.event.durationMinutes.compareTo(a.event.durationMinutes);
  });

  // Track end time for each lane
  final lanesEnd = <int>[];

  // Assign lanes
  for (final slot in slots) {
    var placed = false;

    // Try to place in existing lane
    for (var i = 0; i < lanesEnd.length; i++) {
      if (slot.startMs >= lanesEnd[i]) {
        slot.lane = i;
        lanesEnd[i] = slot.endMs;
        placed = true;
        break;
      }
    }

    // Create new lane if needed
    if (!placed) {
      slot.lane = lanesEnd.length;
      lanesEnd.add(slot.endMs);
    }
  }

  final totalLanes = lanesEnd.length;

  // Return events with lane assignments
  return slots.map((s) => s.event.withLane(s.lane, totalLanes)).toList();
}

/// Group events by date for agenda view
Map<DateTime, List<EventVM>> groupByDate(List<EventVM> events) {
  final groups = <DateTime, List<EventVM>>{};

  for (final event in events) {
    final date = DateTime(event.start.year, event.start.month, event.start.day);
    groups.putIfAbsent(date, () => []).add(event);
  }

  // Sort events within each day
  for (final events in groups.values) {
    events.sort((a, b) {
      // All-day events first
      if (a.allDay && !b.allDay) return -1;
      if (!a.allDay && b.allDay) return 1;
      // Then by start time
      return a.start.compareTo(b.start);
    });
  }

  return groups;
}
