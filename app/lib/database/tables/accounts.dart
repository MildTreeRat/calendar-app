part of '../database.dart';

/// Accounts - connected external accounts (Google, Apple, etc.)
@DataClassName('Account')
class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id, onDelete: KeyAction.restrict, onUpdate: KeyAction.cascade)();
  TextColumn get provider => text().check(provider.isIn(['google', 'apple', 'local']))();
  TextColumn get subject => text()(); // Provider's user ID
  TextColumn get label => text().nullable()(); // "Work", "Personal", etc.
  TextColumn get syncToken => text().nullable()();
  IntColumn get lastSyncMs => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get metadata => text()
      .customConstraint('NOT NULL DEFAULT \'{}\' CHECK (json_valid(metadata))')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {provider, subject}, // Prevent duplicate account linkage
  ];
}
