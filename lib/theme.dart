import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for the VoidLex "strict / minimalist / futuristic" palette.
///
/// Two parallel sets — light and dark — accessed via [VoidTokens.of] from a
/// [BuildContext]. The semantic names mirror the design canvas (`bg`,
/// `surface`, `fg1..fg3`, `accent`, etc.) so widgets can read them without
/// branching on brightness.
class VoidTokens {
  const VoidTokens({
    required this.bg,
    required this.bgRaised,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.borderStrong,
    required this.fg1,
    required this.fg2,
    required this.fg3,
    required this.accent,
    required this.accentDim,
    required this.accentMid,
    required this.error,
    required this.ok,
    required this.warn,
    required this.haloOn,
    required this.brightness,
  });

  final Color bg;
  final Color bgRaised;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color borderStrong;
  final Color fg1;
  final Color fg2;
  final Color fg3;
  final Color accent;
  final Color accentDim;
  final Color accentMid;
  final Color error;
  final Color ok;
  final Color warn;
  final Color haloOn;
  final Brightness brightness;

  bool get isDark => brightness == Brightness.dark;

  static const VoidTokens light = VoidTokens(
    bg: Color(0xFFF4F5F6),
    bgRaised: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFECEEF1),
    border: Color(0x120A0B0C),
    borderStrong: Color(0x240A0B0C),
    fg1: Color(0xFF0A0B0C),
    fg2: Color(0xFF5A5C61),
    fg3: Color(0xFFA4A6AB),
    accent: Color(0xFF0A0B0C),
    accentDim: Color(0xFFC2C5CB),
    accentMid: Color(0xFF3A3D44),
    error: Color(0xFFC62A2A),
    ok: Color(0xFF1A6E47),
    warn: Color(0xFFB67A1F),
    haloOn: Color(0x2E0A0B0C),
    brightness: Brightness.light,
  );

  static const VoidTokens dark = VoidTokens(
    bg: Color(0xFF08090B),
    bgRaised: Color(0xFF0E1013),
    surface: Color(0xFF13161B),
    surfaceAlt: Color(0xFF1A1E25),
    border: Color(0x0FFFFFFF),
    borderStrong: Color(0x1FFFFFFF),
    fg1: Color(0xFFE9EAEB),
    fg2: Color(0xFF9A9DA3),
    fg3: Color(0xFF5A5C61),
    accent: Color(0xFFC8E6FF),
    accentDim: Color(0xFF3A4A5C),
    accentMid: Color(0xFF8BB7D9),
    error: Color(0xFFFF6B6B),
    ok: Color(0xFFA6E2C2),
    warn: Color(0xFFC8A14A),
    haloOn: Color(0x4DC8E6FF),
    brightness: Brightness.dark,
  );

  static VoidTokens of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }
}

/// Geist + Geist Mono via google_fonts. Centralised so widgets get consistent
/// metrics without each one configuring the package.
class VoidType {
  const VoidType._();

  static const String russianSansFamily = 'Manrope';
  static const List<String> _cyrillicFallback = <String>[russianSansFamily];

  /// When true, [sans] and [mono] return [russianSansFamily] as the primary
  /// family.
  /// Driven by `main.dart` from the effective locale before each rebuild.
  /// Geist ships full Cyrillic, so a passive `fontFamilyFallback` would
  /// never trigger — forcing the primary family is the only way to switch.
  static bool useRussianPrimary = false;

  static void useLocale(Locale locale) {
    useRussianPrimary = locale.languageCode == 'ru';
  }

  static TextStyle _russianPrimary({
    required double fontSize,
    required FontWeight fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    List<FontFeature>? fontFeatures,
  }) {
    return TextStyle(
      fontFamily: russianSansFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      fontFeatures: fontFeatures,
    );
  }

  static TextStyle sans({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
    double? height,
    List<FontFeature>? fontFeatures,
  }) {
    if (useRussianPrimary) {
      return _russianPrimary(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        fontFeatures: fontFeatures,
      );
    }
    return GoogleFonts.geist(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      fontFeatures: fontFeatures,
    ).copyWith(fontFamilyFallback: _cyrillicFallback);
  }

  static TextStyle mono({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
    double? letterSpacing,
    double? height,
    List<FontFeature>? fontFeatures,
  }) {
    if (useRussianPrimary) {
      return _russianPrimary(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        fontFeatures: fontFeatures,
      );
    }
    return GoogleFonts.geistMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      fontFeatures: fontFeatures,
    ).copyWith(fontFamilyFallback: _cyrillicFallback);
  }
}

class AppTheme {
  static ThemeData get lightTheme => _build(VoidTokens.light);
  static ThemeData get darkTheme => _build(VoidTokens.dark);

  static ThemeData _build(VoidTokens t) {
    final colorScheme = ColorScheme(
      brightness: t.brightness,
      primary: t.accent,
      onPrimary: t.bg,
      secondary: t.ok,
      onSecondary: t.bg,
      error: t.error,
      onError: t.bg,
      surface: t.surface,
      onSurface: t.fg1,
      surfaceContainerHighest: t.surfaceAlt,
      outline: t.borderStrong,
      outlineVariant: t.border,
    );

    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: t.border),
    );

    final base = ThemeData(
      brightness: t.brightness,
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: t.bg,
      canvasColor: t.bg,
      cardColor: t.surface,
      dividerColor: t.border,
      disabledColor: t.fg3,
      primaryColor: t.accent,
      iconTheme: IconThemeData(color: t.fg2),
      appBarTheme: AppBarTheme(
        backgroundColor: t.bg,
        foregroundColor: t.fg1,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: t.fg2),
        titleTextStyle: VoidType.mono(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.8,
          color: t.fg1,
        ),
      ),
      cardTheme: CardThemeData(
        color: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: t.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: t.border, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.surfaceAlt,
        contentTextStyle: VoidType.sans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: t.fg1,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: t.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: t.border),
        ),
        textStyle: VoidType.sans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: t.fg1,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.bgRaised,
        modalBackgroundColor: t.bgRaised,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: t.borderStrong,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.bgRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: t.border),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: VoidType.sans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: t.fg1,
        ),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(t.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: t.border),
            ),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surface,
        labelStyle: VoidType.mono(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.6,
          color: t.fg2,
        ),
        floatingLabelStyle: VoidType.mono(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.6,
          color: t.fg1,
        ),
        hintStyle: VoidType.sans(fontSize: 14, color: t.fg3),
        errorStyle: VoidType.sans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: t.error,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: outline,
        enabledBorder: outline,
        focusedBorder: outline.copyWith(
          borderSide: BorderSide(color: t.fg1, width: 1.5),
        ),
        errorBorder: outline.copyWith(borderSide: BorderSide(color: t.error)),
        focusedErrorBorder: outline.copyWith(
          borderSide: BorderSide(color: t.error, width: 1.5),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
          side: WidgetStatePropertyAll(BorderSide(color: t.border)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return t.bg;
            return t.fg2;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return t.fg1;
            return t.surface;
          }),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return t.fg1;
          return t.surfaceAlt;
        }),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return t.bg;
          return t.fg3;
        }),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: t.fg1,
        selectionColor: t.fg1.withValues(alpha: 0.18),
        selectionHandleColor: t.fg1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: t.fg2,
        textColor: t.fg1,
        subtitleTextStyle: VoidType.sans(
          fontSize: 12,
          color: t.fg2,
          fontWeight: FontWeight.w500,
        ),
        titleTextStyle: VoidType.sans(
          fontSize: 14,
          color: t.fg1,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    final textTheme = base.textTheme.copyWith(
      displayLarge: VoidType.sans(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: t.fg1,
      ),
      displayMedium: VoidType.sans(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: t.fg1,
      ),
      titleLarge: VoidType.sans(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: t.fg1,
      ),
      titleMedium: VoidType.sans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: t.fg1,
      ),
      titleSmall: VoidType.sans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: t.fg1,
      ),
      bodyLarge: VoidType.sans(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: t.fg1,
      ),
      bodyMedium: VoidType.sans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: t.fg2,
        height: 1.4,
      ),
      bodySmall: VoidType.sans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: t.fg2,
        height: 1.35,
      ),
      labelSmall: VoidType.mono(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
        color: t.fg2,
      ),
      labelMedium: VoidType.mono(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: t.fg2,
      ),
    );

    return base.copyWith(textTheme: textTheme);
  }
}
