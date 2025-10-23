import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database.dart';
import '../repositories/events_repository.dart';
import '../state/visible_window.dart';
import '../state/visible_calendars_provider.dart';
import '../state/active_palette_provider.dart';
import '../models/event_vm.dart';
import '../logging/logger.dart';
import '../utils/color_resolver.dart';
import 'week_view.dart';
import 'agenda_view.dart';
import 'preferences_sheet.dart';
import 'export_sheet.dart';

/// Main calendar screen with Week and Agenda views
class CalendarHome extends StatefulWidget {
  final AppDatabase database;
  final String userId;

  const CalendarHome({
    super.key,
    required this.database,
    required this.userId,
  });

  @override
  State<CalendarHome> createState() => _CalendarHomeState();
}

class _CalendarHomeState extends State<CalendarHome>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late VisibleWindow _window;
  late EventsRepository _eventsRepo;
  late VisibleCalendarsProvider _calendarsProvider;
  late ActivePaletteProvider _paletteProvider;
  late ColorResolver _colorResolver;
  final Logger _logger = Logger.instance;

  List<EventVM> _events = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _window = VisibleWindow();
    _eventsRepo = EventsRepository(db: widget.database);
    _calendarsProvider = VisibleCalendarsProvider(
      db: widget.database,
      userId: widget.userId,
    );
    _paletteProvider = ActivePaletteProvider(
      db: widget.database,
      userId: widget.userId,
    );
    _colorResolver = ColorResolver();

    _window.addListener(_onWindowChanged);
    _calendarsProvider.addListener(_loadEvents);
    _paletteProvider.addListener(_loadEvents);
    _loadEvents();
  }

  void _onWindowChanged() {
    _logger.debug(
      'Window extended',
      tag: 'ui.window_extend',
      metadata: {
        'new_start': _window.startMs,
        'new_end': _window.endMs,
        'duration_days': _window.durationDays,
      },
    );
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final events = await _eventsRepo.getWindow(
        widget.userId,
        _window.startMs,
        _window.endMs,
      );

      // Get base calendar colors
      final calendarIds = events.map((e) => e.calendarId).toSet().toList();
      final calendarColors = await _eventsRepo.getCalendarColors(calendarIds);

      // Build color map with palette support
      final colorMap = <String, String>{};
      for (final calendarId in calendarIds) {
        final calendar = _calendarsProvider.getCalendar(calendarId);
        if (calendar == null) continue;

        // Get palette color by calendar index (simple strategy)
        final calendarIndex = calendarIds.indexOf(calendarId);
        final paletteHex = _paletteProvider.getColorForCalendarIndex(calendarIndex);

        // TODO: Get override color from calendar_membership if exists
        // For now, just use palette > calendar > fallback
        final resolvedColor = _colorResolver.resolveCalendarColor(
          calendarId: calendarId,
          paletteHex: paletteHex,
          calendarHex: calendarColors[calendarId],
        );

        colorMap[calendarId] = '#${resolvedColor.value.toRadixString(16).substring(2)}';
      }

      final eventVMs = events
          .map((e) => EventVM.fromEvent(
                e,
                color: colorMap[e.calendarId] ?? '#2196F3',
              ))
          .toList();

      setState(() {
        _events = eventVMs;
        _isLoading = false;
      });

      _logger.info(
        'Events loaded',
        tag: 'ui.events_loaded',
        metadata: {
          'count': events.length,
          'start': _window.start.toIso8601String(),
          'end': _window.end.toIso8601String(),
        },
      );
    } catch (e, stack) {
      _logger.error(
        'Failed to load events',
        tag: 'ui.events_error',
        error: e,
        stackTrace: stack,
      );

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _goToToday() {
    _window.resetToToday();
    _logger.debug('Navigated to today', tag: 'ui.today_tap');
  }

  String _getMonthYearLabel() {
    final now = DateTime.now();
    return DateFormat.yMMMM().format(now);
  }

  void _openPreferences() {
    PreferencesSheet.show(
      context,
      calendarsProvider: _calendarsProvider,
      paletteProvider: _paletteProvider,
    );
  }

  void _openExport() {
    ExportSheet.show(
      context,
      widget.database,
      widget.userId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          // Export button
          IconButton(
            onPressed: _openExport,
            icon: const Icon(Icons.file_download),
            tooltip: 'Export Calendar',
          ),
          // Preferences button
          IconButton(
            onPressed: _openPreferences,
            icon: const Icon(Icons.settings),
            tooltip: 'Preferences',
          ),
          // Today button
          TextButton.icon(
            onPressed: _goToToday,
            icon: const Icon(Icons.today),
            label: const Text('Today'),
          ),
          const SizedBox(width: 8),
          // Month/Year label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              _getMonthYearLabel(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Week', icon: Icon(Icons.view_week)),
            Tab(text: 'Agenda', icon: Icon(Icons.view_agenda)),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'Error loading events',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadEvents,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        WeekView(
          userId: widget.userId,
          events: _events,
          startDate: _window.start,
        ),
        AgendaView(
          userId: widget.userId,
          events: _events,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _window.removeListener(_onWindowChanged);
    _calendarsProvider.removeListener(_loadEvents);
    _paletteProvider.removeListener(_loadEvents);
    _window.dispose();
    _calendarsProvider.dispose();
    _paletteProvider.dispose();
    super.dispose();
  }
}
