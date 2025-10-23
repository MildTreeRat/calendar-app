import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import '../database/database.dart';
import '../logging/logger.dart';
import 'supabase_service.dart';
import 'device_id_service.dart';

// ============================================================================
// SyncService - Orchestrates bidirectional cloud sync
// ============================================================================

class SyncService {
  final AppDatabase _db;
  final SupabaseService _supabase;
  final Logger _logger;

  // Sync configuration
  static const int _pullBatchSize = 500;
  static const int _pushBatchSize = 100;

  // Tables to sync (order matters for foreign keys)
  static const List<String> _syncTables = [
    'user',
    'user_profile',
    'account',
    'calendar',
    'calendar_membership',
    'calendar_group',
    'calendar_group_map',
    'event',
    'ics_source',
    'task_list',
    'task',
    'color_palette',
    'palette_color',
  ];

  SyncService({
    required AppDatabase database,
    required SupabaseService supabase,
    required Logger logger,
  })  : _db = database,
        _supabase = supabase,
        _logger = logger;

  // ============================================================================
  // Main Sync Entry Point
  // ============================================================================

  /// Perform a full sync: pull then push for all tables
  Future<SyncResult> sync({
    List<String>? tables,
    bool wifiOnly = false,
  }) async {
    final startTime = DateTime.now();
    _logger.info('Starting sync', tag: 'Sync', metadata: {
      'tables': tables ?? 'all',
      'wifi_only': wifiOnly,
    });

    // Check authentication
    if (!_supabase.isAuthenticated) {
      _logger.warn('Sync aborted: not authenticated', tag: 'Sync');
      return SyncResult(
        success: false,
        error: 'Not authenticated',
        duration: DateTime.now().difference(startTime),
      );
    }

    // Check network connectivity
    if (wifiOnly) {
      final connectivity = await Connectivity().checkConnectivity();
      if (!connectivity.contains(ConnectivityResult.wifi)) {
        _logger.warn('Sync aborted: WiFi only mode', tag: 'Sync');
        return SyncResult(
          success: false,
          error: 'WiFi required',
          duration: DateTime.now().difference(startTime),
        );
      }
    }

    final tablesToSync = tables ?? _syncTables;
    int pulledRows = 0;
    int pushedRows = 0;
    String? errorMessage;

    try {
      // Pull phase: server → local
      for (final table in tablesToSync) {
        final count = await _pullTable(table);
        pulledRows += count;
      }

      // Push phase: local → server
      for (final table in tablesToSync) {
        final count = await _pushTable(table);
        pushedRows += count;
      }

      final duration = DateTime.now().difference(startTime);
      _logger.info('Sync completed', tag: 'Sync', metadata: {
        'pulled': pulledRows,
        'pushed': pushedRows,
        'duration_ms': duration.inMilliseconds,
      });

      return SyncResult(
        success: true,
        pulledRows: pulledRows,
        pushedRows: pushedRows,
        duration: duration,
      );
    } catch (e, stack) {
      errorMessage = e.toString();
      _logger.error('Sync failed',
        tag: 'Sync',
        error: e,
        stackTrace: stack,
      );

      return SyncResult(
        success: false,
        error: errorMessage,
        pulledRows: pulledRows,
        pushedRows: pushedRows,
        duration: DateTime.now().difference(startTime),
      );
    }
  }

  // ============================================================================
  // Pull Logic: Server → Local
  // ============================================================================

  Future<int> _pullTable(String table) async {
    _logger.debug('Pulling table', tag: 'Sync', metadata: {'table': table});

    int totalRows = 0;

    try {
      // Get last pull timestamp
      final syncState = await (_db.select(_db.syncState)
        ..where((t) => t.tableNameCol.equals(table)))
        .getSingleOrNull();

      final lastPullMs = syncState?.lastPullMs ?? 0;

      // Pull rows updated since last sync
      int offset = 0;
      bool hasMore = true;
      int maxUpdatedAt = lastPullMs;

      while (hasMore) {
        final rows = await _supabase
          .from(table)
          .select()
          .gt('updated_at', lastPullMs)
          .order('updated_at')
          .range(offset, offset + _pullBatchSize - 1);

        if (rows.isEmpty) {
          hasMore = false;
          break;
        }

        // Upsert rows into local database
        for (final row in rows) {
          await _upsertLocalRow(table, row);
          final updatedAt = row['updated_at'] as int;
          if (updatedAt > maxUpdatedAt) {
            maxUpdatedAt = updatedAt;
          }
        }

        totalRows += rows.length;
        offset += rows.length;

        if (rows.length < _pullBatchSize) {
          hasMore = false;
        }
      }

      // Update sync state
      if (totalRows > 0) {
        await _updateSyncState(
          table: table,
          lastPullMs: maxUpdatedAt,
        );
      }

      _logger.debug('Pull completed', tag: 'Sync', metadata: {
        'table': table,
        'rows': totalRows,
      });

      return totalRows;
    } catch (e, stack) {
      _logger.error('Pull failed for table',
        tag: 'Sync',
        error: e,
        stackTrace: stack,
        metadata: {'table': table},
      );
      rethrow;
    }
  }

  /// Upsert a row from the server into the local database
  Future<void> _upsertLocalRow(String table, Map<String, dynamic> r) async {
    _logger.trace('Upserting row', tag: 'Sync', metadata: {
      'table': table,
      'id': r['id'],
    });

    try {
      switch (table) {
        case 'user':
          await _db.into(_db.users).insertOnConflictUpdate(UsersCompanion(
            id: Value(r['id']),
            createdAt: Value(r['created_at']),
            updatedAt: Value(r['updated_at']),
            deletedAt: Value(r['deleted_at'] as int?),
            metadata: Value(r['metadata'] ?? '{}'),
          ));
          break;

        case 'user_profile':
          await _db.into(_db.userProfiles).insertOnConflictUpdate(UserProfilesCompanion(
            userId: Value(r['user_id']),
            displayName: Value(r['display_name'] as String?),
            email: Value(r['email'] as String?),
            tzid: Value(r['tzid'] as String?),
            paletteId: Value(r['palette_id'] as String?),
            createdAt: Value(r['created_at']),
            updatedAt: Value(r['updated_at']),
            metadata: Value(r['metadata'] ?? '{}'),
          ));
          break;

        case 'account':
          await _db.into(_db.accounts).insertOnConflictUpdate(AccountsCompanion(
            id: Value(r['id']),
            userId: Value(r['user_id']),
            provider: Value(r['provider']),
            subject: Value(r['subject']),
            label: Value(r['label'] as String?),
            syncToken: Value(r['sync_token'] as String?),
            lastSyncMs: Value(r['last_sync_ms'] as int?),
            createdAt: Value(r['created_at']),
            updatedAt: Value(r['updated_at']),
            metadata: Value(r['metadata'] ?? '{}'),
          ));
          break;

        case 'calendar':
          await _db.into(_db.calendars).insertOnConflictUpdate(CalendarsCompanion(
            id: Value(r['id']),
            userId: Value(r['user_id']),
            accountId: Value(r['account_id'] as String?),
            name: Value(r['name']),
            color: Value(r['color'] as String?),
            source: Value(r['source']),
            externalId: Value(r['external_id'] as String?),
            readOnly: Value(r['read_only'] == 1 || r['read_only'] == true),
            createdAt: Value(r['created_at']),
            updatedAt: Value(r['updated_at']),
            metadata: Value(r['metadata'] ?? '{}'),
          ));
          break;

        case 'calendar_membership':
          await _db.into(_db.calendarMemberships).insertOnConflictUpdate(CalendarMembershipsCompanion(
            userId: Value(r['user_id']),
            calendarId: Value(r['calendar_id']),
            visible: Value(r['visible']),
            createdAt: Value(r['created_at']),
            updatedAt: Value(r['updated_at']),
          ));
          break;

        case 'calendar_group':
          await _db.into(_db.calendarGroups).insertOnConflictUpdate(CalendarGroupsCompanion(
            id: Value(r['id']),
            userId: Value(r['user_id']),
            name: Value(r['name']),
            createdAt: Value(r['created_at']),
            updatedAt: Value(r['updated_at']),
          ));
          break;

        case 'calendar_group_map':
          await _db.into(_db.calendarGroupMaps).insertOnConflictUpdate(CalendarGroupMapsCompanion(
            groupId: Value(r['group_id']),
            calendarId: Value(r['calendar_id']),
          ));
          break;

        case 'event':
          await _db.into(_db.events).insertOnConflictUpdate(EventsCompanion(
            id: Value(r['id']),
            calendarId: Value(r['calendar_id']),
            uid: Value(r['uid'] as String?),
            title: Value(r['title']),
            description: Value(r['description'] as String?),
            location: Value(r['location'] as String?),
            startMs: Value(r['start_ms']),
            endMs: Value(r['end_ms']),
            tzid: Value(r['tzid'] as String?),
            allDay: Value(r['all_day'] == 1 || r['all_day'] == true),
            rrule: Value(r['rrule'] as String?),
            exdates: Value(r['exdates'] as String?),
            rdates: Value(r['rdates'] as String?),
            createdAt: Value(r['created_at']),
            updatedAt: Value(r['updated_at']),
            metadata: Value(r['metadata'] ?? '{}'),
          ));
          break;

        case 'ics_source':
          await _db.into(_db.icsSources).insertOnConflictUpdate(IcsSourcesCompanion(
            id: Value(r['id']),
            calendarId: Value(r['calendar_id']),
            url: Value(r['url']),
            etag: Value(r['etag'] as String?),
            lastFetchMs: Value(r['last_fetch_ms'] as int?),
            createdAt: Value(r['created_at']),
            updatedAt: Value(r['updated_at']),
            metadata: Value(r['metadata'] ?? '{}'),
          ));
          break;

        case 'task_list':
          await _db.into(_db.taskLists).insertOnConflictUpdate(TaskListsCompanion(
            id: Value(r['id']),
            userId: Value(r['user_id']),
            accountId: Value(r['account_id'] as String?),
            name: Value(r['name']),
            source: Value(r['source']),
            externalId: Value(r['external_id'] as String?),
            createdAt: Value(r['created_at']),
            updatedAt: Value(r['updated_at']),
            metadata: Value(r['metadata'] ?? '{}'),
          ));
          break;

        case 'task':
          await _db.into(_db.tasks).insertOnConflictUpdate(TasksCompanion(
            id: Value(r['id']),
            taskListId: Value(r['task_list_id']),
            title: Value(r['title']),
            notes: Value(r['notes'] as String?),
            dueMs: Value(r['due_ms'] as int?),
            completedMs: Value(r['completed_ms'] as int?),
            priority: Value(r['priority'] as int?),
            createdAt: Value(r['created_at']),
            updatedAt: Value(r['updated_at']),
            metadata: Value(r['metadata'] ?? '{}'),
          ));
          break;

        case 'color_palette':
          await _db.into(_db.colorPalettes).insertOnConflictUpdate(ColorPalettesCompanion(
            id: Value(r['id']),
            userId: Value(r['user_id']),
            name: Value(r['name']),
            createdAt: Value(r['created_at']),
            updatedAt: Value(r['updated_at']),
          ));
          break;

        case 'palette_color':
          await _db.into(_db.paletteColors).insertOnConflictUpdate(PaletteColorsCompanion(
            id: Value(r['id']),
            paletteId: Value(r['palette_id']),
            ordinal: Value(r['ordinal']),
            hex: Value(r['hex']),
            createdAt: Value(r['created_at']),
            updatedAt: Value(r['updated_at']),
          ));
          break;

        default:
          _logger.warn('Unknown table in upsert', tag: 'Sync', metadata: {'table': table});
      }

      _logger.debug('Upsert completed', tag: 'Sync', metadata: {
        'table': table,
        'id': r['id'],
      });
    } catch (e, stack) {
      _logger.error('Upsert failed', tag: 'Sync', error: e, stackTrace: stack, metadata: {
        'table': table,
        'id': r['id'],
      });
      rethrow;
    }
  }

  // ============================================================================
  // Push Logic: Local → Server
  // ============================================================================

  Future<int> _pushTable(String table) async {
    _logger.debug('Pushing table', tag: 'Sync', metadata: {'table': table});

    int totalRows = 0;

    try {
      // Get pending changes from outbox (tracked per-row, not per-table timestamp)
      final changes = await (_db.select(_db.changes)
        ..where((t) => t.tableNameCol.equals(table) & t.isPushed.equals(false))
        ..orderBy([(t) => OrderingTerm(expression: t.updatedAt)]))
        .get();

      if (changes.isEmpty) {
        return 0;
      }

      final deviceId = await DeviceIdService.getDeviceId();
      final ownerId = _supabase.currentUserId!;

      // Push in batches
      for (int i = 0; i < changes.length; i += _pushBatchSize) {
        final batch = changes.skip(i).take(_pushBatchSize).toList();

        for (final change in batch) {
          final payload = jsonDecode(change.payloadJson) as Map<String, dynamic>;

          // Add metadata
          payload['owner_id'] = ownerId;
          payload['device_id'] = deviceId;

          try {
            await _pushRow(table, change.operation, payload);

            // Mark as pushed
            await (_db.update(_db.changes)
              ..where((t) => t.id.equals(change.id)))
              .write(ChangesCompanion(isPushed: Value(true)));

            totalRows++;
          } catch (e, stack) {
            _logger.error('Failed to push row',
              tag: 'Sync',
              error: e,
              stackTrace: stack,
              metadata: {
                'table': table,
                'row_id': change.rowId,
                'operation': change.operation,
              },
            );
            // Continue with other rows
          }
        }
      }

      // Update sync state
      if (totalRows > 0) {
        await _updateSyncState(
          table: table,
          lastPushMs: DateTime.now().millisecondsSinceEpoch,
        );
      }

      _logger.debug('Push completed', tag: 'Sync', metadata: {
        'table': table,
        'rows': totalRows,
      });

      return totalRows;
    } catch (e, stack) {
      _logger.error('Push failed for table',
        tag: 'Sync',
        error: e,
        stackTrace: stack,
        metadata: {'table': table},
      );
      rethrow;
    }
  }

  /// Push a single row to the server
  Future<void> _pushRow(
    String table,
    String operation,
    Map<String, dynamic> payload,
  ) async {
    if (operation == 'delete') {
      // Soft delete: update deleted_at
      await _supabase
        .from(table)
        .update({'deleted_at': DateTime.now().millisecondsSinceEpoch})
        .eq('id', payload['id']);
    } else {
      // Insert or update (upsert)
      await _supabase
        .from(table)
        .upsert(payload, onConflict: 'id');
    }
  }

  // ============================================================================
  // Outbox Management
  // ============================================================================

  /// Record a local change in the outbox for later sync
  Future<void> recordChange({
    required String table,
    required String rowId,
    required String operation, // 'insert', 'update', 'delete'
    required Map<String, dynamic> payload,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final changeId = '$table-$rowId-$now';

      await _db.into(_db.changes).insert(
        ChangesCompanion.insert(
          id: changeId,
          tableNameCol: table,
          rowId: rowId,
          operation: operation,
          payloadJson: jsonEncode(payload),
          updatedAt: now,
          createdAt: now,
          isPushed: Value(false),
        ),
      );

      _logger.trace('Recorded change', tag: 'Sync', metadata: {
        'table': table,
        'operation': operation,
        'row_id': rowId,
      });
    } catch (e, stack) {
      _logger.error('Failed to record change',
        tag: 'Sync',
        error: e,
        stackTrace: stack,
        metadata: {
          'table': table,
          'operation': operation,
          'row_id': rowId,
        },
      );
    }
  }

  /// Clear pushed changes older than a certain age
  Future<void> cleanupOutbox({Duration maxAge = const Duration(days: 7)}) async {
    try {
      final cutoff = DateTime.now().subtract(maxAge).millisecondsSinceEpoch;

      await (_db.delete(_db.changes)
        ..where((t) => t.isPushed.equals(true) & t.createdAt.isSmallerThan(Variable(cutoff))))
        .go();

      _logger.info('Cleaned up outbox', tag: 'Sync', metadata: {
        'cutoff_ms': cutoff,
      });
    } catch (e, stack) {
      _logger.error('Outbox cleanup failed',
        tag: 'Sync',
        error: e,
        stackTrace: stack,
      );
    }
  }

  // ============================================================================
  // Sync State Management
  // ============================================================================

  Future<void> _updateSyncState({
    required String table,
    int? lastPullMs,
    int? lastPushMs,
  }) async {
    final existing = await (_db.select(_db.syncState)
      ..where((t) => t.tableNameCol.equals(table)))
      .getSingleOrNull();

    if (existing == null) {
      await _db.into(_db.syncState).insert(
        SyncStateCompanion.insert(
          tableNameCol: table,
          lastPullMs: Value(lastPullMs ?? 0),
          lastPushMs: Value(lastPushMs ?? 0),
        ),
      );
    } else {
      await (_db.update(_db.syncState)
        ..where((t) => t.tableNameCol.equals(table)))
        .write(SyncStateCompanion(
          lastPullMs: lastPullMs != null ? Value(lastPullMs) : Value.absent(),
          lastPushMs: lastPushMs != null ? Value(lastPushMs) : Value.absent(),
        ));
    }
  }

  /// Get pending changes count (not yet pushed)
  Future<int> getPendingChangesCount() async {
    final countColumn = _db.changes.id.count();
    final result = await (_db.selectOnly(_db.changes)
      ..addColumns([countColumn])
      ..where(_db.changes.isPushed.equals(false)))
      .getSingle();

    return result.read(countColumn) ?? 0;
  }
}

// ============================================================================
// Result Models
// ============================================================================

class SyncResult {
  final bool success;
  final int pulledRows;
  final int pushedRows;
  final Duration duration;
  final String? error;

  SyncResult({
    required this.success,
    this.pulledRows = 0,
    this.pushedRows = 0,
    required this.duration,
    this.error,
  });

  @override
  String toString() {
    if (!success) {
      return 'SyncResult(failed: $error)';
    }
    return 'SyncResult(pulled: $pulledRows, pushed: $pushedRows, duration: ${duration.inSeconds}s)';
  }
}
