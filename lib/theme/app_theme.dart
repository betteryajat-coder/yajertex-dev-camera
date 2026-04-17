import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Global design tokens + ThemeData for YajerTex Dev Camera.
/// Palette: premium light blue + white, with soft shadows and rounded shapes.
class AppTheme {
  AppTheme._();

  // Brand palette
  static const Color primary = Color(0xFF3DA9FC);      // vivid sky blue
  static const Color primaryDeep = Color(0xFF1E6EE8);  // depth accent
  static const Color primarySoft = Color(0xFFD8ECFF);  // washed blue
  static const Color surface = Color(0xFFFFFFFF);
  static const Color scaffold = Color(0xFFF4F9FF);     // off-white w/ blue tint
  static const Color ink = Color(0xFF0B2239);          // near-black text
  static const Color subInk = Color(0xFF637A94);       // muted text
  static const Color divider = Color(0xFFE3ECF6);
  static const Color danger = Color(0xFFE5484D);

  // Elevations / shapes
  static const double radiusSm = 10;
  static const double radiusMd = 16;
  static const double radiusLg = 24;
  static const double radiusXl = 32;

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: primaryDeep.withOpacity(0.08),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];

  static List<BoxShadow> get liftShadow => [
        BoxShadow(
          color: primaryDeep.withOpacity(0.14),
          blurRadius: 28,
          spreadRadius: -4,
          offset: const Offset(0, 14),
        ),
      ];

  static LinearGradient get brandGradient => const LinearGradient(
        colors: [Color(0xFF7DC5FF), primary, primaryDeep],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get softBackground => const LinearGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFEAF3FF)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: ink,
      displayColor: ink,
    );

    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        secondary: primaryDeep,
        onSecondary: Colors.white,
        surface: surface,
        onSurface: ink,
        error: danger,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: scaffold,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: ink,
          fontWeight: FontWeight.w700,
          fontSize: 20,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: ink),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primary, width: 1.6),
        ),
        hintStyle: GoogleFonts.inter(color: subInk, fontSize: 15),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: primary,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 28),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            letterSpacing: 0.1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
          ),
          elevation: 0,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: divider),
        ),
      ),
      dividerTheme: const DividerThemeData(color: divider, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
    );
  }
}
