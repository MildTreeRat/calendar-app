import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event_vm.dart';
import '../logging/logger.dart';

/// Week view showing 7-day grid with events
class WeekView extends StatefulWidget {
  final String userId;
  final List<EventVM> events;
  final DateTime startDate;

  const WeekView({
    super.key,
    required this.userId,
    required this.events,
    required this.startDate,
  });

  @override
  State<WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends State<WeekView> {
  final _scrollController = ScrollController();
  final Logger _logger = Logger.instance;
  late DateTime _weekStart;
  late List<DateTime> _weekDays;

  @override
  void initState() {
    super.initState();
    _weekStart = _getWeekStart(widget.startDate);
    _weekDays = List.generate(7, (i) => _weekStart.add(Duration(days: i)));

    // Scroll to current time on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentTime();
    });
  }

  DateTime _getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday % 7));
  }

  void _scrollToCurrentTime() {
    final now = DateTime.now();
    final minutesSinceMidnight = now.hour * 60 + now.minute;
    final offset = (minutesSinceMidnight / 15) * 20.0; // 20px per 15min slot

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        offset - 100, // Offset to show some context above
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final stopwatch = Stopwatch()..start();

    final eventsByDay = <int, List<EventVM>>{};
    for (var i = 0; i < 7; i++) {
      eventsByDay[i] = [];
    }

    // Group events by day
    for (final event in widget.events) {
      final dayIndex = event.start.difference(_weekStart).inDays;
      if (dayIndex >= 0 && dayIndex < 7) {
        eventsByDay[dayIndex]!.add(event);
      }
    }

    // Assign lanes per day
    for (var i = 0; i < 7; i++) {
      eventsByDay[i] = assignLanes(eventsByDay[i]!);
    }

    stopwatch.stop();
    _logger.debug(
      'Week view rendered',
      tag: 'ui.week_open_ms',
      metadata: {
        'ms': stopwatch.elapsedMilliseconds,
        'count_events': widget.events.length,
      },
    );

    return Column(
      children: [
        _buildDayHeaders(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTimeColumn(),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: 96, // 24 hours * 4 (15-min slots)
                  itemBuilder: (context, index) {
                    final hour = index ~/ 4;
                    final minute = (index % 4) * 15;
                    return _buildTimeSlot(hour, minute, eventsByDay);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDayHeaders() {
    final now = DateTime.now();
    final dateFormat = DateFormat('EEE d');

    return Container(
      height: 50,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 60), // Time column width
          ...List.generate(7, (i) {
            final day = _weekDays[i];
            final isToday = day.year == now.year &&
                day.month == now.month &&
                day.day == now.day;

            return Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isToday ? Colors.blue.shade50 : null,
                  border: Border(
                    left: i > 0 ? BorderSide(color: Colors.grey.shade300) : BorderSide.none,
                  ),
                ),
                child: Text(
                  dateFormat.format(day),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    color: isToday ? Colors.blue.shade700 : null,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimeColumn() {
    return SizedBox(
      width: 60,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 24,
        itemBuilder: (context, hour) {
          return SizedBox(
            height: 80, // 4 slots * 20px per slot
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: Text(
                  DateFormat.j().format(DateTime(2000, 1, 1, hour)),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeSlot(int hour, int minute, Map<int, List<EventVM>> eventsByDay) {
    final now = DateTime.now();
    final isCurrentTimeSlot = now.hour == hour &&
        (now.minute >= minute && now.minute < minute + 15);

    return SizedBox(
      height: 20,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...List.generate(7, (dayIndex) {
            final dayEvents = eventsByDay[dayIndex]!
                .where((e) {
                  final eventMinutes = e.minutesFromMidnight;
                  final slotMinutes = hour * 60 + minute;
                  return eventMinutes <= slotMinutes &&
                      slotMinutes < (eventMinutes + e.durationMinutes);
                })
                .toList();

            return Expanded(
              child: Stack(
                children: [
                  // Grid line
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: minute == 0
                              ? Colors.grey.shade400
                              : Colors.grey.shade200,
                          width: minute == 0 ? 1 : 0.5,
                        ),
                        left: dayIndex > 0
                            ? BorderSide(color: Colors.grey.shade300)
                            : BorderSide.none,
                      ),
                    ),
                  ),
                  // Current time indicator
                  if (isCurrentTimeSlot)
                    Container(
                      height: 2,
                      color: Colors.red,
                    ),
                  // Events
                  ...dayEvents.map((event) {
                    if (event.minutesFromMidnight == hour * 60 + minute) {
                      return _buildEventBox(event);
                    }
                    return const SizedBox.shrink();
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEventBox(EventVM event) {
    final heightInSlots = (event.durationMinutes / 15).ceil();
    final width = event.totalLanes > 1 ? 1.0 / event.totalLanes : 1.0;
    final left = event.lane / event.totalLanes;

    return Positioned(
      left: left * 100,  // Percentage
      width: width * 100, // Percentage
      top: 0,
      child: Container(
        height: heightInSlots * 20.0,
        margin: const EdgeInsets.only(right: 2, bottom: 2),
        decoration: BoxDecoration(
          color: event.backgroundColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Text(
            event.title,
            style: TextStyle(
              fontSize: 10,
              color: event.textColor,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
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
