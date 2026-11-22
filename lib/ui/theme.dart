import 'package:flutter/material.dart';

// Tema gelap-hijau meniru ConfigColor.dart pada game asli.
class AppColors {
  static const primary = Color(0xFF00D261);
  static const primaryDark = Color(0xFF0A7A3B);
  static const accent = Color(0xFFFFC833);
  static const bg = Color(0xFF08100D);
  static const surface = Color(0xFF111D18);
  static const surface2 = Color(0xFF192922);
  static const line = Color(0xFF273D32);
  static const text = Color(0xFFECF4EF);
  static const muted = Color(0xFF8AA598);
  static const danger = Color(0xFFEF4444);
  static const gold = Color(0xFFFFD54F);
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      error: AppColors.danger,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
          color: AppColors.text,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2),
    ),
    cardTheme: CardTheme(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: const Color(0xFF04150B),
        elevation: 0,
        textStyle: const TextStyle(
            fontWeight: FontWeight.w800, letterSpacing: 0.2, fontSize: 13.5),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.line),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: const Color(0xFF04150B),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.surface2,
      selectedColor: AppColors.primaryDark,
      side: const BorderSide(color: AppColors.line),
      labelStyle: const TextStyle(
          color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.primary.withOpacity(0.16),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.muted,
          )),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.muted,
          )),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surface2,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.line),
      ),
      contentTextStyle: const TextStyle(color: AppColors.text),
    ),
  );
}

// Utilitas format
String formatMoney(num v) {
  final n = v.round();
  if (n >= 1000000000) {
    return '${(n / 1000000000).toStringAsFixed(1)} M';
  }
  if (n >= 1000000) {
    return '${(n / 1000000).toStringAsFixed(1)} jt';
  }
  if (n >= 1000) {
    return '${(n / 1000).toStringAsFixed(0)} rb';
  }
  return '$n';
}

class Squads {
  static String positionName(int posid) {
    const m = {
      1: 'GK',
      2: 'CB',
      3: 'SW',
      4: 'FB',
      5: 'DM',
      6: 'AM',
      7: 'CM',
      8: 'WM',
      9: 'WF',
      10: 'ST',
      11: 'SS',
    };
    return m[posid] ?? 'CM';
  }

  static Color positionColor(int posid) {
    if (posid == 1) return const Color(0xFFFFB74D);
    if (posid <= 4) return const Color(0xFF64B5F6);
    if (posid <= 8) return const Color(0xFF81C784);
    return const Color(0xFFE57373);
  }

  static Color powerColor(int poder) {
    if (poder >= 85) return const Color(0xFFFFD54F);
    if (poder >= 75) return const Color(0xFF00C853);
    if (poder >= 65) return const Color(0xFF64DD17);
    if (poder >= 55) return const Color(0xFF9E9D24);
    return const Color(0xFF78909C);
  }
}
