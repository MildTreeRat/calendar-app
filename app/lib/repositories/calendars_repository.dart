import 'package:drift/drift.dart';
import '../database/database.dart';
import '../logging/logger.dart';
import '../utils/id_generator.dart';

/// Repository for managing Calendars with automatic outbox recording
class CalendarsRepository {
  final AppDatabase _db;
  final Logger _logger;

  CalendarsRepository({
    required AppDatabase db,
  })  : _db = db,
        _logger = Logger.instance;

  /// Insert a new calendar and record in outbox
  Future<Calendar> insert({
    required String accountId,
    required String userId,
    required String name,
    String? color,
    required String source,
    String? externalId,
    bool readOnly = false,
    String? metadata,
  }) async {
    final id = IdGenerator.generateUlid();
    final now = DateTime.now().millisecondsSinceEpoch;

    final calendar = await _db.transaction(() async {
      // Insert calendar
      final calendar = await _db.into(_db.calendars).insertReturning(CalendarsCompanion(
            id: Value(id),
            accountId: Value(accountId),
            userId: Value(userId),
            name: Value(name),
            color: Value(color),
            source: Value(source),
            externalId: Value(externalId),
            readOnly: Value(readOnly),
            createdAt: Value(now),
            updatedAt: Value(now),
            metadata: Value(metadata ?? '{}'),
          ));

      // Record in outbox
      await _recordChange(
        table: 'calendar',
        rowId: id,
        operation: 'INSERT',
      );

      _logger.info(
        'Calendar created',
        tag: 'repo.calendar.insert',
        metadata: {
          'calendar_id': id,
          'account_id': accountId,
          'name': name,
          'source': source,
        },
      );

      return calendar;
    });

    return calendar;
  }

  /// Update an existing calendar and record in outbox
  Future<Calendar> update({
    required String id,
    String? accountId,
    String? userId,
    String? name,
    String? color,
    String? source,
    String? externalId,
    bool? readOnly,
    String? metadata,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final calendar = await _db.transaction(() async {
      // Update calendar
      final updated = await (_db.update(_db.calendars)..where((t) => t.id.equals(id))).writeReturning(
            CalendarsCompanion(
              accountId: accountId != null ? Value(accountId) : const Value.absent(),
              userId: userId != null ? Value(userId) : const Value.absent(),
              name: name != null ? Value(name) : const Value.absent(),
              color: color != null ? Value(color) : const Value.absent(),
              source: source != null ? Value(source) : const Value.absent(),
              externalId: externalId != null ? Value(externalId) : const Value.absent(),
              readOnly: readOnly != null ? Value(readOnly) : const Value.absent(),
              updatedAt: Value(now),
              metadata: metadata != null ? Value(metadata) : const Value.absent(),
            ),
          );

      if (updated.isEmpty) {
        throw Exception('Calendar not found: $id');
      }

      // Record in outbox
      await _recordChange(
        table: 'calendar',
        rowId: id,
        operation: 'UPDATE',
      );

      _logger.info(
        'Calendar updated',
        tag: 'repo.calendar.update',
        metadata: {
          'calendar_id': id,
          'fields_updated': {
            if (name != null) 'name': name,
            if (color != null) 'color': color,
            if (readOnly != null) 'read_only': readOnly,
          },
        },
      );

      return updated.first;
    });

    return calendar;
  }

  /// Soft delete a calendar (mark as deleted in metadata) and record in outbox
  Future<void> softDelete(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.transaction(() async {
      // Fetch current calendar
      final calendar = await (_db.select(_db.calendars)..where((t) => t.id.equals(id))).getSingleOrNull();

      if (calendar == null) {
        throw Exception('Calendar not found: $id');
      }

      // Update with deleted flag in metadata
      await (_db.update(_db.calendars)..where((t) => t.id.equals(id))).write(
            CalendarsCompanion(
              metadata: Value('{"deleted":true}'),
              updatedAt: Value(now),
            ),
          );

      // Record in outbox
      await _recordChange(
        table: 'calendar',
        rowId: id,
        operation: 'DELETE',
      );

      _logger.info(
        'Calendar soft deleted',
        tag: 'repo.calendar.delete',
        metadata: {'calendar_id': id, 'name': calendar.name},
      );
    });
  }

  /// Get calendar by ID
  Future<Calendar?> getById(String id) async {
    return (_db.select(_db.calendars)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Get all calendars for a user
  Future<List<Calendar>> getByUser(String userId) async {
    return (_db.select(_db.calendars)..where((t) => t.userId.equals(userId))).get();
  }

  /// Get all calendars for an account
  Future<List<Calendar>> getByAccount(String accountId) async {
    return (_db.select(_db.calendars)..where((t) => t.accountId.equals(accountId))).get();
  }

  /// Get visible calendars for a user with membership details
  Future<List<Calendar>> getVisibleCalendars(String userId) async {
    final query = _db.select(_db.calendars).join([
      innerJoin(
        _db.calendarMemberships,
        _db.calendarMemberships.calendarId.equalsExp(_db.calendars.id),
      ),
    ])
      ..where(_db.calendarMemberships.userId.equals(userId) & _db.calendarMemberships.visible.equals(true));

    final result = await query.get();
    return result.map((row) => row.readTable(_db.calendars)).toList();
  }

  /// Set calendar visibility for a user
  Future<void> setVisible({
    required String userId,
    required String calendarId,
    required bool visible,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.transaction(() async {
      // Update calendar_membership
      await (_db.update(_db.calendarMemberships)
            ..where((t) => t.userId.equals(userId) & t.calendarId.equals(calendarId)))
          .write(CalendarMembershipsCompanion(
        visible: Value(visible),
        updatedAt: Value(now),
      ));

      // Record in outbox
      await _recordChange(
        table: 'calendar_membership',
        rowId: '$userId:$calendarId',
        operation: 'UPDATE',
      );

      _logger.info(
        'Calendar visibility updated',
        tag: 'repo.calendar.set_visible',
        metadata: {
          'user_id': userId,
          'calendar_id': calendarId,
          'visible': visible,
        },
      );
    });
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
