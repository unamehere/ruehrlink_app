import 'package:material_ui/material_ui.dart';

/// Design-Tokens – Farben, Schrift, Abstände an EINER Stelle.
///
/// Leitbild (docs/screens.md): viel Weißraum, eine Akzentfarbe, Schrift ≥ 18 pt,
/// Tippflächen ≥ 56 px, starker Kontrast. Schrift: Systemschrift (keine Laufzeit-Downloads).
abstract final class Tokens {
  /// Die eine Akzentfarbe (warmes Terrakotta).
  static const accent = Color(0xFFC2410C);

  /// Mindestgröße jeder Tippfläche.
  static const tap = 56.0;

  /// Höhe der großen Haupt-Buttons.
  static const bigButton = 64.0;

  static const radius = 20.0;

  // Abstände
  static const s = 8.0;
  static const m = 16.0;
  static const l = 24.0;
  static const xl = 40.0;

  /// Maximale Breite einspaltiger Inhalte (Lesebreite).
  static const maxContentWidth = 640.0;

  /// Maximale Breite zweispaltiger Layouts.
  static const maxTwoPaneWidth = 1200.0;
}

ThemeData buildTheme(Brightness brightness) {
  final light = brightness == Brightness.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: Tokens.accent,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    contrastLevel: 0.5,
  ).copyWith(surface: light ? Colors.white : const Color(0xFF121212));

  final base = ThemeData(colorScheme: scheme, brightness: brightness);
  final text = base.textTheme.copyWith(
    displaySmall: base.textTheme.displaySmall?.copyWith(
      fontSize: 44,
      fontWeight: FontWeight.w600,
    ),
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
      fontSize: 32,
      fontWeight: FontWeight.w600,
    ),
    headlineSmall: base.textTheme.headlineSmall?.copyWith(
      fontSize: 28,
      fontWeight: FontWeight.w600,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      fontSize: 24,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 20, height: 1.4),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 18, height: 1.4),
    bodySmall: base.textTheme.bodySmall?.copyWith(fontSize: 18),
    labelLarge: base.textTheme.labelLarge?.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    labelMedium: base.textTheme.labelMedium?.copyWith(fontSize: 18),
  );

  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Tokens.radius),
  );
  const buttonSize = Size(Tokens.tap, Tokens.tap);
  const buttonPadding = EdgeInsets.symmetric(
    horizontal: Tokens.l,
    vertical: 14,
  );
  final navLabel = WidgetStatePropertyAll(
    text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
  );

  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      centerTitle: false,
      titleTextStyle: text.headlineSmall?.copyWith(color: scheme.onSurface),
      toolbarHeight: 72,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: shape,
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: shape,
        textStyle: text.labelLarge,
        side: BorderSide(color: scheme.outline, width: 2),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: buttonSize,
        padding: buttonPadding,
        textStyle: text.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: buttonSize, iconSize: 32),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: shape,
      margin: EdgeInsets.zero,
    ),
    listTileTheme: ListTileThemeData(
      minTileHeight: 72,
      titleTextStyle: text.titleMedium?.copyWith(color: scheme.onSurface),
      subtitleTextStyle: text.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: Tokens.m),
      shape: shape,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Tokens.radius),
      ),
      contentPadding: const EdgeInsets.all(Tokens.m + 2),
      labelStyle: text.bodyLarge,
      hintStyle: text.bodyLarge,
    ),
    sliderTheme: const SliderThemeData(trackHeight: 8),
    navigationBarTheme: NavigationBarThemeData(
      height: 84,
      labelTextStyle: navLabel,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: const WidgetStatePropertyAll(IconThemeData(size: 30)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      labelType: NavigationRailLabelType.all,
      selectedLabelTextStyle: navLabel.value,
      unselectedLabelTextStyle: navLabel.value,
      selectedIconTheme: const IconThemeData(size: 30),
      unselectedIconTheme: const IconThemeData(size: 30),
      minWidth: 96,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      contentTextStyle: text.bodyLarge?.copyWith(
        color: scheme.onInverseSurface,
      ),
    ),
  );
}
