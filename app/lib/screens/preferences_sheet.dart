import 'package:flutter/material.dart';
import '../state/visible_calendars_provider.dart';
import '../state/active_palette_provider.dart';
import '../widgets/calendar_toggle_tile.dart';
import '../widgets/palette_picker.dart';

/// Modal bottom sheet for calendar and theme preferences
class PreferencesSheet extends StatelessWidget {
  final VisibleCalendarsProvider calendarsProvider;
  final ActivePaletteProvider paletteProvider;

  const PreferencesSheet({
    super.key,
    required this.calendarsProvider,
    required this.paletteProvider,
  });

  /// Show the preferences sheet as a modal bottom sheet
  static void show(
    BuildContext context, {
    required VisibleCalendarsProvider calendarsProvider,
    required ActivePaletteProvider paletteProvider,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => PreferencesSheet(
          calendarsProvider: calendarsProvider,
          paletteProvider: paletteProvider,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Preferences',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),

          const Divider(height: 1),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Calendars Section
                  _buildCalendarsSection(context),

                  const SizedBox(height: 32),

                  // Theme Section
                  _buildThemeSection(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Calendars',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Show or hide calendars in your views',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),

        // Calendar toggles
        AnimatedBuilder(
          animation: calendarsProvider,
          builder: (context, _) {
            if (calendarsProvider.isLoading) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (calendarsProvider.error != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Error: ${calendarsProvider.error}',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              );
            }

            final calendars = calendarsProvider.allCalendars;
            if (calendars.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No calendars found'),
                ),
              );
            }

            return Column(
              children: calendars.map((calendar) {
                final isVisible = calendarsProvider.isVisible(calendar.id);
                return CalendarToggleTile(
                  calendar: calendar,
                  isVisible: isVisible,
                  onToggle: (value) {
                    calendarsProvider.setCalendarVisible(calendar.id, value);
                  },
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildThemeSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Theme',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose a color palette for your events',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),

        // Palette picker
        AnimatedBuilder(
          animation: paletteProvider,
          builder: (context, _) {
            if (paletteProvider.isLoading) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (paletteProvider.error != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Error: ${paletteProvider.error}',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              );
            }

            return PalettePicker(
              palettes: paletteProvider.allPalettes,
              activePaletteId: paletteProvider.activePalette?.id,
              onPaletteSelected: (paletteId) {
                paletteProvider.setActivePalette(paletteId);
              },
            );
          },
        ),
      ],
    );
  }
}
