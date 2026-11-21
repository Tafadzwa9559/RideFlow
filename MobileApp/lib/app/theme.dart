import 'package:flutter/material.dart';

const emerald = Color(0xFF10B981);
const darkGreen = Color(0xFF047857);
const ink = Color(0xFF171717);
const muted = Color(0xFF666666);
const triviaOrange = Color(0xFFF59E0B);
const controlRadius = BorderRadius.all(Radius.circular(16));
const cardRadius = BorderRadius.all(Radius.circular(18));
const sheetRadius = BorderRadius.vertical(top: Radius.circular(28));
const pale = Color(0xFFECFDF5);

ThemeData triviaTheme() => _baseTheme(Brightness.light);
ThemeData triviaDarkTheme() => _baseTheme(Brightness.dark);

ThemeData _baseTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final background = isDark ? const Color(0xFF121412) : const Color(0xFFFFFFFF);
  final surface = isDark ? const Color(0xFF181B18) : Colors.white;
  final surfaceAlt = isDark ? const Color(0xFF222622) : const Color(0xFFF5F7F5);
  final border = isDark ? const Color(0xFF414841) : const Color(0xFFE1E7E2);
  final text = isDark ? const Color(0xFFF3F5F3) : ink;
  final mutedText = isDark ? const Color(0xFFBCC5BC) : muted;

  final primary = isDark ? const Color(0xFF6EE7B7) : darkGreen;
  final scheme = ColorScheme.fromSeed(
    seedColor: emerald,
    brightness: brightness,
    primary: primary,
    onPrimary: isDark ? ink : Colors.white,
    secondary: emerald,
    surface: surface,
    surfaceContainerLow: surfaceAlt,
    outlineVariant: border,
    error: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    brightness: brightness,
    scaffoldBackgroundColor: background,
    colorScheme: scheme,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    splashFactory: InkRipple.splashFactory,
    chipTheme: ChipThemeData(
      backgroundColor: surfaceAlt,
      selectedColor: scheme.primaryContainer,
      side: BorderSide(color: border),
      shape: const RoundedRectangleBorder(borderRadius: controlRadius),
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
    ),
    iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 24),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 44),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(borderRadius: sheetRadius),
    ),
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        color: text,
        letterSpacing: -1.4,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: text,
        letterSpacing: -0.8,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: text,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: text,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: text),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: mutedText),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: text,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: text,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: cardRadius,
        side: BorderSide(color: border),
      ),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      minLeadingWidth: 32,
      tileColor: isDark ? surface : null,
    ),
    dividerTheme: DividerThemeData(color: border, thickness: 1, space: 24),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceAlt,
      contentPadding: const EdgeInsets.all(17),
      border: OutlineInputBorder(
        borderRadius: controlRadius,
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: controlRadius,
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: controlRadius,
        borderSide: BorderSide(color: primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: controlRadius,
        borderSide: BorderSide(color: scheme.error, width: 1.2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(double.infinity, 54),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: controlRadius),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: controlRadius),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: isDark ? scheme.primaryContainer : pale,
      surfaceTintColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: text),
      ),
    ),
  );
}
