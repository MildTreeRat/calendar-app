import 'package:flutter/foundation.dart';
import '../database/database.dart';
import '../repositories/calendars_repository.dart';
import '../logging/logger.dart';

/// Manages visibility state for calendars with membership data
class VisibleCalendarsProvider extends ChangeNotifier {
  final AppDatabase _db;
  final CalendarsRepository _calendarsRepo;
  final String _userId;
  final Logger _logger;

  Map<String, bool> _visibilityMap = {};
  List<Calendar> _allCalendars = [];
  bool _isLoading = false;
  String? _error;

  VisibleCalendarsProvider({
    required AppDatabase db,
    required String userId,
  })  : _db = db,
        _calendarsRepo = CalendarsRepository(db: db),
        _userId = userId,
        _logger = Logger.instance {
    _init();
  }

  /// Current visibility map: calendarId → visible
  Map<String, bool> get visibilityMap => Map.unmodifiable(_visibilityMap);

  /// All calendars for the user
  List<Calendar> get allCalendars => List.unmodifiable(_allCalendars);

  /// Only visible calendars
  List<Calendar> get visibleCalendars {
    return _allCalendars.where((cal) => _visibilityMap[cal.id] == true).toList();
  }

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Initialize by loading calendars and visibility states
  Future<void> _init() async {
    await loadCalendars();
  }

  /// Load all calendars and their visibility states from DB
  Future<void> loadCalendars() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Get all calendars for user
      _allCalendars = await _calendarsRepo.getByUser(_userId);

      // Query calendar_memberships for visibility
      final memberships = await (_db.select(_db.calendarMemberships)
            ..where((t) => t.userId.equals(_userId)))
          .get();

      // Build visibility map
      _visibilityMap = {
        for (final m in memberships) m.calendarId: m.visible,
      };

      _logger.debug(
        'Calendars loaded',
        tag: 'state.visible_calendars.load',
        metadata: {
          'user_id': _userId,
          'total_calendars': _allCalendars.length,
          'visible_count': visibleCalendars.length,
        },
      );
    } catch (e) {
      _error = e.toString();
      _logger.error(
        'Failed to load calendars',
        tag: 'state.visible_calendars.error',
        metadata: {'user_id': _userId, 'error': e.toString()},
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggle visibility for a calendar
  Future<void> toggleCalendar(String calendarId) async {
    final currentVisibility = _visibilityMap[calendarId] ?? false;
    await setCalendarVisible(calendarId, !currentVisibility);
  }

  /// Set visibility for a calendar
  Future<void> setCalendarVisible(String calendarId, bool visible) async {
    try {
      // Update in database
      await _calendarsRepo.setVisible(
        userId: _userId,
        calendarId: calendarId,
        visible: visible,
      );

      // Update local state
      _visibilityMap[calendarId] = visible;

      _logger.info(
        'Calendar visibility toggled',
        tag: 'ui.toggle_calendar',
        metadata: {
          'calendar_id': calendarId,
          'to_visible': visible,
        },
      );

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _logger.error(
        'Failed to toggle calendar',
        tag: 'state.visible_calendars.toggle_error',
        metadata: {
          'calendar_id': calendarId,
          'error': e.toString(),
        },
      );
      notifyListeners();
    }
  }

  /// Check if a calendar is visible
  bool isVisible(String calendarId) {
    return _visibilityMap[calendarId] ?? false;
  }

  /// Get calendar by ID
  Calendar? getCalendar(String calendarId) {
    try {
      return _allCalendars.firstWhere((c) => c.id == calendarId);
    } catch (e) {
      return null;
    }
  }
}
