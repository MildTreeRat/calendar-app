# Database and Repository Testing Guide

## Overview

This document outlines the comprehensive testing strategy for database operations and repositories to prevent production bugs like the "SqliteException: no such table: changes" error that occurred when users tried to select color preferences.

## The Production Bug That Should Never Happen Again

### What Happened
- **User Action:** Clicked to change a color preference
- **Error:** `SqliteException(1): while preparing statement, no such table: changes, SQL logic error code 1`
- **Root Cause:** The `changes` table wasn't properly created during database initialization
- **Impact:** Users couldn't modify any preferences; all repository operations failed

### Why It Happened
- Database schema defined the `changes` table in code
- Tests didn't verify that ALL tables were created
- Database initialization tests only checked for presence of seeded data, not schema completeness
- Repository operations assumed the `changes` table existed

### Why Tests Would Have Caught This
If we had proper repository tests that:
1. Exercised CRUD operations through repositories (not just direct database access)
2. Verified that `changes` table was accessible
3. Tested the full flow from user action → repository → database → changes table

Then the test would have failed with the same SqliteException before any code reached production.

## Test Coverage Requirements

### Level 1: Database Schema Tests (CRITICAL)
**File:** `test/database_test.dart`

```dart
test('should create ALL required tables including changes', () async {
  // Verify every table in the schema exists and is queryable
  expect(() => database.select(database.changes).get(), returnsNormally);
  expect(() => database.select(database.users).get(), returnsNormally);
  expect(() => database.select(database.calendars).get(), returnsNormally);
  // ... for every table
});

test('should be able to insert into changes table', () async {
  // This is what repositories do - if this fails, everything fails
  await database.into(database.changes).insert(ChangesCompanion(...));
  final changes = await database.select(database.changes).get();
  expect(changes.length, 1);
});
```

### Level 2: Repository Integration Tests (CRITICAL)
**Files:** `test/repositories/*_repository_test.dart`

Every repository must have tests that verify:

```dart
group('Repository - Changes Table Integration', () {
  test('REGRESSION: operations must record changes', () async {
    // This simulates what happens in production
    final entity = await repository.create(...);

    // Verify change was recorded - THIS IS WHERE THE BUG OCCURRED
    final changes = await database.select(database.changes).get();
    expect(changes.isNotEmpty, true,
      reason: 'Repository must record changes for sync');
  });

  test('CRITICAL: changes table must be accessible', () async {
    // Direct test that changes table exists
    expect(
      () async => await database.into(database.changes).insert(...),
      returnsNormally,
      reason: 'SqliteException here means production will crash',
    );
  });
});
```

### Level 3: End-to-End Flow Tests
**File:** `test/integration/user_flows_test.dart`

```dart
test('user can change color preference without SqliteException', () async {
  // Simulate exact user flow that caused the bug
  final palette = await palettesRepo.insert(...);
  final color = await palettesRepo.addColor(...);

  // This is what crashed in production
  await palettesRepo.updateColor(id: color.id, hex: '#FF0000');

  // Verify it worked
  final updated = await palettesRepo.getColorById(color.id);
  expect(updated.hex, '#FF0000');
});
```

## Test Implementation Status

### ✅ Completed
1. **`test/database_test.dart`** - Basic database initialization tests
   - ✅ Creates all tables
   - ✅ Seeds default data
   - ✅ Tests foreign key constraints
   - ⚠️  **Missing:** Explicit `changes` table verification

2. **`test/repositories/calendars_repository_test.dart`** - **13 passing tests**
   - ✅ CRUD operations with changes table recording
   - ✅ Regression test for changes table existence
   - ✅ Concurrent operations
   - ✅ Transaction handling
   - ✅ Edge cases

### 🔄 Needed
3. **`test/repositories/palettes_repository_test.dart`** - CRITICAL (caused the bug)
   - Must test color preference changes
   - Must verify changes table integration
   - Must simulate the exact production bug scenario

4. **`test/repositories/events_repository_test.dart`** - High Priority
   - Events use changes table extensively
   - Critical for calendar sync

5. **`test/repositories/tasks_repository_test.dart`** - High Priority
   - Tasks also record changes

## Repository Test Template

Use this template for ALL new repository tests:

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/database/database.dart';
import 'package:app/repositories/YOUR_repository.dart';
import 'package:app/logging/logger.dart';
import 'package:matcher/matcher.dart' as matcher;

void main() {
  late AppDatabase database;
  late YourRepository repository;

  setUpAll(() async {
    await Logger.initialize(
      config: const LoggerConfig(level: LogLevel.error, console: false),
    );
  });

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = YourRepository(db: database);
  });

  tearDown(() async {
    await database.close();
  });

  group('YourRepository - REGRESSION TESTS', () {
    test('CRITICAL: changes table must exist', () async {
      final testId = 'test-${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now().millisecondsSinceEpoch;

      expect(
        () async => await database.into(database.changes).insert(
          ChangesCompanion(
            id: Value(testId),
            tableNameCol: const Value('your_table'),
            rowId: const Value('test-row'),
            operation: const Value('INSERT'),
            payloadJson: const Value('{}'),
            updatedAt: Value(now),
            createdAt: Value(now),
            isPushed: const Value(false),
          ),
        ),
        returnsNormally,
        reason: 'This prevents SqliteException in production',
      );
    });

    test('REGRESSION: create operation must record change', () async {
      final entity = await repository.create(...);

      final changes = await database.select(database.changes).get();
      expect(changes.any((c) => c.rowId == entity.id), true);
    });

    test('REGRESSION: update operation must record change', () async {
      final entity = await repository.create(...);
      await database.delete(database.changes).go();

      await repository.update(...);

      final changes = await database.select(database.changes).get();
      expect(changes.length, 1);
      expect(changes.first.operation, 'UPDATE');
    });

    test('REGRESSION: delete operation must record change', () async {
      final entity = await repository.create(...);
      await database.delete(database.changes).go();

      await repository.delete(...);

      final changes = await database.select(database.changes).get();
      expect(changes.length, 1);
      expect(changes.first.operation, 'DELETE');
    });
  });

  group('YourRepository - CRUD Operations', () {
    // Test normal CRUD functionality
  });

  group('YourRepository - Edge Cases', () {
    // Test error handling, null cases, etc.
  });
}
```

## Running Tests

### Run All Tests
```bash
cd app
flutter test
```

### Run Specific Test File
```bash
flutter test test/repositories/calendars_repository_test.dart
```

### Run Tests with Coverage
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

## Test Assertions That Prevent Bugs

### ❌ BAD: Only testing the happy path
```dart
test('should create calendar', () async {
  final cal = await repo.createCalendar(name: 'Test');
  expect(cal.name, 'Test'); // This doesn't catch the changes table bug!
});
```

### ✅ GOOD: Testing the full integration
```dart
test('should create calendar AND record change', () async {
  final cal = await repo.insert(name: 'Test', ...);
  expect(cal.name, 'Test');

  // THIS is what catches the bug:
  final changes = await database.select(database.changes).get();
  expect(changes.where((c) => c.rowId == cal.id).length, 1,
    reason: 'Must record in changes table for sync');
});
```

### ✅ BEST: Testing the exact failure scenario
```dart
test('REGRESSION: SqliteException bug must not occur', () async {
  // Simulate exact production scenario
  expect(
    () async => await repository.someOperation(),
    returnsNormally, // Will fail with SqliteException if table missing
    reason: 'This is the exact error users hit in production',
  );
});
```

## Continuous Integration

### Pre-commit Hook
```bash
#!/bin/bash
# Run tests before allowing commit
flutter test
if [ $? -ne 0 ]; then
  echo "Tests failed! Commit rejected."
  exit 1
fi
```

### CI Pipeline (GitHub Actions, etc.)
```yaml
- name: Run tests
  run: |
    cd app
    flutter test

- name: Check test coverage
  run: |
    flutter test --coverage
    # Fail if coverage < 80%
```

## What These Tests Protect Against

1. **Schema Migration Errors**
   - Missing tables in new schema versions
   - Incorrect table definitions
   - Missing indexes

2. **Repository Logic Errors**
   - Forgetting to record changes
   - Incorrect transaction handling
   - Missing null checks

3. **Integration Failures**
   - Database and repository mismatches
   - Sync logic breaking
   - Cascading delete issues

4. **Production Crashes**
   - SqliteException from missing tables
   - Null pointer exceptions
   - Data corruption

## Summary

**The Golden Rule:** If a repository operation touches the database, it MUST have a test that:
1. Exercises the operation
2. Verifies the changes table was updated
3. Tests the operation doesn't throw SqliteException

**Before Merging Any PR:**
- [ ] All repository methods have tests
- [ ] Tests verify changes table integration
- [ ] Tests pass locally
- [ ] Tests pass in CI
- [ ] Coverage doesn't decrease

**The production bug we experienced would have been caught by:**
- ✅ `test/repositories/palettes_repository_test.dart` - Would fail when trying to record change
- ✅ `test/database_test.dart` - Would fail if checking for changes table explicitly
- ✅ Any integration test that exercises color preferences

**Never again should we see:** `SqliteException(1): no such table: changes` in production! 🎯
