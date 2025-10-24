part of '../database.dart';

/// Users table - core user entity
@DataClassName('User')
class Users extends Table {
  TextColumn get id => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  TextColumn get metadata => text()
      .customConstraint('NOT NULL DEFAULT \'{}\' CHECK (json_valid(metadata))')();

  @override
  Set<Column> get primaryKey => {id};
}

/// User profiles - extended user information
@DataClassName('UserProfile')
class UserProfiles extends Table {
  TextColumn get userId => text().references(Users, #id, onDelete: KeyAction.cascade, onUpdate: KeyAction.cascade)();
  TextColumn get displayName => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get tzid => text().nullable()(); // IANA timezone
  TextColumn get paletteId => text().nullable()(); // Reference to color palette
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get metadata => text()
      .customConstraint('NOT NULL DEFAULT \'{}\' CHECK (json_valid(metadata))')();

  @override
  Set<Column> get primaryKey => {userId};
}
