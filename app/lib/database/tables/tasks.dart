part of '../database.dart';

/// Task lists - collections of tasks
@DataClassName('TaskList')
class TaskLists extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text().nullable().references(Accounts, #id, onDelete: KeyAction.cascade)();
  TextColumn get userId => text().references(Users, #id, onDelete: KeyAction.restrict)();
  TextColumn get source => text().check(source.isIn(['apple', 'google', 'obsidian', 'local']))();
  TextColumn get name => text()();
  TextColumn get externalId => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get metadata => text()
      .customConstraint('NOT NULL DEFAULT \'{}\' CHECK (json_valid(metadata))')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {userId, source, externalId}, // Prevent duplicate task list imports
  ];
}

/// Tasks - individual todo items
@DataClassName('Task')
class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get taskListId => text().references(TaskLists, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  IntColumn get dueMs => integer().nullable()(); // Due date (UTC millis)
  IntColumn get completedMs => integer().nullable()(); // Completion time
  TextColumn get notes => text().nullable()();
  IntColumn get priority => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get metadata => text()
      .customConstraint('NOT NULL DEFAULT \'{}\' CHECK (json_valid(metadata))')();

  @override
  Set<Column> get primaryKey => {id};
}
