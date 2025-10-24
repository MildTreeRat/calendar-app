part of '../database.dart';

/// Calendars - calendar collections
@DataClassName('Calendar')
class Calendars extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text().nullable().references(Accounts, #id, onDelete: KeyAction.cascade, onUpdate: KeyAction.cascade)();
  TextColumn get userId => text().references(Users, #id, onDelete: KeyAction.restrict, onUpdate: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get color => text().nullable()(); // Default color (hex)
  TextColumn get source => text().check(source.isIn(['google', 'apple', 'local', 'ics']))();
  TextColumn get externalId => text().nullable()(); // Provider calendar ID
  BoolColumn get readOnly => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get metadata => text()
      .customConstraint('NOT NULL DEFAULT \'{}\' CHECK (json_valid(metadata))')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {userId, source, externalId}, // Prevent duplicate calendar imports
  ];
}

/// Calendar memberships - per-user calendar visibility and preferences
@DataClassName('CalendarMembership')
class CalendarMemberships extends Table {
  TextColumn get userId => text().references(Users, #id, onDelete: KeyAction.cascade)();
  TextColumn get calendarId => text().references(Calendars, #id, onDelete: KeyAction.cascade)();
  BoolColumn get visible => boolean().withDefault(const Constant(true))();
  TextColumn get overrideColor => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {userId, calendarId};
}

/// Calendar groups - for organizing calendars (e.g., "Aaron", "Work")
@DataClassName('CalendarGroup')
class CalendarGroups extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {userId, name}, // Unique group names per user
  ];
}

/// Calendar group mappings - many-to-many relationship
@DataClassName('CalendarGroupMap')
class CalendarGroupMaps extends Table {
  TextColumn get groupId => text().references(CalendarGroups, #id, onDelete: KeyAction.cascade)();
  TextColumn get calendarId => text().references(Calendars, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {groupId, calendarId};
}
