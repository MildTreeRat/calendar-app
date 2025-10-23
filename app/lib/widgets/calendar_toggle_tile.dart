import 'package:flutter/material.dart';
import '../database/database.dart';
import '../utils/color_resolver.dart';

/// A list tile with a colored chip, calendar name, and visibility switch
class CalendarToggleTile extends StatelessWidget {
  final Calendar calendar;
  final bool isVisible;
  final ValueChanged<bool> onToggle;

  const CalendarToggleTile({
    super.key,
    required this.calendar,
    required this.isVisible,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colorResolver = ColorResolver();
    final calendarColor = colorResolver.resolveCalendarColor(
      calendarId: calendar.id,
      calendarHex: calendar.color,
    );

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: calendarColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.calendar_today,
          color: colorResolver.getContrastingTextColor(calendarColor),
          size: 20,
        ),
      ),
      title: Text(
        calendar.name,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      subtitle: Text(
        calendar.source,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
      trailing: Switch(
        value: isVisible,
        onChanged: onToggle,
        activeColor: calendarColor,
      ),
    );
  }
}
