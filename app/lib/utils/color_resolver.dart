import 'dart:math' as math;
import 'dart:ui';
import '../logging/logger.dart';

/// Utility for resolving calendar colors with fallback rules
class ColorResolver {
  final Logger _logger;

  ColorResolver() : _logger = Logger.instance;

  /// Resolve calendar color with priority: override > palette > calendar > fallback
  ///
  /// Resolution order:
  /// 1. membership.override_color (per-user custom color)
  /// 2. palette color (from active palette)
  /// 3. calendar.color (calendar default)
  /// 4. fallback #5470FF (Material Blue 500 variant)
  Color resolveCalendarColor({
    required String calendarId,
    String? overrideHex,
    String? paletteHex,
    String? calendarHex,
  }) {
    String? selectedHex;
    String source;

    if (overrideHex != null) {
      selectedHex = overrideHex;
      source = 'override';
    } else if (paletteHex != null) {
      selectedHex = paletteHex;
      source = 'palette';
    } else if (calendarHex != null) {
      selectedHex = calendarHex;
      source = 'calendar';
    } else {
      selectedHex = '#5470FF';
      source = 'fallback';
    }

    final color = _parseHexColor(selectedHex);

    _logger.debug(
      'Color resolved',
      tag: 'theme.color_resolve',
      metadata: {
        'calendar_id': calendarId,
        'source': source,
        'hex': selectedHex,
      },
    );

    return color;
  }

  /// Parse hex color string to Color object
  Color _parseHexColor(String hex) {
    final cleanHex = hex.replaceFirst('#', '');
    return Color(int.parse('FF$cleanHex', radix: 16));
  }

  /// Calculate relative luminance (WCAG formula)
  /// Returns value between 0 (black) and 1 (white)
  double calculateLuminance(Color color) {
    final r = _sRGBtoLinear(color.red / 255.0);
    final g = _sRGBtoLinear(color.green / 255.0);
    final b = _sRGBtoLinear(color.blue / 255.0);

    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Convert sRGB color component to linear RGB
  double _sRGBtoLinear(double value) {
    if (value <= 0.03928) {
      return value / 12.92;
    } else {
      return ((value + 0.055) / 1.055).pow(2.4);
    }
  }

  /// Get contrasting text color (black or white) based on background luminance
  /// Uses WCAG 2.0 contrast ratio guidelines
  Color getContrastingTextColor(Color backgroundColor) {
    final luminance = calculateLuminance(backgroundColor);

    // If luminance > 0.5, background is light → use black text
    // If luminance ≤ 0.5, background is dark → use white text
    return luminance > 0.5 ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  }

  /// Calculate contrast ratio between two colors (WCAG formula)
  /// Returns value between 1 (no contrast) and 21 (max contrast)
  double calculateContrastRatio(Color color1, Color color2) {
    final lum1 = calculateLuminance(color1);
    final lum2 = calculateLuminance(color2);

    final lighter = lum1 > lum2 ? lum1 : lum2;
    final darker = lum1 > lum2 ? lum2 : lum1;

    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Check if two colors meet WCAG AA contrast requirement (4.5:1)
  bool meetsWCAGContrast(Color foreground, Color background) {
    return calculateContrastRatio(foreground, background) >= 4.5;
  }
}

// Extension for convenient access to luminance on Color
extension ColorLuminance on Color {
  double get luminance {
    final resolver = ColorResolver();
    return resolver.calculateLuminance(this);
  }
}

// Extension for convenient pow method on double
extension _NumPow on double {
  double pow(double exponent) {
    return math.pow(this, exponent).toDouble();
  }
}
