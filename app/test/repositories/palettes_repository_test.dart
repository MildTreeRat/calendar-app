import 'package:drift/drift.dart';import 'package:drift/drift.dart';

import 'package:drift/native.dart';import 'package:drift/native.dart';

import 'package:flutter_test/flutter_test.dart';import 'package:flutter_test/flutter_test.dart';

import 'package:app/database/database.dart';import 'package:app/database/database.dart';

import 'package:app/repositories/palettes_repository.dart';import 'package:app/repositories/palettes_repository.dart';

import 'package:app/logging/logger.dart';import 'package:app/logging/logger.dart';

import 'package:matcher/matcher.dart' as matcher;import 'package:matcher/matcher.dart' as matcher;



/// **CRITICAL: These tests prevent the production bug that occurred**/// CRITICAL: These tests prevent production bugs like the color preference SqliteException

/// ///

/// **Production Bug:**/// Bug that occurred in production:

/// - User clicked on a color preference/// - User tried to select a color for preferences

/// - Application crashed with: `SqliteException(1): no such table: changes`/// - SqliteException(1): no such table: changes

/// - Root cause: The `changes` table wasn't properly created in the database schema/// - This was caused because the changes table wasn't created during database migration

/// - Impact: Users couldn't change color preferences///

/// /// These tests ensure:

/// **What These Tests Do:**/// 1. The changes table exists and is accessible

/// 1. Verify the `changes` table exists and is accessible/// 2. All repository CRUD operations record changes properly

/// 2. Test that all repository operations record changes properly/// 3. Changes are not lost during concurrent operations

/// 3. Ensure database schema includes all necessary tablesvoid main() {

///   late AppDatabase database;

/// **If these tests fail, it means:**  late PalettesRepository repository;

/// - Database migration is broken  late String userId;

/// - Changes won't sync to cloud

/// - Users will hit SqliteException in production  setUpAll(() async {

void main() {    await Logger.initialize(

  late AppDatabase database;      config: const LoggerConfig(

  late PalettesRepository repository;        level: LogLevel.error,

  late String userId;        console: false,

      ),

  setUpAll(() async {    );

    await Logger.initialize(  });

      config: const LoggerConfig(

        level: LogLevel.error,  setUp(() async {

        console: false,    database = AppDatabase.forTesting(NativeDatabase.memory());

      ),    repository = PalettesRepository(db: database);

    );

  });    // Get seeded user

    final users = await database.select(database.users).get();

  setUp(() async {    userId = users.first.id;

    database = AppDatabase.forTesting(NativeDatabase.memory());  });

    repository = PalettesRepository(db: database);

      tearDown(() async {

    // Get seeded user    await database.close();

    final users = await database.select(database.users).get();  });

    userId = users.first.id;

  });  group('PalettesRepository - CRUD Operations', () {

    test('should create palette and record change in changes table', () async {

  tearDown() async {      final palette = await repository.insert(

    await database.close();        userId: userId,

  }        name: 'Test Palette',

      );

  group('PalettesRepository - Changes Table (REGRESSION TESTS)', () {

    test('CRITICAL: changes table must exist in database schema', () async {      expect(palette.name, 'Test Palette');

      // This is the core issue - the changes table must exist      expect(palette.userId, userId);

      // Without this test, we wouldn't catch schema migration errors

            // **CRITICAL**: Verify change was recorded in changes table

      final testId = 'test-${DateTime.now().millisecondsSinceEpoch}';      final changes = await database.select(database.changes).get();

      final now = DateTime.now().millisecondsSinceEpoch;      final paletteChanges = changes.where((c) =>

        c.tableNameCol == 'color_palette' &&

      // This is what every repository does - insert into changes table        c.rowId == palette.id &&

      // If this throws SqliteException, users can't perform any operations        c.operation == 'INSERT'

      expect(      ).toList();

        () async => await database.into(database.changes).insert(

          ChangesCompanion(      expect(paletteChanges.length, 1,

            id: Value(testId),        reason: 'Should record palette creation in changes table');

            tableNameCol: const Value('test_table'),      expect(paletteChanges.first.isPushed, false);

            rowId: const Value('test-row-123'),    });

            operation: const Value('INSERT'),

            payloadJson: const Value('{}'),    test('should add color to palette and record change', () async {

            updatedAt: Value(now),      final palette = await repository.insert(

            createdAt: Value(now),        userId: userId,

            isPushed: const Value(false),        name: 'Color Test',

          ),      );

        ),

        returnsNormally,      // Clear initial changes

        reason: 'MUST be able to insert into changes table - this is where the production bug occurred!',      await database.delete(database.changes).go();

      );

      final color = await repository.addColor(

      // Verify it was actually inserted        paletteId: palette.id,

      final change = await (database.select(database.changes)        ordinal: 0,

        ..where((c) => c.id.equals(testId)))        hex: '#FF0000',

        .getSingleOrNull();      );



      expect(change, matcher.isNotNull,      expect(color.hex, '#FF0000');

        reason: 'Changes table must exist and be queryable');      expect(color.paletteId, palette.id);

    });

      // Verify change recorded

    test('REGRESSION: creating palette must record change (simulates color preference bug)', () async {      final changes = await database.select(database.changes).get();

      // This simulates what happens when user selects a color      final colorChanges = changes.where((c) =>

      // In production, this threw "no such table: changes"        c.tableNameCol == 'palette_color' &&

              c.rowId == color.id &&

      expect(        c.operation == 'INSERT'

        () async => await repository.insert(      ).toList();

          userId: userId,

          name: 'User Preferences',      expect(colorChanges.length, 1,

        ),        reason: 'Should record color addition in changes table');

        returnsNormally,    });

        reason: 'Creating palette MUST NOT throw SqliteException about missing changes table',

      );    test('should update color and record change', () async {

      final palette = await repository.insert(

      // Verify the change was recorded        userId: userId,

      final changes = await database.select(database.changes).get();        name: 'Update Test',

      expect(changes.isNotEmpty, true,      );

        reason: 'Repository operations must record changes for sync');

    });      final color = await repository.addColor(

        paletteId: palette.id,

    test('REGRESSION: adding color must record change', () async {        ordinal: 0,

      final palette = await repository.insert(        hex: '#FF0000',

        userId: userId,      );

        name: 'Color Test',

      );      // Clear initial changes

      await database.delete(database.changes).go();

      // Clear to isolate this operation

      await database.delete(database.changes).go();      await repository.updateColor(

        id: color.id,

      // This is what happens when user selects a color        hex: '#00FF00',

      expect(      );

        () async => await repository.addColor(

          paletteId: palette.id,      final updated = await repository.getColorById(color.id);

          ordinal: 0,      expect(updated?.hex, '#00FF00');

          hex: '#4285F4',

        ),      // Verify change recorded

        returnsNormally,      final changes = await database.select(database.changes).get();

        reason: 'Adding color MUST NOT throw SqliteException',      final updateChanges = changes.where((c) =>

      );        c.tableNameCol == 'palette_color' &&

        c.rowId == color.id &&

      final changes = await database.select(database.changes).get();        c.operation == 'UPDATE'

      expect(changes.length, 1,      ).toList();

        reason: 'Color addition must be recorded for sync');

      expect(changes.first.tableNameCol, 'palette_color');      expect(updateChanges.length, 1,

      expect(changes.first.operation, 'INSERT');        reason: 'Should record color update in changes table');

    });    });



    test('REGRESSION: updating palette must record change', () async {    test('should delete color and record change', () async {

      final palette = await repository.insert(      final palette = await repository.insert(

        userId: userId,        userId: userId,

        name: 'Original Name',        name: 'Delete Test',

      );      );



      await database.delete(database.changes).go();      final color = await repository.addColor(

        paletteId: palette.id,

      expect(        ordinal: 0,

        () async => await repository.update(        hex: '#0000FF',

          id: palette.id,      );

          name: 'Updated Name',

        ),      // Clear initial changes

        returnsNormally,      await database.delete(database.changes).go();

        reason: 'Updating palette MUST NOT throw SqliteException',

      );      await repository.deleteColor(color.id);



      final changes = await database.select(database.changes).get();      final deleted = await repository.getColorById(color.id);

      expect(changes.length, 1);      expect(deleted, matcher.isNull);

      expect(changes.first.operation, 'UPDATE');

    });      // Verify change recorded

      final changes = await database.select(database.changes).get();

    test('REGRESSION: setting active palette must record change', () async {      final deleteChanges = changes.where((c) =>

      final palette = await repository.insert(        c.tableNameCol == 'palette_color' &&

        userId: userId,        c.rowId == color.id &&

        name: 'Active Palette',        c.operation == 'DELETE'

      );      ).toList();



      await database.delete(database.changes).go();      expect(deleteChanges.length, 1,

        reason: 'Should record color deletion in changes table');

      // This is triggered when user changes color preferences    });

      expect(

        () async => await repository.setActivePalette(    test('should delete entire palette and record change', () async {

          userId: userId,      final palette = await repository.insert(

          paletteId: palette.id,        userId: userId,

        ),        name: 'Delete Palette Test',

        returnsNormally,      );

        reason: 'Setting active palette MUST NOT throw SqliteException',

      );      await repository.addColor(

        paletteId: palette.id,

      final changes = await database.select(database.changes).get();        ordinal: 0,

      expect(changes.length, 1);        hex: '#111111',

      expect(changes.first.tableNameCol, 'user_profile');      );

    });

  });      await repository.addColor(

        paletteId: palette.id,

  group('PalettesRepository - Basic CRUD', () {        ordinal: 1,

    test('should create palette and record change', () async {        hex: '#222222',

      final palette = await repository.insert(      );

        userId: userId,

        name: 'Test Palette',      // Clear initial changes

      );      await database.delete(database.changes).go();



      expect(palette.name, 'Test Palette');      await repository.deletePalette(palette.id, userId: userId);

      expect(palette.userId, userId);

      final deleted = await repository.getById(palette.id);

      final changes = await (database.select(database.changes)      expect(deleted, matcher.isNull);

        ..where((c) => c.rowId.equals(palette.id)))

        .get();      // Verify change recorded

            final changes = await database.select(database.changes).get();

      expect(changes.length, 1);      expect(changes.any((c) =>

      expect(changes.first.operation, 'INSERT');        c.tableNameCol == 'color_palette' &&

      expect(changes.first.isPushed, false);        c.rowId == palette.id

    });      ), true, reason: 'Should record palette deletion');

    });

    test('should add color to palette', () async {

      final palette = await repository.insert(    test('should get palette with colors', () async {

        userId: userId,      final palette = await repository.insert(

        name: 'Color Test',        userId: userId,

      );        name: 'Full Palette',

      );

      final color = await repository.addColor(

        paletteId: palette.id,      await repository.addColor(paletteId: palette.id, ordinal: 0, hex: '#FF0000');

        ordinal: 0,      await repository.addColor(paletteId: palette.id, ordinal: 1, hex: '#00FF00');

        hex: '#FF0000',      await repository.addColor(paletteId: palette.id, ordinal: 2, hex: '#0000FF');

      );

      final colors = await repository.getColorsByPalette(palette.id);

      expect(color.hex, '#FF0000');      expect(colors.length, 3);

      expect(color.paletteId, palette.id);      expect(colors[0].hex, '#FF0000');

      expect(color.ordinal, 0);      expect(colors[1].hex, '#00FF00');

    });      expect(colors[2].hex, '#0000FF');

    });

    test('should get palette by ID', () async {

      final palette = await repository.insert(    test('should list palettes for user', () async {

        userId: userId,      await repository.insert(userId: userId, name: 'Palette 1');

        name: 'Get Test',      await repository.insert(userId: userId, name: 'Palette 2');

      );

      final palettes = await repository.getByUser(userId);

      final retrieved = await repository.getById(palette.id);

      expect(retrieved, matcher.isNotNull);      // Should include default palette + 2 new ones

      expect(retrieved!.name, 'Get Test');      expect(palettes.length, greaterThanOrEqualTo(3));

    });

      final newPalettes = palettes.where((p) =>

    test('should list palettes for user', () async {        p.name == 'Palette 1' || p.name == 'Palette 2'

      await repository.insert(userId: userId, name: 'Palette 1');      ).toList();

      await repository.insert(userId: userId, name: 'Palette 2');      expect(newPalettes.length, 2);

    });

      final palettes = await repository.getByUser(userId);  });



      // Should include default + 2 new ones  group('PalettesRepository - REGRESSION: Production Bug Fix', () {

      expect(palettes.length, greaterThanOrEqualTo(3));    test('CRITICAL: changes table must exist when updating colors (production bug)', () async {

    });      // This test simulates the exact scenario that caused the production bug:

      // User selects a color for preference, which triggers a repository update

    test('should get colors for palette ordered by ordinal', () async {

      final palette = await repository.insert(      final palette = await repository.insert(

        userId: userId,        userId: userId,

        name: 'Ordered Colors',        name: 'User Preferences',

      );      );



      await repository.addColor(paletteId: palette.id, ordinal: 2, hex: '#0000FF');      final color = await repository.addColor(

      await repository.addColor(paletteId: palette.id, ordinal: 0, hex: '#FF0000');        paletteId: palette.id,

      await repository.addColor(paletteId: palette.id, ordinal: 1, hex: '#00FF00');        ordinal: 0,

        hex: '#4285F4', // Default blue

      final colors = await repository.getColors(palette.id);      );



      expect(colors.length, 3);      // Clear initial changes to simulate fresh state

      expect(colors[0].ordinal, 0);      await database.delete(database.changes).go();

      expect(colors[0].hex, '#FF0000');

      expect(colors[1].ordinal, 1);      // This is what happened in production - user selecting a color

      expect(colors[1].hex, '#00FF00');      // This MUST NOT throw SqliteException(1): no such table: changes

      expect(colors[2].ordinal, 2);      expect(

      expect(colors[2].hex, '#0000FF');        () async => await repository.updateColor(

    });          id: color.id,

          hex: '#EA4335', // User selects red

    test('should soft delete palette', () async {        ),

      final palette = await repository.insert(        returnsNormally,

        userId: userId,        reason: 'Updating color should not throw "no such table: changes" exception',

        name: 'To Delete',      );

      );

      // Verify the color was actually updated

      await database.delete(database.changes).go();      final updated = await repository.getColorById(color.id);

      expect(updated?.hex, '#EA4335');

      await repository.softDelete(palette.id);

      // Verify change was recorded (this is where the bug occurred)

      final deleted = await repository.getById(palette.id);      final changes = await database.select(database.changes).get();

      expect(deleted, matcher.isNotNull); // Still exists      expect(changes.length, 1,

      expect(deleted!.metadata, contains('deleted'));        reason: 'Change must be recorded in changes table');

      expect(changes.first.tableNameCol, 'palette_color');

      // Verify deletion recorded      expect(changes.first.operation, 'UPDATE');

      final changes = await database.select(database.changes).get();    });

      expect(changes.length, 1);

      expect(changes.first.operation, 'DELETE');    test('should handle changes table insertions during transactions', () async {

    });      // Ensure changes table is accessible within transactions

      await database.transaction(() async {

    test('should get palettes with colors', () async {        final palette = await repository.insert(

      final palette = await repository.insert(          userId: userId,

        userId: userId,          name: 'Transaction Test',

        name: 'Full Palette',        );

      );

        // This should not throw even within a transaction

      await repository.addColor(paletteId: palette.id, ordinal: 0, hex: '#111111');        await repository.addColor(

      await repository.addColor(paletteId: palette.id, ordinal: 1, hex: '#222222');          paletteId: palette.id,

          ordinal: 0,

      final palettesWithColors = await repository.getPalettesForUser(userId);          hex: '#ABCDEF',

              );

      expect(palettesWithColors.length, greaterThanOrEqualTo(2)); // Default + 1 new      });



      final newPalette = palettesWithColors.firstWhere(      final changes = await database.select(database.changes).get();

        (p) => (p['palette'] as ColorPalette).name == 'Full Palette'      expect(changes.length, greaterThan(0),

      );        reason: 'Changes should be recorded even within transactions');

          });

      final colors = newPalette['colors'] as List<PaletteColor>;

      expect(colors.length, 2);    test('direct insert into changes table should work', () async {

    });      // Test that we can directly insert into changes table

      // This is what repositories do internally

    test('should set and get active palette', () async {      final testId = 'direct-test-${DateTime.now().millisecondsSinceEpoch}';

      final palette = await repository.insert(      final now = DateTime.now().millisecondsSinceEpoch;

        userId: userId,

        name: 'Active Palette',      expect(

      );        () async => await database.into(database.changes).insert(

          ChangesCompanion(

      await repository.setActivePalette(            id: Value(testId),

        userId: userId,            tableNameCol: const Value('palette_color'),

        paletteId: palette.id,            rowId: const Value('test-color-123'),

      );            operation: const Value('UPDATE'),

            payloadJson: const Value('{"hex":"#FF0000"}'),

      final activePalette = await repository.getActivePalette(userId);            updatedAt: Value(now),

      expect(activePalette, matcher.isNotNull);            createdAt: Value(now),

      expect(activePalette!.id, palette.id);            isPushed: const Value(false),

    });          ),

  });        ),

        returnsNormally,

  group('PalettesRepository - Changes Table Integrity', () {        reason: 'Direct insert into changes table must work without SqliteException',

    test('should record multiple operations sequentially', () async {      );

      final palette = await repository.insert(

        userId: userId,      // Verify it was inserted

        name: 'Multi-Op Test',      final change = await (database.select(database.changes)

      );        ..where((c) => c.id.equals(testId)))

        .getSingleOrNull();

      await repository.update(id: palette.id, name: 'Updated');

      await repository.softDelete(palette.id);      expect(change, matcher.isNotNull);

      expect(change!.tableNameCol, 'palette_color');

      final allChanges = await (database.select(database.changes)      expect(change.operation, 'UPDATE');

        ..where((c) => c.rowId.equals(palette.id))    });

        ..orderBy([(c) => OrderingTerm.asc(c.createdAt)]))  });

        .get();

  group('PalettesRepository - Changes Table Integrity', () {

      expect(allChanges.length, 3);    test('should record all palette operations sequentially', () async {

      expect(allChanges[0].operation, 'INSERT');      final palette = await repository.insert(

      expect(allChanges[1].operation, 'UPDATE');        userId: userId,

      expect(allChanges[2].operation, 'DELETE');        name: 'Sequential Test',

      );

      // All should be unpushed

      expect(allChanges.every((c) => !c.isPushed), true);      final color = await repository.addColor(

    });        paletteId: palette.id,

        ordinal: 0,

    test('should handle concurrent palette creations', () async {        hex: '#111111',

      final futures = <Future>[];      );



      for (int i = 0; i < 10; i++) {      await repository.updateColor(id: color.id, hex: '#222222');

        futures.add(repository.insert(      await repository.deleteColor(color.id);

          userId: userId,

          name: 'Concurrent $i',      final allChanges = await (database.select(database.changes)

        ));        ..where((c) => c.rowId.equals(color.id))

      }        ..orderBy([(c) => OrderingTerm.asc(c.createdAt)]))

        .get();

      await Future.wait(futures);

      expect(allChanges.length, 3);

      final changes = await (database.select(database.changes)      expect(allChanges[0].operation, 'INSERT');

        ..where((c) => c.tableNameCol.equals('color_palette')))      expect(allChanges[1].operation, 'UPDATE');

        .get();      expect(allChanges[2].operation, 'DELETE');



      expect(changes.length, greaterThanOrEqualTo(10),      // All should be unpushed

        reason: 'All concurrent operations must be recorded');      expect(allChanges.every((c) => !c.isPushed), true);

    });    });



    test('should record changes within transactions', () async {    test('should handle concurrent palette operations', () async {

      await database.transaction(() async {      final futures = <Future>[];

        final palette = await repository.insert(

          userId: userId,      for (int i = 0; i < 5; i++) {

          name: 'Transaction Test',        futures.add(repository.insert(

        );          userId: userId,

          name: 'Concurrent Palette $i',

        await repository.addColor(        ));

          paletteId: palette.id,      }

          ordinal: 0,

          hex: '#ABCDEF',      await Future.wait(futures);

        );

      });      final changes = await (database.select(database.changes)

        ..where((c) => c.tableNameCol.equals('color_palette')))

      final changes = await database.select(database.changes).get();        .get();

      expect(changes.length, greaterThan(0),

        reason: 'Changes must be recorded even within transactions');      expect(changes.length, greaterThanOrEqualTo(5),

    });        reason: 'All concurrent operations should be recorded');

  });    });

}

    test('should maintain referential integrity with palette colors', () async {
      final palette = await repository.insert(
        userId: userId,
        name: 'Referential Test',
      );

      final color1 = await repository.addColor(
        paletteId: palette.id,
        ordinal: 0,
        hex: '#AAAAAA',
      );

      final color2 = await repository.addColor(
        paletteId: palette.id,
        ordinal: 1,
        hex: '#BBBBBB',
      );

      // Delete palette should cascade delete colors
      await repository.deletePalette(palette.id, userId: userId);

      final color1After = await repository.getColorById(color1.id);
      final color2After = await repository.getColorById(color2.id);

      expect(color1After, matcher.isNull);
      expect(color2After, matcher.isNull);

      // Changes should still exist for audit trail
      final changes = await database.select(database.changes).get();
      expect(changes.isNotEmpty, true);
    });
  });
}
