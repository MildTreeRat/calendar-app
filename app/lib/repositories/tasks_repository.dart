import 'package:drift/drift.dart';
import '../database/database.dart';
import '../logging/logger.dart';
import '../utils/id_generator.dart';

/// Repository for managing Tasks with automatic outbox recording
class TasksRepository {
  final AppDatabase _db;
  final Logger _logger;

  TasksRepository({
    required AppDatabase db,
  })  : _db = db,
        _logger = Logger.instance;

  /// Insert a new task and record in outbox
  Future<Task> insert({
    required String taskListId,
    required String title,
    String? notes,
    int? dueMs,
    int? completedMs,
    int? priority,
    String? metadata,
  }) async {
    final id = IdGenerator.generateUlid();
    final now = DateTime.now().millisecondsSinceEpoch;

    final task = await _db.transaction(() async {
      // Insert task
      final task = await _db.into(_db.tasks).insertReturning(TasksCompanion(
            id: Value(id),
            taskListId: Value(taskListId),
            title: Value(title),
            notes: Value(notes),
            dueMs: Value(dueMs),
            completedMs: Value(completedMs),
            priority: Value(priority),
            createdAt: Value(now),
            updatedAt: Value(now),
            metadata: Value(metadata ?? '{}'),
          ));

      // Record in outbox
      await _recordChange(
        table: 'task',
        rowId: id,
        operation: 'INSERT',
      );

      _logger.info(
        'Task created',
        tag: 'repo.task.insert',
        metadata: {
          'task_id': id,
          'task_list_id': taskListId,
          'title': title,
          'due_ms': dueMs,
        },
      );

      return task;
    });

    return task;
  }

  /// Update an existing task and record in outbox
  Future<Task> update({
    required String id,
    String? taskListId,
    String? title,
    String? notes,
    int? dueMs,
    int? completedMs,
    int? priority,
    String? metadata,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final task = await _db.transaction(() async {
      // Update task
      final updated = await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).writeReturning(
            TasksCompanion(
              taskListId: taskListId != null ? Value(taskListId) : const Value.absent(),
              title: title != null ? Value(title) : const Value.absent(),
              notes: notes != null ? Value(notes) : const Value.absent(),
              dueMs: dueMs != null ? Value(dueMs) : const Value.absent(),
              completedMs: completedMs != null ? Value(completedMs) : const Value.absent(),
              priority: priority != null ? Value(priority) : const Value.absent(),
              updatedAt: Value(now),
              metadata: metadata != null ? Value(metadata) : const Value.absent(),
            ),
          );

      if (updated.isEmpty) {
        throw Exception('Task not found: $id');
      }

      // Record in outbox
      await _recordChange(
        table: 'task',
        rowId: id,
        operation: 'UPDATE',
      );

      _logger.info(
        'Task updated',
        tag: 'repo.task.update',
        metadata: {
          'task_id': id,
          'fields_updated': {
            if (title != null) 'title': title,
            if (completedMs != null) 'completed_ms': completedMs,
          },
        },
      );

      return updated.first;
    });

    return task;
  }

  /// Mark task as complete
  Future<Task> complete(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return update(id: id, completedMs: now);
  }

  /// Mark task as incomplete
  Future<Task> uncomplete(String id) async {
    return update(id: id, completedMs: null);
  }

  /// Soft delete a task (mark as deleted in metadata) and record in outbox
  Future<void> softDelete(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.transaction(() async {
      // Fetch current task
      final task = await (_db.select(_db.tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

      if (task == null) {
        throw Exception('Task not found: $id');
      }

      // Update with deleted flag in metadata
      await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
            TasksCompanion(
              metadata: Value('{"deleted":true}'),
              updatedAt: Value(now),
            ),
          );

      // Record in outbox
      await _recordChange(
        table: 'task',
        rowId: id,
        operation: 'DELETE',
      );

      _logger.info(
        'Task soft deleted',
        tag: 'repo.task.delete',
        metadata: {'task_id': id, 'title': task.title},
      );
    });
  }

  /// Get task by ID
  Future<Task?> getById(String id) async {
    return (_db.select(_db.tasks)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Get all tasks for a task list
  Future<List<Task>> getByTaskList(String taskListId) async {
    return (_db.select(_db.tasks)..where((t) => t.taskListId.equals(taskListId))).get();
  }

  /// Get incomplete tasks
  Future<List<Task>> getIncomplete() async {
    return (_db.select(_db.tasks)..where((t) => t.completedMs.isNull())).get();
  }

  /// Get completed tasks
  Future<List<Task>> getCompleted() async {
    return (_db.select(_db.tasks)..where((t) => t.completedMs.isNotNull())).get();
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
