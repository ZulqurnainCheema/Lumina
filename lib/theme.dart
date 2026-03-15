import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ===============================
/// COLORS
/// ===============================

class LuminaColors {
  static const background = Color(0xFF0A1A0F);
  static const surface = Color(0xFF142A1C);
  static const accent = Color(0xFF17CF54);
  static const neutral = Color(0xFFA0A0A0);
  static const track = Color(0xFF0D2517);

  static const white = Colors.white;

  static const borderSubtle = Color(0x14FFFFFF);
  static const borderSoft = Color(0x1AFFFFFF);
  static const shadow = Color(0x66000000);
}

/// ===============================
/// THEME
/// ===============================

class LuminaTheme {
  static const radiusCard = 12.0;
  static const radiusInput = 8.0;
  static const radiusThumbnail = 8.0;

  static const buttonHeight = 54.0;

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.inter(
        fontWeight: FontWeight.w700,
        fontSize: 40,
        color: LuminaColors.white,
      ),
      headlineMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w700,
        fontSize: 24,
        color: LuminaColors.white,
      ),
      titleLarge: GoogleFonts.inter(
        fontWeight: FontWeight.w700,
        fontSize: 20,
        color: LuminaColors.white,
      ),
      titleMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w500,
        fontSize: 16,
        color: LuminaColors.white,
      ),
      bodyLarge: GoogleFonts.inter(
        fontWeight: FontWeight.w400,
        fontSize: 18,
        color: LuminaColors.white,
      ),
      bodyMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w400,
        fontSize: 16,
        color: LuminaColors.white,
      ),
      bodySmall: GoogleFonts.inter(
        fontWeight: FontWeight.w400,
        fontSize: 14,
        color: LuminaColors.neutral,
      ),
      labelLarge: GoogleFonts.inter(
        fontWeight: FontWeight.w700,
        fontSize: 16,
        color: LuminaColors.background,
      ),
      labelMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w500,
        fontSize: 14,
        color: LuminaColors.accent,
      ),
    );

    final colorScheme = const ColorScheme.dark(
      brightness: Brightness.dark,
      primary: LuminaColors.accent,
      onPrimary: LuminaColors.background,
      secondary: LuminaColors.accent,
      surface: LuminaColors.surface,
      onSurface: LuminaColors.white,
      error: Colors.redAccent,
    );

    return base.copyWith(
      textTheme: textTheme,

      scaffoldBackgroundColor: LuminaColors.background,

      colorScheme: colorScheme,

      /// ===============================
      /// APP BAR
      /// ===============================
      appBarTheme: AppBarTheme(
        backgroundColor: LuminaColors.background,
        elevation: 0,
        titleTextStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w700,
          fontSize: 22,
          color: LuminaColors.white,
        ),
      ),

      /// ===============================
      /// CARDS
      /// ===============================
      cardTheme: CardThemeData(
        color: LuminaColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(color: LuminaColors.borderSubtle),
        ),
      ),

      /// ===============================
      /// BUTTONS
      /// ===============================
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: LuminaColors.accent,
          foregroundColor: LuminaColors.background,
          minimumSize: const Size.fromHeight(buttonHeight),
          elevation: 0,
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusCard),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: LuminaColors.accent,
          backgroundColor: LuminaColors.shadow,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),

      /// ===============================
      /// INPUTS
      /// ===============================
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: LuminaColors.background,
        hintStyle: GoogleFonts.inter(color: LuminaColors.neutral),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: LuminaColors.surface),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: LuminaColors.surface),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: LuminaColors.accent, width: 1.2),
        ),
      ),

      /// ===============================
      /// NAVIGATION BAR
      /// ===============================
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: LuminaColors.surface,
        indicatorColor: LuminaColors.track,
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: LuminaColors.accent,
            );
          }
          return GoogleFonts.inter(fontSize: 12, color: LuminaColors.neutral);
        }),
      ),

      /// ===============================
      /// PROGRESS BAR
      /// ===============================
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: LuminaColors.accent,
        linearTrackColor: LuminaColors.track,
      ),

      /// ===============================
      /// CHIPS
      /// ===============================
      chipTheme: ChipThemeData(
        backgroundColor: LuminaColors.track,
        selectedColor: LuminaColors.accent,
        disabledColor: LuminaColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: const BorderSide(color: LuminaColors.borderSubtle),
        ),
        labelStyle: GoogleFonts.inter(
          color: LuminaColors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// ===============================
/// DECORATIONS
/// ===============================

class LuminaDecorations {
  static BoxDecoration card = BoxDecoration(
    color: LuminaColors.surface,
    borderRadius: BorderRadius.circular(LuminaTheme.radiusCard),
    border: Border.all(color: LuminaColors.borderSubtle),
    boxShadow: const [
      BoxShadow(
        color: LuminaColors.shadow,
        blurRadius: 25,
        offset: Offset(0, 10),
        spreadRadius: -5,
      ),
    ],
  );

  static BoxDecoration thumbnail = BoxDecoration(
    color: LuminaColors.background,
    borderRadius: BorderRadius.circular(LuminaTheme.radiusThumbnail),
    border: Border.all(color: LuminaColors.borderSoft),
  );
}

/// ===============================
/// WIDGET HELPERS
/// ===============================

class LuminaWidgets {
  static Widget progressBar(double value) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: 6,
        backgroundColor: LuminaColors.track,
        valueColor: const AlwaysStoppedAnimation(LuminaColors.accent),
      ),
    );
  }
}
