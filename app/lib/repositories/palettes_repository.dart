import 'package:drift/drift.dart';
import '../database/database.dart';
import '../logging/logger.dart';
import '../utils/id_generator.dart';

/// Repository for managing Color Palettes with automatic outbox recording
class PalettesRepository {
  final AppDatabase _db;
  final Logger _logger;

  PalettesRepository({
    required AppDatabase db,
  })  : _db = db,
        _logger = Logger.instance;

  /// Insert a new color palette and record in outbox
  Future<ColorPalette> insert({
    required String userId,
    required String name,
    String? shareCode,
    String? metadata,
  }) async {
    final id = IdGenerator.generateUlid();
    final now = DateTime.now().millisecondsSinceEpoch;

    final palette = await _db.transaction(() async {
      // Insert palette
      final palette = await _db.into(_db.colorPalettes).insertReturning(ColorPalettesCompanion(
            id: Value(id),
            userId: Value(userId),
            name: Value(name),
            shareCode: Value(shareCode),
            createdAt: Value(now),
            updatedAt: Value(now),
            metadata: Value(metadata ?? '{}'),
          ));

      // Record in outbox
      await _recordChange(
        table: 'color_palette',
        rowId: id,
        operation: 'INSERT',
      );

      _logger.info(
        'Color palette created',
        tag: 'repo.palette.insert',
        metadata: {
          'palette_id': id,
          'user_id': userId,
          'name': name,
        },
      );

      return palette;
    });

    return palette;
  }

  /// Add a color to a palette
  Future<PaletteColor> addColor({
    required String paletteId,
    required int ordinal,
    required String hex,
  }) async {
    final id = IdGenerator.generateUlid();
    final now = DateTime.now().millisecondsSinceEpoch;

    final color = await _db.transaction(() async {
      // Insert color
      final color = await _db.into(_db.paletteColors).insertReturning(PaletteColorsCompanion(
            id: Value(id),
            paletteId: Value(paletteId),
            ordinal: Value(ordinal),
            hex: Value(hex),
            createdAt: Value(now),
            updatedAt: Value(now),
          ));

      // Record in outbox
      await _recordChange(
        table: 'palette_color',
        rowId: id,
        operation: 'INSERT',
      );

      _logger.info(
        'Palette color added',
        tag: 'repo.palette.add_color',
        metadata: {
          'color_id': id,
          'palette_id': paletteId,
          'hex': hex,
          'ordinal': ordinal,
        },
      );

      return color;
    });

    return color;
  }

  /// Update an existing palette and record in outbox
  Future<ColorPalette> update({
    required String id,
    String? userId,
    String? name,
    String? shareCode,
    String? metadata,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final palette = await _db.transaction(() async {
      // Update palette
      final updated = await (_db.update(_db.colorPalettes)..where((t) => t.id.equals(id))).writeReturning(
            ColorPalettesCompanion(
              userId: userId != null ? Value(userId) : const Value.absent(),
              name: name != null ? Value(name) : const Value.absent(),
              shareCode: shareCode != null ? Value(shareCode) : const Value.absent(),
              updatedAt: Value(now),
              metadata: metadata != null ? Value(metadata) : const Value.absent(),
            ),
          );

      if (updated.isEmpty) {
        throw Exception('Color palette not found: $id');
      }

      // Record in outbox
      await _recordChange(
        table: 'color_palette',
        rowId: id,
        operation: 'UPDATE',
      );

      _logger.info(
        'Color palette updated',
        tag: 'repo.palette.update',
        metadata: {
          'palette_id': id,
          'fields_updated': {
            if (name != null) 'name': name,
            if (shareCode != null) 'share_code': shareCode,
          },
        },
      );

      return updated.first;
    });

    return palette;
  }

  /// Soft delete a palette (mark as deleted in metadata) and record in outbox
  Future<void> softDelete(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.transaction(() async {
      // Fetch current palette
      final palette = await (_db.select(_db.colorPalettes)..where((t) => t.id.equals(id))).getSingleOrNull();

      if (palette == null) {
        throw Exception('Color palette not found: $id');
      }

      // Update with deleted flag in metadata
      await (_db.update(_db.colorPalettes)..where((t) => t.id.equals(id))).write(
            ColorPalettesCompanion(
              metadata: Value('{"deleted":true}'),
              updatedAt: Value(now),
            ),
          );

      // Record in outbox
      await _recordChange(
        table: 'color_palette',
        rowId: id,
        operation: 'DELETE',
      );

      _logger.info(
        'Color palette soft deleted',
        tag: 'repo.palette.delete',
        metadata: {'palette_id': id, 'name': palette.name},
      );
    });
  }

  /// Get palette by ID
  Future<ColorPalette?> getById(String id) async {
    return (_db.select(_db.colorPalettes)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Get all palettes for a user
  Future<List<ColorPalette>> getByUser(String userId) async {
    return (_db.select(_db.colorPalettes)..where((t) => t.userId.equals(userId))).get();
  }

  /// Get all colors for a palette, ordered by ordinal
  Future<List<PaletteColor>> getColors(String paletteId) async {
    return (_db.select(_db.paletteColors)
          ..where((t) => t.paletteId.equals(paletteId))
          ..orderBy([(t) => OrderingTerm(expression: t.ordinal)]))
        .get();
  }

  /// Get all palettes for a user with their colors
  Future<List<Map<String, dynamic>>> getPalettesForUser(String userId) async {
    final palettes = await getByUser(userId);
    final result = <Map<String, dynamic>>[];

    for (final palette in palettes) {
      final colors = await getColors(palette.id);
      result.add({
        'palette': palette,
        'colors': colors,
      });
    }

    return result;
  }

  /// Get the active palette for a user from user_profile
  Future<ColorPalette?> getActivePalette(String userId) async {
    final profile = await (_db.select(_db.userProfiles)..where((t) => t.userId.equals(userId))).getSingleOrNull();

    if (profile == null || profile.paletteId == null) {
      return null;
    }

    return getById(profile.paletteId!);
  }

  /// Set the active palette for a user in user_profile
  Future<void> setActivePalette({
    required String userId,
    required String paletteId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.transaction(() async {
      // Update user_profile
      await (_db.update(_db.userProfiles)..where((t) => t.userId.equals(userId))).write(UserProfilesCompanion(
        paletteId: Value(paletteId),
        updatedAt: Value(now),
      ));

      // Record in outbox
      await _recordChange(
        table: 'user_profile',
        rowId: userId,
        operation: 'UPDATE',
      );

      _logger.info(
        'Active palette updated',
        tag: 'repo.palette.set_active',
        metadata: {
          'user_id': userId,
          'palette_id': paletteId,
        },
      );
    });
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
