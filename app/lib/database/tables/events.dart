part of '../database.dart';

/// Events - calendar events with recurrence support
@DataClassName('Event')
class Events extends Table {
  TextColumn get id => text()();
  TextColumn get calendarId => text().references(Calendars, #id, onDelete: KeyAction.cascade)();
  TextColumn get uid => text().nullable()(); // iCalendar UID
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get location => text().nullable()();
  IntColumn get startMs => integer()(); // UTC milliseconds
  IntColumn get endMs => integer()(); // UTC milliseconds
  TextColumn get tzid => text().nullable()(); // Original timezone
  BoolColumn get allDay => boolean().withDefault(const Constant(false))();
  TextColumn get rrule => text().nullable()(); // Recurrence rule (RFC5545)
  TextColumn get exdates => text().nullable()(); // Exception dates (JSON array of UTC millis)
  TextColumn get rdates => text().nullable()(); // Recurrence dates (JSON array of UTC millis)
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get metadata => text()
      .customConstraint('NOT NULL DEFAULT \'{}\' CHECK (json_valid(metadata))')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {calendarId, uid}, // Prevent duplicate event UIDs in same calendar
  ];
}
