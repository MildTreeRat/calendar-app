import 'package:flutter/material.dart';
import '../database/database.dart';
import '../utils/color_resolver.dart';

/// A palette picker with radio selection and color previews
class PalettePicker extends StatelessWidget {
  final List<Map<String, dynamic>> palettes;
  final String? activePaletteId;
  final ValueChanged<String> onPaletteSelected;

  const PalettePicker({
    super.key,
    required this.palettes,
    required this.activePaletteId,
    required this.onPaletteSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (palettes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No color palettes available'),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: palettes.length,
      itemBuilder: (context, index) {
        final paletteData = palettes[index];
        final palette = paletteData['palette'] as ColorPalette;
        final colors = paletteData['colors'] as List<PaletteColor>;

        return _PaletteTile(
          palette: palette,
          colors: colors,
          isSelected: palette.id == activePaletteId,
          onTap: () => onPaletteSelected(palette.id),
        );
      },
    );
  }
}

/// Individual palette tile with radio button and color preview
class _PaletteTile extends StatelessWidget {
  final ColorPalette palette;
  final List<PaletteColor> colors;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaletteTile({
    required this.palette,
    required this.colors,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<bool>(
      value: true,
      groupValue: isSelected,
      onChanged: (_) => onTap(),
      title: Text(
        palette.name,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: _ColorPreviewStrip(colors: colors),
      ),
    );
  }
}

/// Horizontal strip showing palette colors
class _ColorPreviewStrip extends StatelessWidget {
  final List<PaletteColor> colors;

  const _ColorPreviewStrip({required this.colors});

  @override
  Widget build(BuildContext context) {
    if (colors.isEmpty) {
      return const SizedBox(height: 20);
    }

    final colorResolver = ColorResolver();

    return SizedBox(
      height: 32,
      child: Row(
        children: [
          for (final color in colors.take(8)) // Show max 8 colors
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(
                  color: colorResolver.resolveCalendarColor(
                    calendarId: 'preview',
                    paletteHex: color.hex,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
