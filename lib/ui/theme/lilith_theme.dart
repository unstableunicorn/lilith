// The look, in one place: colours from one seed, spacing, radii and the
// shapes of the standard widgets. Screens take everything from here or from
// a component; checks/style-drift.sh fails a screen that does not.

import 'package:material_ui/material_ui.dart';

/// The lavender the whole palette derives from, as in the original app.
const Color lilithSeed = Color(0xFF9B72CF);

/// Spacing steps. Nothing in a screen is spaced by any other number.
abstract final class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// The margin around a page's content.
  static const EdgeInsets page = EdgeInsets.all(lg);
}

/// Fixed sizes of things that are not text.
abstract final class Sizes {
  static const double chart = 200;
  static const double chartLabelGutter = 40;
}

/// Corner radii, from controls up to cards.
abstract final class Radii {
  static const double tile = 16;
  static const double control = 20;
  static const double card = 24;
}

ThemeData lilithTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: lilithSeed,
    brightness: brightness,
  );
  final control = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Radii.control),
  );
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(Radii.control),
    borderSide: BorderSide.none,
  );
  return ThemeData(
    colorScheme: scheme,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: scheme.surface,
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(vertical: Space.xs + 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: Space.xl,
          vertical: Space.md + 2,
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: Space.xl,
          vertical: Space.md + 2,
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: const StadiumBorder()),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Space.lg,
        vertical: Space.md + 2,
      ),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
      side: BorderSide(color: scheme.outlineVariant),
    ),
    dialogTheme: DialogThemeData(shape: control),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: control,
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.tile),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
    ),
  );
}

/// WCAG 2 contrast ratio between two colours, 1 to 21.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}
