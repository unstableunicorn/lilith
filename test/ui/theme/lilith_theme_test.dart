import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  /// WCAG AA for normal text.
  const minimum = 4.5;

  for (final brightness in Brightness.values) {
    group('${brightness.name} theme', () {
      final theme = lilithTheme(brightness);
      final s = theme.colorScheme;

      /// Every text-on-background pairing a screen may use.
      final pairs = <String, (Color, Color)>{
        'text on the page': (s.onSurface, s.surface),
        'muted text on the page': (s.onSurfaceVariant, s.surface),
        'text on a card': (s.onSurface, s.surfaceContainerLow),
        'muted text on a card': (s.onSurfaceVariant, s.surfaceContainerLow),
        'primary text on the page': (s.primary, s.surface),
        'primary text on a card': (s.primary, s.surfaceContainerLow),
        'error text on the page': (s.error, s.surface),
        'error text on a card': (s.error, s.surfaceContainerLow),
        'filled button label': (s.onPrimary, s.primary),
        'tonal button label': (s.onSecondaryContainer, s.secondaryContainer),
        'highlighted card text': (s.onPrimaryContainer, s.primaryContainer),
        'error banner text': (s.onErrorContainer, s.errorContainer),
      };

      for (final MapEntry(key: name, value: (fg, bg)) in pairs.entries) {
        test('$name reads at $minimum:1 or better', () {
          expect(contrastRatio(fg, bg), greaterThanOrEqualTo(minimum));
        });
      }

      test('uses the bundled font and flat cards', () {
        expect(theme.textTheme.bodyMedium?.fontFamily, 'Roboto');
        expect(theme.cardTheme.elevation, 0);
        expect(theme.colorScheme.brightness, brightness);
      });
    });
  }

  test(
    'contrastRatio is 21 for black on white and 1 for a colour on itself',
    () {
      expect(contrastRatio(Colors.black, Colors.white), closeTo(21, 0.01));
      expect(contrastRatio(lilithSeed, lilithSeed), 1);
    },
  );
}
