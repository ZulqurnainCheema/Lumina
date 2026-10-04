import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ===============================
/// COLORS
/// ===============================

class LuminaColors {
  static const background = Color(0xFF0B0D0C);
  static const surface = Color(0xFF151917);
  static const surfaceRaised = Color(0xFF1D2320);

  // Accent is for the one main action on a screen and for live progress.
  static const accent = Color(0xFF2BD46B);
  // Streak colour is for the flame and streak numbers only.
  static const streak = Color(0xFFFFB347);

  static const textPrimary = Color(0xFFF2F5F3);
  static const textSecondary = Color(0xFFA3ADA7);
  static const textTertiary = Color(0xFF6B756F);

  static const neutral = textSecondary;
  static const track = Color(0xFF232A26);
  static const field = surfaceRaised;
  static const fieldFocus = Color(0xFF242C28);

  static const white = textPrimary;

  static const borderSubtle = Color(0x14FFFFFF);
  static const borderSoft = Color(0x1FFFFFFF);
  static const shadow = Color(0x66000000);
}

/// ===============================
/// THEME
/// ===============================

class LuminaTheme {
  static const radiusCard = 16.0;
  static const radiusInput = 14.0;
  static const radiusThumbnail = 8.0;

  static const buttonHeight = 54.0;

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);

    // One job per style: display is the screen title, headline the key number
    // on a card, title a section or card heading, body the reading text, and
    // label the small overline above a section.
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.inter(
        fontWeight: FontWeight.w700,
        fontSize: 30,
        height: 1.15,
        letterSpacing: -0.5,
        color: LuminaColors.textPrimary,
      ),
      headlineLarge: GoogleFonts.inter(
        fontWeight: FontWeight.w700,
        fontSize: 26,
        height: 1.2,
        letterSpacing: -0.3,
        color: LuminaColors.textPrimary,
      ),
      headlineMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w700,
        fontSize: 22,
        height: 1.2,
        color: LuminaColors.textPrimary,
      ),
      titleLarge: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        fontSize: 18,
        height: 1.3,
        color: LuminaColors.textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        height: 1.3,
        color: LuminaColors.textPrimary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontWeight: FontWeight.w400,
        fontSize: 16,
        height: 1.45,
        color: LuminaColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w400,
        fontSize: 15,
        height: 1.45,
        color: LuminaColors.textPrimary,
      ),
      bodySmall: GoogleFonts.inter(
        fontWeight: FontWeight.w400,
        fontSize: 13,
        height: 1.4,
        color: LuminaColors.textSecondary,
      ),
      labelLarge: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        fontSize: 15,
        color: LuminaColors.textPrimary,
      ),
      labelMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        fontSize: 12,
        letterSpacing: 1.1,
        color: LuminaColors.textTertiary,
      ),
    );

    final colorScheme = const ColorScheme.dark(
      brightness: Brightness.dark,
      primary: LuminaColors.accent,
      onPrimary: LuminaColors.background,
      secondary: LuminaColors.accent,
      surface: LuminaColors.surface,
      onSurface: LuminaColors.textPrimary,
      onSurfaceVariant: LuminaColors.textSecondary,
      outline: LuminaColors.borderSoft,
      error: Color(0xFFFF8A80),
    );

    return base.copyWith(
      textTheme: textTheme,

      // Workaround for Linux desktop mouse tracker assertion on route pop.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.linux: _NoAnimationPageTransitionsBuilder(),
          TargetPlatform.windows: _NoAnimationPageTransitionsBuilder(),
          TargetPlatform.macOS: _NoAnimationPageTransitionsBuilder(),
        },
      ),

      scaffoldBackgroundColor: LuminaColors.background,

      colorScheme: colorScheme,

      /// ===============================
      /// APP BAR
      /// ===============================
      appBarTheme: AppBarTheme(
        backgroundColor: LuminaColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: LuminaColors.textPrimary),
        titleTextStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: LuminaColors.textPrimary,
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
            borderRadius: BorderRadius.circular(radiusInput),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: LuminaColors.textPrimary,
          minimumSize: const Size.fromHeight(buttonHeight),
          side: const BorderSide(color: LuminaColors.borderSoft),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusInput),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: LuminaColors.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: LuminaColors.surfaceRaised,
        foregroundColor: LuminaColors.textPrimary,
        elevation: 0,
      ),

      /// ===============================
      /// INPUTS
      /// ===============================
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: LuminaColors.field,
        alignLabelWithHint: true,
        hintStyle: GoogleFonts.inter(
          color: LuminaColors.textTertiary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: GoogleFonts.inter(
          color: LuminaColors.textSecondary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        floatingLabelStyle: GoogleFonts.inter(
          color: LuminaColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        errorStyle: GoogleFonts.inter(
          color: const Color(0xFFFF8A80),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),

        // Filled fields: the label floats inside the box, not on its edge.
        border: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide.none,
        ),

        enabledBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide.none,
        ),

        focusedBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: LuminaColors.accent, width: 2),
        ),

        errorBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: Color(0x66FF8A80), width: 2),
        ),

        focusedErrorBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: Color(0xFFFF8A80), width: 2),
        ),
      ),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: LuminaColors.accent,
        selectionColor: LuminaColors.accent.withAlpha(70),
        selectionHandleColor: LuminaColors.accent,
      ),

      /// ===============================
      /// NAVIGATION BAR
      /// ===============================
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: LuminaColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: LuminaColors.accent.withAlpha(36),
        height: 68,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? LuminaColors.accent
                : LuminaColors.textSecondary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? LuminaColors.textPrimary
                : LuminaColors.textSecondary,
          );
        }),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: LuminaColors.textPrimary,
        unselectedLabelColor: LuminaColors.textSecondary,
        indicatorColor: LuminaColors.accent,
        dividerColor: LuminaColors.borderSubtle,
        labelStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),

      /// ===============================
      /// SHEETS AND DIALOGS
      /// ===============================
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: LuminaColors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: LuminaColors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: LuminaColors.textSecondary,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: LuminaColors.surfaceRaised,
        contentTextStyle: textTheme.bodyMedium,
        behavior: SnackBarBehavior.floating,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: LuminaColors.textSecondary,
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodySmall,
      ),

      dividerTheme: const DividerThemeData(
        color: LuminaColors.borderSubtle,
        thickness: 1,
      ),

      /// ===============================
      /// PROGRESS, SLIDERS, SEGMENTS
      /// ===============================
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: LuminaColors.accent,
        linearTrackColor: LuminaColors.track,
      ),

      sliderTheme: const SliderThemeData(
        activeTrackColor: LuminaColors.accent,
        inactiveTrackColor: LuminaColors.track,
        thumbColor: LuminaColors.accent,
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: LuminaColors.surfaceRaised,
          foregroundColor: LuminaColors.textSecondary,
          selectedBackgroundColor: LuminaColors.textPrimary,
          selectedForegroundColor: LuminaColors.background,
          side: BorderSide.none,
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),

      /// ===============================
      /// CHIPS
      /// ===============================
      chipTheme: ChipThemeData(
        backgroundColor: LuminaColors.surfaceRaised,
        selectedColor: LuminaColors.textPrimary,
        disabledColor: LuminaColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide.none,
        ),
        side: BorderSide.none,
        labelStyle: GoogleFonts.inter(
          color: LuminaColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: GoogleFonts.inter(
          color: LuminaColors.background,
          fontWeight: FontWeight.w600,
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
  );

  static BoxDecoration thumbnail = BoxDecoration(
    color: LuminaColors.surfaceRaised,
    borderRadius: BorderRadius.circular(LuminaTheme.radiusThumbnail),
  );
}

class _NoAnimationPageTransitionsBuilder extends PageTransitionsBuilder {
  const _NoAnimationPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
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
