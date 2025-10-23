part of '../database.dart';

/// Color palettes - user-defined color collections
@DataClassName('ColorPalette')
class ColorPalettes extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get shareCode => text().nullable()(); // For sharing palettes
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get metadata => text()
      .customConstraint('NOT NULL DEFAULT \'{}\' CHECK (json_valid(metadata))')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {userId, name}, // Unique palette names per user
  ];
}

/// Palette colors - individual colors in a palette
@DataClassName('PaletteColor')
class PaletteColors extends Table {
  TextColumn get id => text()();
  TextColumn get paletteId => text().references(ColorPalettes, #id, onDelete: KeyAction.cascade)();
  IntColumn get ordinal => integer()(); // Display order (0-indexed)
  TextColumn get hex => text()(); // Color hex code
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {paletteId, ordinal}, // Unique ordinal per palette
  ];
}
