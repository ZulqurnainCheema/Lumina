import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ===============================
/// COLORS
/// ===============================

class LuminaColors {
  // Warm near-black, with each surface a step lighter. Depth comes from the
  // surface step, not from borders.
  static const background = Color(0xFF11100E);
  static const surface = Color(0xFF1C1A17);
  static const surfaceRaised = Color(0xFF282521);
  static const sheet = Color(0xFF2E2B27);

  // Every colour has one meaning.
  static const accent = Color(0xFF8FD9A8); // the main action, progress
  static const onAccent = Color(0xFF0E2A18);
  static const streak = Color(0xFFF2B45A); // streak and fire
  static const recall = Color(0xFFB7A6F5); // your own notes and questions
  static const missed = Color(0xFFF28B82);

  static const textPrimary = Color(0xFFF3EFE8);
  static const textSecondary = Color(0xFFABA59B);
  static const textTertiary = Color(0xFF7D776E);

  static const neutral = textSecondary;
  static const track = Color(0xFF2B2824);
  static const field = surfaceRaised;
  static const fieldFocus = sheet;

  static const white = textPrimary;

  static const borderSubtle = Color(0x14FFFFFF);
  static const borderSoft = Color(0x1FFFFFFF);
  static const shadow = Color(0x66000000);

  // A colour at low strength over a card, for tinted tiles.
  static Color tint(Color color) =>
      Color.alphaBlend(color.withAlpha(34), surface);
}

/// ===============================
/// THEME
/// ===============================

class LuminaTheme {
  static const radiusCard = 28.0;
  static const radiusInput = 18.0;
  static const radiusThumbnail = 10.0;

  static const buttonHeight = 56.0;

  // Editorial serif for titles and big numbers, grotesk for everything else.
  static TextStyle display({
    required double size,
    double height = 1.1,
    FontWeight weight = FontWeight.w600,
    Color color = LuminaColors.textPrimary,
  }) {
    return GoogleFonts.fraunces(
      fontSize: size,
      height: height,
      fontWeight: weight,
      letterSpacing: size * -0.02,
      color: color,
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);

    final textTheme = GoogleFonts.manropeTextTheme(base.textTheme).copyWith(
      // The one hero number on a screen.
      displayMedium: display(size: 72, height: 1),
      // The screen title.
      displayLarge: display(size: 36),
      // Stat numerals and sheet titles.
      headlineLarge: display(size: 30, height: 1.15),
      headlineMedium: display(size: 24, height: 1.2),
      titleLarge: GoogleFonts.manrope(
        fontWeight: FontWeight.w700,
        fontSize: 20,
        height: 1.3,
        color: LuminaColors.textPrimary,
      ),
      titleMedium: GoogleFonts.manrope(
        fontWeight: FontWeight.w700,
        fontSize: 16,
        height: 1.3,
        color: LuminaColors.textPrimary,
      ),
      bodyLarge: GoogleFonts.manrope(
        fontWeight: FontWeight.w500,
        fontSize: 16,
        height: 1.5,
        color: LuminaColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.manrope(
        fontWeight: FontWeight.w500,
        fontSize: 15,
        height: 1.5,
        color: LuminaColors.textPrimary,
      ),
      bodySmall: GoogleFonts.manrope(
        fontWeight: FontWeight.w500,
        fontSize: 14,
        height: 1.4,
        color: LuminaColors.textSecondary,
      ),
      labelLarge: GoogleFonts.manrope(
        fontWeight: FontWeight.w700,
        fontSize: 15,
        color: LuminaColors.textPrimary,
      ),
      // Small capitals above a section.
      labelMedium: GoogleFonts.manrope(
        fontWeight: FontWeight.w700,
        fontSize: 12,
        letterSpacing: 0.8,
        color: LuminaColors.textSecondary,
      ),
    );

    final colorScheme = const ColorScheme.dark(
      brightness: Brightness.dark,
      primary: LuminaColors.accent,
      onPrimary: LuminaColors.onAccent,
      secondary: LuminaColors.accent,
      surface: LuminaColors.surface,
      onSurface: LuminaColors.textPrimary,
      onSurfaceVariant: LuminaColors.textSecondary,
      outline: LuminaColors.borderSoft,
      error: LuminaColors.missed,
    );

    final TextStyle buttonText = GoogleFonts.manrope(
      fontWeight: FontWeight.w700,
      fontSize: 16,
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
        titleTextStyle: textTheme.titleLarge,
      ),

      /// ===============================
      /// CARDS
      /// ===============================
      cardTheme: CardThemeData(
        color: LuminaColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
      ),

      /// ===============================
      /// BUTTONS
      /// ===============================
      // Filled pill: the one main action on a screen.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: LuminaColors.accent,
          foregroundColor: LuminaColors.onAccent,
          minimumSize: const Size.fromHeight(buttonHeight),
          elevation: 0,
          textStyle: buttonText,
          shape: const StadiumBorder(),
        ),
      ),

      // Tonal pill: secondary actions.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: LuminaColors.surfaceRaised,
          foregroundColor: LuminaColors.textPrimary,
          minimumSize: const Size.fromHeight(buttonHeight),
          side: BorderSide.none,
          textStyle: buttonText.copyWith(fontSize: 15),
          shape: const StadiumBorder(),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: LuminaColors.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          textStyle: buttonText.copyWith(fontSize: 15),
          shape: const StadiumBorder(),
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
        hintStyle: GoogleFonts.manrope(
          color: LuminaColors.textTertiary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        labelStyle: GoogleFonts.manrope(
          color: LuminaColors.textSecondary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: GoogleFonts.manrope(
          color: LuminaColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        helperStyle: GoogleFonts.manrope(
          color: LuminaColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        errorStyle: GoogleFonts.manrope(
          color: LuminaColors.missed,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        contentPadding: const EdgeInsets.fromLTRB(18, 14, 18, 14),

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
          borderSide: const BorderSide(color: LuminaColors.missed, width: 2),
        ),

        focusedErrorBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: LuminaColors.missed, width: 2),
        ),
      ),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: LuminaColors.accent,
        selectionColor: LuminaColors.accent.withAlpha(70),
        selectionHandleColor: LuminaColors.accent,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: LuminaColors.textPrimary,
        unselectedLabelColor: LuminaColors.textSecondary,
        indicatorColor: LuminaColors.accent,
        dividerColor: Colors.transparent,
        labelStyle: GoogleFonts.manrope(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.manrope(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),

      /// ===============================
      /// SHEETS AND DIALOGS
      /// ===============================
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: LuminaColors.sheet,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: LuminaColors.sheet,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.headlineMedium,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: LuminaColors.textSecondary,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: LuminaColors.sheet,
        contentTextStyle: textTheme.bodyMedium,
        behavior: SnackBarBehavior.floating,
        shape: const StadiumBorder(),
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
          textStyle: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: const StadiumBorder(),
        side: BorderSide.none,
        labelStyle: GoogleFonts.manrope(
          color: LuminaColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: GoogleFonts.manrope(
          color: LuminaColors.background,
          fontWeight: FontWeight.w700,
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
  );

  static BoxDecoration tinted(Color color) => BoxDecoration(
    color: LuminaColors.tint(color),
    borderRadius: BorderRadius.circular(LuminaTheme.radiusCard),
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
        minHeight: 8,
        backgroundColor: LuminaColors.track,
        valueColor: const AlwaysStoppedAnimation(LuminaColors.accent),
      ),
    );
  }
}
