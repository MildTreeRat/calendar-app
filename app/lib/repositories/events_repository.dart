import 'package:drift/drift.dart';
import '../database/database.dart';
import '../logging/logger.dart';
import '../utils/id_generator.dart';

/// Repository for managing Events with automatic outbox recording
class EventsRepository {
  final AppDatabase _db;
  final Logger _logger;

  EventsRepository({
    required AppDatabase db,
  })  : _db = db,
        _logger = Logger.instance;

  /// Insert a new event and record in outbox
  Future<Event> insert({
    required String calendarId,
    required String uid,
    required String title,
    String? description,
    String? location,
    required int startMs,
    required int endMs,
    required String tzid,
    bool allDay = false,
    String? rrule,
    String? exdates,
    String? rdates,
    String? metadata,
  }) async {
    final id = IdGenerator.generateUlid();
    final now = DateTime.now().millisecondsSinceEpoch;

    final event = await _db.transaction(() async {
      // Insert event
      final event = await _db.into(_db.events).insertReturning(EventsCompanion(
            id: Value(id),
            calendarId: Value(calendarId),
            uid: Value(uid),
            title: Value(title),
            description: Value(description),
            location: Value(location),
            startMs: Value(startMs),
            endMs: Value(endMs),
            tzid: Value(tzid),
            allDay: Value(allDay),
            rrule: Value(rrule),
            exdates: Value(exdates),
            rdates: Value(rdates),
            createdAt: Value(now),
            updatedAt: Value(now),
            metadata: Value(metadata ?? '{}'),
          ));

      // Record in outbox
      await _recordChange(
        table: 'event',
        rowId: id,
        operation: 'INSERT',
      );

      _logger.info(
        'Event created',
        tag: 'repo.event.insert',
        metadata: {
          'event_id': id,
          'calendar_id': calendarId,
          'title': title,
          'start_ms': startMs,
        },
      );

      return event;
    });

    return event;
  }

  /// Update an existing event and record in outbox
  Future<Event> update({
    required String id,
    String? calendarId,
    String? uid,
    String? title,
    String? description,
    String? location,
    int? startMs,
    int? endMs,
    String? tzid,
    bool? allDay,
    String? rrule,
    String? exdates,
    String? rdates,
    String? metadata,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final event = await _db.transaction(() async {
      // Update event
      final updated = await (_db.update(_db.events)..where((t) => t.id.equals(id))).writeReturning(
            EventsCompanion(
              calendarId: calendarId != null ? Value(calendarId) : const Value.absent(),
              uid: uid != null ? Value(uid) : const Value.absent(),
              title: title != null ? Value(title) : const Value.absent(),
              description: description != null ? Value(description) : const Value.absent(),
              location: location != null ? Value(location) : const Value.absent(),
              startMs: startMs != null ? Value(startMs) : const Value.absent(),
              endMs: endMs != null ? Value(endMs) : const Value.absent(),
              tzid: tzid != null ? Value(tzid) : const Value.absent(),
              allDay: allDay != null ? Value(allDay) : const Value.absent(),
              rrule: rrule != null ? Value(rrule) : const Value.absent(),
              exdates: exdates != null ? Value(exdates) : const Value.absent(),
              rdates: rdates != null ? Value(rdates) : const Value.absent(),
              updatedAt: Value(now),
              metadata: metadata != null ? Value(metadata) : const Value.absent(),
            ),
          );

      if (updated.isEmpty) {
        throw Exception('Event not found: $id');
      }

      // Record in outbox
      await _recordChange(
        table: 'event',
        rowId: id,
        operation: 'UPDATE',
      );

      _logger.info(
        'Event updated',
        tag: 'repo.event.update',
        metadata: {
          'event_id': id,
          'fields_updated': {
            if (title != null) 'title': title,
            if (startMs != null) 'start_ms': startMs,
            if (endMs != null) 'end_ms': endMs,
          },
        },
      );

      return updated.first;
    });

    return event;
  }

  /// Soft delete an event (mark as deleted in metadata) and record in outbox
  Future<void> softDelete(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.transaction(() async {
      // Fetch current event
      final event = await (_db.select(_db.events)..where((t) => t.id.equals(id))).getSingleOrNull();

      if (event == null) {
        throw Exception('Event not found: $id');
      }

      // Update with deleted flag in metadata
      await (_db.update(_db.events)..where((t) => t.id.equals(id))).write(
            EventsCompanion(
              metadata: Value('{"deleted":true}'),
              updatedAt: Value(now),
            ),
          );

      // Record in outbox
      await _recordChange(
        table: 'event',
        rowId: id,
        operation: 'DELETE',
      );

      _logger.info(
        'Event soft deleted',
        tag: 'repo.event.delete',
        metadata: {'event_id': id, 'title': event.title},
      );
    });
  }

  /// Get event by ID
  Future<Event?> getById(String id) async {
    return (_db.select(_db.events)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Get all events for a calendar
  Future<List<Event>> getByCalendar(String calendarId) async {
    return (_db.select(_db.events)..where((t) => t.calendarId.equals(calendarId))).get();
  }

  /// Get events in a time range
  Future<List<Event>> getInRange(int startMs, int endMs) async {
    return (_db.select(_db.events)
          ..where((t) => t.startMs.isBiggerOrEqualValue(startMs) & t.endMs.isSmallerOrEqualValue(endMs)))
        .get();
  }

  /// Get events in a time window for a user, respecting calendar visibility
  /// Returns only events from visible calendars, excludes soft-deleted events
  Future<List<Event>> getWindow(String userId, int startMs, int endMs) async {
    final stopwatch = Stopwatch()..start();

    final query = _db.select(_db.events).join([
      innerJoin(
        _db.calendarMemberships,
        _db.calendarMemberships.calendarId.equalsExp(_db.events.calendarId),
      ),
    ])
      ..where(_db.calendarMemberships.userId.equals(userId))
      ..where(_db.calendarMemberships.visible.equals(true))
      ..where(_db.events.metadata.like('%"deleted"%').not())
      ..where(_db.events.startMs.isSmallerThanValue(endMs))
      ..where(_db.events.endMs.isBiggerOrEqualValue(startMs))
      ..orderBy([OrderingTerm.asc(_db.events.startMs)]);

    final rows = await query.get();
    final events = rows.map((row) => row.readTable(_db.events)).toList();

    stopwatch.stop();
    _logger.debug(
      'Query window completed',
      tag: 'db.query_window',
      metadata: {
        'ms': stopwatch.elapsedMilliseconds,
        'start_ms': startMs,
        'end_ms': endMs,
        'rows': events.length,
        'user_id': userId,
      },
    );

    return events;
  }

  /// Get events with their calendar colors for UI rendering
  Future<Map<String, String>> getCalendarColors(List<String> calendarIds) async {
    if (calendarIds.isEmpty) return {};

    final calendars = await (_db.select(_db.calendars)
          ..where((t) => t.id.isIn(calendarIds)))
        .get();

    return {for (final cal in calendars) cal.id: cal.color ?? '#2196F3'};
  }

  /// Record a change in the outbox table
  Future<void> _recordChange({
    required String table,
    required String rowId,
    required String operation,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = IdGenerator.generateUlid();

    await _db.into(_db.changes).insert(ChangesCompanion(
          id: Value(id),
          tableNameCol: Value(table),
          rowId: Value(rowId),
          operation: Value(operation),
          payloadJson: const Value('{}'),
          updatedAt: Value(now),
          createdAt: Value(now),
          isPushed: const Value(false),
        ));
  }
}
