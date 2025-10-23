import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event_vm.dart';
import '../logging/logger.dart';

/// Agenda view showing events grouped by date
class AgendaView extends StatefulWidget {
  final String userId;
  final List<EventVM> events;

  const AgendaView({
    super.key,
    required this.userId,
    required this.events,
  });

  @override
  State<AgendaView> createState() => _AgendaViewState();
}

class _AgendaViewState extends State<AgendaView> {
  final Logger _logger = Logger.instance;
  final _scrollController = ScrollController();
  late Map<DateTime, List<EventVM>> _eventsByDate;
  late List<DateTime> _sortedDates;

  @override
  void initState() {
    super.initState();
    _groupEvents();

    // Scroll to today on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToToday();
    });
  }

  @override
  void didUpdateWidget(AgendaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.events != oldWidget.events) {
      _groupEvents();
    }
  }

  void _groupEvents() {
    final stopwatch = Stopwatch()..start();

    _eventsByDate = groupByDate(widget.events);
    _sortedDates = _eventsByDate.keys.toList()..sort();

    stopwatch.stop();
    _logger.debug(
      'Agenda view grouped',
      tag: 'ui.agenda_open_ms',
      metadata: {
        'ms': stopwatch.elapsedMilliseconds,
        'count_events': widget.events.length,
        'count_days': _sortedDates.length,
      },
    );
  }

  void _scrollToToday() {
    if (!_scrollController.hasClients) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final index = _sortedDates.indexWhere((date) =>
        date.year == today.year &&
        date.month == today.month &&
        date.day == today.day);

    if (index >= 0) {
      // Each day header + events, approximate 80px per day
      final offset = index * 80.0;
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sortedDates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No events in this time range',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _sortedDates.length,
      itemBuilder: (context, index) {
        final date = _sortedDates[index];
        final events = _eventsByDate[date]!;
        return _buildDaySection(date, events);
      },
    );
  }

  Widget _buildDaySection(DateTime date, List<EventVM> events) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDateHeader(date, isToday, events.length),
        ...events.map((event) => _buildEventTile(event)),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildDateHeader(DateTime date, bool isToday, int count) {
    final dateFormat = DateFormat.yMMMEd();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isToday ? Colors.blue.shade50 : Colors.grey.shade100,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              dateFormat.format(date),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isToday ? Colors.blue.shade700 : Colors.black87,
              ),
            ),
          ),
          Text(
            '$count ${count == 1 ? 'event' : 'events'}',
            style: TextStyle(
              fontSize: 14,
              color: isToday ? Colors.blue.shade600 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventTile(EventVM event) {
    final timeFormat = DateFormat.jm();

    return InkWell(
      onTap: () {
        // TODO: Navigate to event detail
        _logger.debug(
          'Event tapped',
          tag: 'ui.event_tap',
          metadata: {'event_id': event.id, 'title': event.title},
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time column
            SizedBox(
              width: 80,
              child: event.allDay
                  ? const Text(
                      'All day',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          timeFormat.format(event.start),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          timeFormat.format(event.end),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(width: 12),
            // Color indicator
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: event.backgroundColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            // Event details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (event.location != null && event.location!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.location!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
