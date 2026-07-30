import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Roots design tokens — Material 3 + FarmSmart/Imali styling.
class RootsColors {
  static const navy = Color(0xFF0E1F2E);
  static const navyDeep = Color(0xFF001B3D);
  static const sidebarAccent = Color(0xFF1D3B4F);
  static const teal = Color(0xFF00C897);
  static const green = Color(0xFF2D9B5E);
  static const greenSoft = Color(0xFFEEF6F0);
  static const greenPale = Color(0xFFE6F7EE);
  static const greenDeep = Color(0xFF1F7B4A);
  static const leaf = Color(0xFF6FCF97);
  static const bg = Color(0xFFF2F6FC);
  static const panel = Color(0xFFFFFFFF);
  static const text = Color(0xFF1A2A3A);
  static const textStrong = Color(0xFF0E1F2E);
  static const muted = Color(0xFF5E7A8F);
  static const line = Color(0xFFE9EEF3);
  static const orange = Color(0xFFD68A3C);
  static const red = Color(0xFFC73B3B);
  static const gold = Color(0xFFF5B342);
  static const blue = Color(0xFF2A7AB0);
  static const mintCard = Color(0xFFE8F8F2);
  static const greyCard = Color(0xFFEEF1F6);
  static const peachCard = Color(0xFFFFF3E8);
  static const lavenderCard = Color(0xFFF0EEF8);

  static const heroGradient = LinearGradient(
    colors: [Color(0xFF001B3D), Color(0xFF0A6B5C), Color(0xFF00C897)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const tealCardGradient = LinearGradient(
    colors: [Color(0xFF0A8F7A), Color(0xFF00C897)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class RootsTheme {
  static ThemeData light() {
    final base = ColorScheme.fromSeed(
      seedColor: RootsColors.green,
      brightness: Brightness.light,
      primary: RootsColors.greenDeep,
      secondary: RootsColors.teal,
      surface: RootsColors.panel,
      error: RootsColors.red,
    );

    final textTheme = GoogleFonts.plusJakartaSansTextTheme().apply(
      bodyColor: RootsColors.text,
      displayColor: RootsColors.textStrong,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      scaffoldBackgroundColor: RootsColors.bg,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: RootsColors.bg,
        foregroundColor: RootsColors.textStrong,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: RootsColors.textStrong,
        ),
      ),
      cardTheme: CardThemeData(
        color: RootsColors.panel,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: RootsColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: RootsColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: RootsColors.teal, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: RootsColors.greenDeep,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: RootsColors.greenPale,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  static ThemeData dark() {
    final base = ColorScheme.fromSeed(
      seedColor: RootsColors.teal,
      brightness: Brightness.dark,
      primary: RootsColors.teal,
      secondary: RootsColors.leaf,
      surface: const Color(0xFF132433),
      error: RootsColors.red,
    );

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      scaffoldBackgroundColor: const Color(0xFF0A1520),
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: const Color(0xFF132433),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF0A1520),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}
