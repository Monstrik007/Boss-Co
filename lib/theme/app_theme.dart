import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const gold = Color(0xFFFFD700);
  static const bossPurple = Color(0xFF6C3CE9);
  static const slaveTeal = Color(0xFF00C9A7);
  static const darkBg = Color(0xFF0F0F1A);
  static const cardBg = Color(0xFF1A1A2E);
  static const accentPink = Color(0xFFFF6B9D);
  static const accentOrange = Color(0xFFFF9F43);

  static ThemeData get theme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      colorScheme: ColorScheme.dark(
        primary: bossPurple,
        secondary: slaveTeal,
        tertiary: accentPink,
        surface: cardBg,
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.nunitoTextTheme(base.textTheme).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.nunito(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  static BoxDecoration gradientBackground({List<Color>? colors}) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors ??
            [
              darkBg,
              const Color(0xFF1a1035),
              const Color(0xFF0d2137),
            ],
      ),
    );
  }

  static BoxDecoration glassCard({Color? borderColor}) {
    return BoxDecoration(
      color: cardBg.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: (borderColor ?? Colors.white).withValues(alpha: 0.12),
      ),
      boxShadow: [
        BoxShadow(
          color: (borderColor ?? bossPurple).withValues(alpha: 0.15),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}
