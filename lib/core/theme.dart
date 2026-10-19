import 'package:flutter/material.dart';

abstract final class SuwarColors {
  static const ivory = Color(0xFFF7F4EA);
  static const paper = Color(0xFFFFFCF5);
  static const green = Color(0xFF173F35);
  static const active = Color(0xFF245C49);
  static const ink = Color(0xFF203C34);
  static const muted = Color(0xFF66756B);
  static const gold = Color(0xFFAC884B);
  static const goldText = Color(0xFF82632E);
  static const line = Color(0xFFDDDCCD);
  static const sage = Color(0xFFE8EEE5);
}

TextStyle headingStyle(
  BuildContext context, {
  double size = 30,
  Color? color,
}) => TextStyle(
  fontFamily: 'Amiri',
  fontSize: size,
  height: 1.65,
  color: color ?? SuwarColors.green,
);

ThemeData suwarTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: SuwarColors.green,
    brightness: Brightness.light,
    surface: SuwarColors.ivory,
    primary: SuwarColors.green,
    onPrimary: SuwarColors.paper,
    onSurface: SuwarColors.ink,
  );
  return ThemeData(
    useMaterial3: true,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    colorScheme: scheme,
    scaffoldBackgroundColor: SuwarColors.ivory,
    fontFamily: 'NotoSansArabic',
    textTheme: const TextTheme(
      bodyLarge: TextStyle(fontSize: 16, height: 1.75),
      bodyMedium: TextStyle(fontSize: 14, height: 1.7),
      bodySmall: TextStyle(fontSize: 12, height: 1.6),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: SuwarColors.ivory,
      foregroundColor: SuwarColors.green,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    dividerTheme: const DividerThemeData(color: SuwarColors.line, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SuwarColors.paper,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: SuwarColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: SuwarColors.line),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: SuwarColors.sage,
      selectedColor: SuwarColors.green,
      secondarySelectedColor: SuwarColors.green,
      checkmarkColor: SuwarColors.paper,
      shape: const StadiumBorder(),
      side: BorderSide.none,
      labelStyle: const TextStyle(
        fontFamily: 'NotoSansArabic',
        fontSize: 13,
        height: 1.65,
      ),
      secondaryLabelStyle: const TextStyle(color: SuwarColors.paper),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: SuwarColors.paper,
      indicatorColor: SuwarColors.sage,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'NotoSansArabic',
          fontSize: 12,
          color: states.contains(WidgetState.selected)
              ? SuwarColors.green
              : SuwarColors.muted,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.bold
              : FontWeight.normal,
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: SuwarColors.green,
      contentTextStyle: TextStyle(
        fontFamily: 'NotoSansArabic',
        color: SuwarColors.paper,
      ),
    ),
  );
}
