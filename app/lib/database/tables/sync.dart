part of '../database.dart';

// ============================================================================
// SyncState - Track last sync timestamps per table
// ============================================================================

class SyncState extends Table {
  TextColumn get tableNameCol => text().named('table_name')();
  IntColumn get lastPullMs => integer().withDefault(const Constant(0))();
  IntColumn get lastPushMs => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {tableNameCol};

  @override
  String get tableName => 'sync_state';
}

// ============================================================================
// Changes (Outbox) - Track local modifications awaiting cloud push
// ============================================================================

class Changes extends Table {
  TextColumn get id => text()();
  TextColumn get tableNameCol => text().named('table_name')();
  TextColumn get rowId => text()();
  TextColumn get operation => text()(); // 'insert', 'update', 'delete'
  TextColumn get payloadJson => text()();
  IntColumn get updatedAt => integer()();
  IntColumn get createdAt => integer()();
  BoolColumn get isPushed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'changes';
}

// ============================================================================
// DeviceInfo - Store device identity for conflict resolution
// ============================================================================

class DeviceInfo extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
