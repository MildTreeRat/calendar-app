import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:app/utils/color_resolver.dart';
import 'package:app/logging/logger.dart';

void main() {
  group('ColorResolver', () {
    late ColorResolver resolver;

    setUpAll(() {
      // Initialize logger for tests
      Logger.initialize();
    });

    setUp(() {
      resolver = ColorResolver();
    });

    group('resolveCalendarColor', () {
      test('uses override color when provided', () {
        final color = resolver.resolveCalendarColor(
          calendarId: 'cal1',
          overrideHex: '#FF0000', // Red
          paletteHex: '#00FF00', // Green
          calendarHex: '#0000FF', // Blue
        );

        expect(color, const Color(0xFFFF0000)); // Should be red (override)
      });

      test('uses palette color when no override', () {
        final color = resolver.resolveCalendarColor(
          calendarId: 'cal1',
          paletteHex: '#00FF00', // Green
          calendarHex: '#0000FF', // Blue
        );

        expect(color, const Color(0xFF00FF00)); // Should be green (palette)
      });

      test('uses calendar color when no override or palette', () {
        final color = resolver.resolveCalendarColor(
          calendarId: 'cal1',
          calendarHex: '#0000FF', // Blue
        );

        expect(color, const Color(0xFF0000FF)); // Should be blue (calendar)
      });

      test('uses fallback color when nothing provided', () {
        final color = resolver.resolveCalendarColor(
          calendarId: 'cal1',
        );

        expect(color, const Color(0xFF5470FF)); // Should be fallback
      });

      test('handles hex colors without # prefix', () {
        final color = resolver.resolveCalendarColor(
          calendarId: 'cal1',
          calendarHex: 'FF5733',
        );

        expect(color, const Color(0xFFFF5733));
      });
    });

    group('calculateLuminance', () {
      test('calculates white as high luminance', () {
        final luminance = resolver.calculateLuminance(Colors.white);
        expect(luminance, greaterThan(0.9));
      });

      test('calculates black as low luminance', () {
        final luminance = resolver.calculateLuminance(Colors.black);
        expect(luminance, lessThan(0.1));
      });

      test('calculates gray as medium luminance', () {
        final luminance = resolver.calculateLuminance(Colors.grey);
        expect(luminance, greaterThan(0.2));
        expect(luminance, lessThan(0.8));
      });
    });

    group('getContrastingTextColor', () {
      test('returns black text for light backgrounds', () {
        final textColor = resolver.getContrastingTextColor(Colors.white);
        expect(textColor, const Color(0xFF000000));
      });

      test('returns white text for dark backgrounds', () {
        final textColor = resolver.getContrastingTextColor(Colors.black);
        expect(textColor, const Color(0xFFFFFFFF));
      });

      test('returns black text for yellow', () {
        final textColor = resolver.getContrastingTextColor(Colors.yellow);
        expect(textColor, const Color(0xFF000000));
      });

      test('returns white text for dark blue', () {
        final textColor = resolver.getContrastingTextColor(Colors.blue.shade900);
        expect(textColor, const Color(0xFFFFFFFF));
      });
    });

    group('calculateContrastRatio', () {
      test('returns 21 for black and white', () {
        final ratio = resolver.calculateContrastRatio(Colors.black, Colors.white);
        expect(ratio, closeTo(21.0, 0.1));
      });

      test('returns 1 for identical colors', () {
        final ratio = resolver.calculateContrastRatio(Colors.red, Colors.red);
        expect(ratio, closeTo(1.0, 0.1));
      });

      test('symmetric for color order', () {
        final ratio1 = resolver.calculateContrastRatio(Colors.black, Colors.white);
        final ratio2 = resolver.calculateContrastRatio(Colors.white, Colors.black);
        expect(ratio1, closeTo(ratio2, 0.1));
      });
    });

    group('meetsWCAGContrast', () {
      test('black on white passes', () {
        expect(resolver.meetsWCAGContrast(Colors.black, Colors.white), isTrue);
      });

      test('white on white fails', () {
        expect(resolver.meetsWCAGContrast(Colors.white, Colors.white), isFalse);
      });

      test('dark gray on white passes', () {
        expect(
          resolver.meetsWCAGContrast(Colors.grey.shade800, Colors.white),
          isTrue,
        );
      });
    });

    group('ColorLuminance extension', () {
      test('provides luminance getter', () {
        expect(Colors.white.luminance, greaterThan(0.9));
        expect(Colors.black.luminance, lessThan(0.1));
      });
    });
  });
}
