import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Medical Colors - ألوان طبية أنيقة
  static const Color primaryBlue = Color(0xFF0284C7); // أزرق رئيسي
  static const Color lightBlue = Color(0xFFE0F2FE); // أزرق فاتح
  static const Color backgroundWhite = Color(0xFFF8FAFC); // خلفية بيضاء
  static const Color cardWhite = Color(0xFFFFFFFF); // أبيض البطاقات
  static const Color textDark = Color(0xFF1E293B); // نص داكن
  static const Color textGray = Color(0xFF64748B); // نص رمادي
  static const Color successGreen = Color(0xFF10B981); // أخضر نجاح
  static const Color errorRed = Color(0xFFEF4444); // أحمر خطأ
  static const Color dividerGray = Color(0xFFE2E8F0); // فاصل رمادي

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: GoogleFonts.cairo().fontFamily,
      
      // Primary color
      primaryColor: primaryBlue,
      scaffoldBackgroundColor: backgroundWhite,
      
      // Color scheme
      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        secondary: lightBlue,
        surface: cardWhite,
        error: errorRed,
      ),
      
      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor: cardWhite,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textDark,
        ),
        iconTheme: const IconThemeData(color: primaryBlue),
      ),
      
      // Card theme
      cardTheme: CardThemeData(
        color: cardWhite,
        elevation: 2,
        shadowColor: primaryBlue.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      
      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: dividerGray, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: dividerGray, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: errorRed, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: errorRed, width: 2),
        ),
        labelStyle: GoogleFonts.cairo(
          fontSize: 14,
          color: textGray,
        ),
        hintStyle: GoogleFonts.cairo(
          fontSize: 14,
          color: textGray,
        ),
      ),
      
      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: primaryBlue.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          textStyle: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Floating action button theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      
      // Text theme
      textTheme: TextTheme(
        displayLarge: GoogleFonts.cairo(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textDark,
        ),
        displayMedium: GoogleFonts.cairo(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textDark,
        ),
        displaySmall: GoogleFonts.cairo(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textDark,
        ),
        headlineMedium: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textDark,
        ),
        titleLarge: GoogleFonts.cairo(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textDark,
        ),
        titleMedium: GoogleFonts.cairo(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textDark,
        ),
        bodyLarge: GoogleFonts.cairo(
          fontSize: 16,
          color: textDark,
        ),
        bodyMedium: GoogleFonts.cairo(
          fontSize: 14,
          color: textGray,
        ),
        labelLarge: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
