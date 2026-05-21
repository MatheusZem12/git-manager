import 'package:flutter/material.dart';

class AppTheme {
  static const Color bg = Color(0xFF0D0F12);
  static const Color bgElevated = Color(0xFF14161B);
  static const Color surface = Color(0xFF1A1D24);
  static const Color surfaceHover = Color(0xFF22262E);
  static const Color surfaceActive = Color(0xFF2B303A);
  static const Color border = Color(0x0DFFFFFF);
  static const Color borderStrong = Color(0x1AFFFFFF);
  static const Color borderFocus = Color(0x2EFFFFFF);

  static const Color text = Color(0xFFECEFF4);
  static const Color textSecondary = Color(0xFFA0AAB8);
  static const Color textMuted = Color(0xFF5E6A7A);

  static const Color accent = Color(0xFF6366F1);
  static const Color accentHover = Color(0xFF818CF8);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF06B6D4);

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      onPrimary: Colors.white,
      secondary: accentHover,
      surface: surface,
      surfaceContainerHighest: bgElevated,
      onSurface: text,
      onSurfaceVariant: textSecondary,
      outline: borderStrong,
      error: danger,
      onError: Colors.white,
    ),
    cardTheme: CardTheme(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: borderStrong, width: 1),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: bgElevated,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: text,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      ),
      iconTheme: IconThemeData(color: textSecondary),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: bgElevated,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accent, width: 2),
      ),
      hintStyle: const TextStyle(color: textMuted, fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        elevation: 0,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accentHover,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: text,
        side: const BorderSide(color: borderStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: textSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: borderStrong,
      thickness: 1,
      space: 1,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: textSecondary,
      textColor: text,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surfaceActive,
      selectedColor: accent.withValues(alpha: 0.2),
      labelStyle: const TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      side: BorderSide.none,
    ),
    tabBarTheme: const TabBarTheme(
      dividerColor: borderStrong,
      labelColor: accentHover,
      unselectedLabelColor: textMuted,
      indicatorColor: accent,
      labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderStrong),
      ),
      textStyle: const TextStyle(color: text, fontSize: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
      contentTextStyle: const TextStyle(color: text, fontSize: 13),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: bgElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
    ),
    fontFamily: 'Inter',
  );
}
