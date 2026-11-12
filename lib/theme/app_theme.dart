import 'package:flutter/material.dart';

class AppTheme {
  // ---- Shape scale (one rule, used everywhere) -------------------------
  // controls & inputs 12 · cards & chips 20 · sheets & floating bars 28.
  // Shapes use Apple-style continuous corners (superellipse), not plain
  // circular arcs.
  static const double radiusControl = 12;
  static const double radiusCard = 20;
  static const double radiusSurface = 28;

  /// Continuous-corner shape at one of the radii above.
  static RoundedSuperellipseBorder continuous(double radius) =>
      RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(radius));

  /// Continuous-corner shape with only the top corners rounded (sheets).
  static ShapeDecoration sheetDecoration(Color color) => ShapeDecoration(
        color: color,
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusSurface),
          ),
        ),
      );

  static final _snackBarTheme = SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: continuous(16),
  );
  static final _dialogTheme = DialogThemeData(shape: continuous(radiusSurface));
  static final _popupMenuTheme = PopupMenuThemeData(shape: continuous(16));

  /// Semantic warning colour ("due today", medium priority). Checked for
  /// >= 4.5:1 against the card and background colours of each theme.
  static Color warning(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFFCD34D) // amber-300 on charcoal
          : const Color(0xFFB45309); // amber-700 on white / light grey

  // ---- Professional grey & white palette ------------------------------
  // Neutral (no tint) greys in the style of Apple's system greys. The one
  // accent is near-black in light mode and near-white in dark mode; colour
  // is reserved for meaning (red = overdue/delete, amber = due today).

  // Light: light-grey page, white cards, charcoal ink.
  static const Color _ink = Color(0xFF1C1C1E);
  static const Color _lightBackground = Color(0xFFF2F2F7);

  static final ColorScheme _lightScheme = ColorScheme.fromSeed(
    seedColor: _ink,
    dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
  ).copyWith(
    primary: _ink,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFE5E5EA),
    onPrimaryContainer: _ink,
    secondary: const Color(0xFF3A3A3C),
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFFE5E5EA),
    onSecondaryContainer: _ink,
    surface: _lightBackground,
    onSurface: _ink,
    onSurfaceVariant: const Color(0xFF636366), // 5.6:1 on white
    surfaceTint: Colors.transparent,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: const Color(0xFFF7F7F9),
    surfaceContainer: const Color(0xFFEFEFF4),
    surfaceContainerHigh: const Color(0xFFE5E5EA),
    surfaceContainerHighest: const Color(0xFFD8D8DE),
    outline: const Color(0xFF8E8E93),
    outlineVariant: const Color(0xFFD1D1D6),
    error: const Color(0xFFC62828),
    onError: Colors.white,
  );

  // Dark: charcoal page, slightly lighter cards, near-white ink.
  static const Color _darkInk = Color(0xFFF2F2F7);

  static final ColorScheme _darkScheme = ColorScheme.fromSeed(
    seedColor: _ink,
    brightness: Brightness.dark,
    dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
  ).copyWith(
    primary: _darkInk,
    onPrimary: _ink,
    primaryContainer: const Color(0xFF3A3A3C),
    onPrimaryContainer: _darkInk,
    secondary: const Color(0xFFC7C7CC),
    onSecondary: _ink,
    secondaryContainer: const Color(0xFF3A3A3C),
    onSecondaryContainer: _darkInk,
    surface: const Color(0xFF121214),
    onSurface: _darkInk,
    onSurfaceVariant: const Color(0xFFAEAEB2), // 7.4:1 on #1C1C1E
    surfaceTint: Colors.transparent,
    surfaceDim: const Color(0xFF0C0C0E),
    surfaceBright: const Color(0xFF3A3A3C),
    surfaceContainerLowest: const Color(0xFF0C0C0E),
    surfaceContainerLow: const Color(0xFF18181A),
    surfaceContainer: const Color(0xFF1C1C1E),
    surfaceContainerHigh: const Color(0xFF2C2C2E),
    surfaceContainerHighest: const Color(0xFF3A3A3C),
    outline: const Color(0xFF8E8E93),
    outlineVariant: const Color(0xFF3A3A3C),
    error: const Color(0xFFFF8A80),
    onError: _ink,
  );

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: _lightScheme,
    scaffoldBackgroundColor: _lightBackground,
    // Titles are neutral; the accent is kept for actions and state.
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 2,
      backgroundColor: Colors.transparent,
      foregroundColor: _lightScheme.onSurface,
      titleTextStyle: TextStyle(
        color: _lightScheme.onSurface,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
    ),
    // The + button is the one place the accent is spent at full strength.
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: _lightScheme.primary,
      foregroundColor: _lightScheme.onPrimary,
      elevation: 4,
      shape: const CircleBorder(),
    ),
    cardTheme: CardThemeData(
      elevation: 0.5, // soft lift on the grey page, not a heavy drop shadow
      shadowColor: Colors.black.withValues(alpha: 0.5),
      surfaceTintColor: Colors.transparent,
      shape: continuous(radiusCard),
      color: Colors.white,
    ),
    chipTheme: ChipThemeData(shape: continuous(radiusCard)),
    snackBarTheme: _snackBarTheme,
    dialogTheme: _dialogTheme,
    popupMenuTheme: _popupMenuTheme,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusControl),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusControl),
        borderSide: BorderSide(color: _lightScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusControl),
        borderSide: BorderSide(color: _lightScheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: _darkScheme,
    scaffoldBackgroundColor: _darkScheme.surface,
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 2,
      backgroundColor: Colors.transparent,
      foregroundColor: _darkInk,
      titleTextStyle: TextStyle(
        color: _darkInk,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: _darkScheme.primary,
      foregroundColor: _darkScheme.onPrimary,
      elevation: 4,
      shape: const CircleBorder(),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: continuous(radiusCard),
      color: _darkScheme.surfaceContainer,
    ),
    chipTheme: ChipThemeData(shape: continuous(radiusCard)),
    snackBarTheme: _snackBarTheme,
    dialogTheme: _dialogTheme,
    popupMenuTheme: _popupMenuTheme,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _darkScheme.surfaceContainer,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusControl),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusControl),
        borderSide: BorderSide(color: _darkScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusControl),
        borderSide: BorderSide(color: _darkScheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
    ),
  );
}
