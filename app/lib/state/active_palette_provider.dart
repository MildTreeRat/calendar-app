import 'package:flutter/foundation.dart';
import '../database/database.dart';
import '../repositories/palettes_repository.dart';
import '../logging/logger.dart';

/// Manages active palette state for a user
class ActivePaletteProvider extends ChangeNotifier {
  final PalettesRepository _palettesRepo;
  final String _userId;
  final Logger _logger;

  ColorPalette? _activePalette;
  List<PaletteColor> _paletteColors = [];
  List<Map<String, dynamic>> _allPalettes = [];
  bool _isLoading = false;
  String? _error;

  ActivePaletteProvider({
    required AppDatabase db,
    required String userId,
  })  : _palettesRepo = PalettesRepository(db: db),
        _userId = userId,
        _logger = Logger.instance {
    _init();
  }

  /// Active palette for the user
  ColorPalette? get activePalette => _activePalette;

  /// Colors in the active palette, ordered by ordinal
  List<PaletteColor> get paletteColors => List.unmodifiable(_paletteColors);

  /// All available palettes with their colors
  List<Map<String, dynamic>> get allPalettes => List.unmodifiable(_allPalettes);

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Initialize by loading active palette and all palettes
  Future<void> _init() async {
    await loadPalettes();
  }

  /// Load all palettes and the active one
  Future<void> loadPalettes() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load all palettes for user
      _allPalettes = await _palettesRepo.getPalettesForUser(_userId);

      // Load active palette
      _activePalette = await _palettesRepo.getActivePalette(_userId);

      // Load colors for active palette
      if (_activePalette != null) {
        _paletteColors = await _palettesRepo.getColors(_activePalette!.id);
      } else {
        _paletteColors = [];
      }

      _logger.debug(
        'Palettes loaded',
        tag: 'state.active_palette.load',
        metadata: {
          'user_id': _userId,
          'total_palettes': _allPalettes.length,
          'active_palette_id': _activePalette?.id,
          'color_count': _paletteColors.length,
        },
      );
    } catch (e) {
      _error = e.toString();
      _logger.error(
        'Failed to load palettes',
        tag: 'state.active_palette.error',
        metadata: {'user_id': _userId, 'error': e.toString()},
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Set the active palette
  Future<void> setActivePalette(String paletteId) async {
    try {
      // Update in database
      await _palettesRepo.setActivePalette(
        userId: _userId,
        paletteId: paletteId,
      );

      // Reload to get updated state
      _activePalette = await _palettesRepo.getById(paletteId);
      if (_activePalette != null) {
        _paletteColors = await _palettesRepo.getColors(_activePalette!.id);
      }

      _logger.info(
        'Active palette changed',
        tag: 'ui.select_palette',
        metadata: {
          'palette_id': paletteId,
          'palette_name': _activePalette?.name,
        },
      );

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _logger.error(
        'Failed to set active palette',
        tag: 'state.active_palette.set_error',
        metadata: {
          'palette_id': paletteId,
          'error': e.toString(),
        },
      );
      notifyListeners();
    }
  }

  /// Get color by ordinal (for indexed color assignment)
  /// Returns null if ordinal is out of range
  PaletteColor? getColorByOrdinal(int ordinal) {
    try {
      return _paletteColors.firstWhere((c) => c.ordinal == ordinal);
    } catch (e) {
      return null;
    }
  }

  /// Get color hex by ordinal with fallback
  String? getColorHex(int ordinal) {
    final color = getColorByOrdinal(ordinal);
    return color?.hex;
  }

  /// Get color hex for a calendar by index (wraps around if more calendars than colors)
  String? getColorForCalendarIndex(int index) {
    if (_paletteColors.isEmpty) return null;
    final ordinal = index % _paletteColors.length;
    return getColorHex(ordinal);
  }
}
