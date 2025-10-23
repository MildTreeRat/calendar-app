part of '../database.dart';

/// ICS sources - subscription/import sources for ICS feeds
@DataClassName('IcsSource')
class IcsSources extends Table {
  TextColumn get id => text()();
  TextColumn get calendarId => text().references(Calendars, #id, onDelete: KeyAction.cascade)();
  TextColumn get url => text()();
  TextColumn get etag => text().nullable()(); // For conditional fetching
  IntColumn get lastFetchMs => integer().nullable()(); // Last successful fetch timestamp
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get metadata => text()
      .customConstraint('NOT NULL DEFAULT \'{}\' CHECK (json_valid(metadata))')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {calendarId, url}, // One URL per calendar
  ];
}
