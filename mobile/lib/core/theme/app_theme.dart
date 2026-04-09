import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppTheme {
  // ── Border Radius ─────────────────────────────────────────────────────
  static const double radiusCard   = 24.0; // rounded-3xl
  static const double radiusCardMd = 16.0; // rounded-2xl
  static const double radiusBtn    = 16.0; // rounded-2xl
  static const double radiusBtnSm  = 12.0; // rounded-xl
  static const double radiusInput  = 12.0; // rounded-xl
  static const double radiusIconSm = 12.0; // rounded-xl
  static const double radiusPill   = 9999.0; // rounded-full

  // ── Spacing ───────────────────────────────────────────────────────────
  static const double screenPadding = 20.0;
  static const double cardPadding   = 20.0;
  static const double gap           = 12.0;
  static const double btnHeightLg   = 54.0;
  static const double btnHeightSm   = 38.0;

  // ── Text Styles ───────────────────────────────────────────────────────
  static TextStyle pageTitle(Color color) =>
      GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w700, color: color);

  static TextStyle sectionHeading(Color color) =>
      GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600, color: color);

  static TextStyle cardTitle(Color color) =>
      GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: color);

  static TextStyle body(Color color) =>
      GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w400, color: color);

  static TextStyle caption(Color color) =>
      GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w400, color: color);

  static TextStyle heroNumber(Color color) =>
      GoogleFonts.nunito(fontSize: 56, fontWeight: FontWeight.w800, color: color);

  static TextStyle clockText(Color color) =>
      GoogleFonts.nunito(fontSize: 64, fontWeight: FontWeight.w800, color: color);

  // ── Decoration Helpers ────────────────────────────────────────────────

  /// Glass card dùng trên nền gradient (bg-white/15)
  static BoxDecoration glassCard({double radius = radiusCard}) => BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withOpacity(0.20)),
      );

  /// Glass card mờ hơn (bg-white/10)
  static BoxDecoration glassCardSubtle({double radius = radiusCard}) => BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      );

  /// Gradient background
  static BoxDecoration gradientBg(List<Color> colors) => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      );

  // ── MaterialApp ThemeData ─────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.indigo600,
        secondary: AppColors.orange400,
        error: AppColors.danger,
        surface: AppColors.surface,
      ),
      textTheme: GoogleFonts.nunitoTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.indigo600,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.indigo600,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(btnHeightLg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusBtn),
          ),
          elevation: 4,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: AppColors.slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: AppColors.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: AppColors.indigo500, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
      ),
    );
  }
}
