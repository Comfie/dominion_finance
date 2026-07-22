import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Semantic colors [ColorScheme] doesn't provide a slot for.
///
/// `successText`/`infoText` are darkened variants of [success]/[info] for use
/// as *text* on light surfaces — the vivid brand tokens (`#00D09E`, `#3299FF`)
/// fail WCAG AA as text on white (~2.0:1 / ~2.9:1). The vivid tokens stay
/// reserved for icon chips, fills, and badges, which have looser contrast
/// requirements than body text.
class AppColors extends ThemeExtension<AppColors> {
  final Color success;
  final Color successText;
  final Color warning;
  final Color info;
  final Color infoText;
  final Color surfaceElevated;

  const AppColors({
    required this.success,
    required this.successText,
    required this.warning,
    required this.info,
    required this.infoText,
    required this.surfaceElevated,
  });

  // `success` is deliberately a different hue from brand `primary`
  // (#00D09E, teal-leaning emerald) — a true green (#22C55E) — so income/
  // gains read as a distinct semantic signal rather than looking identical
  // to ordinary brand chrome (nav, buttons, hero background).
  static const light = AppColors(
    success: Color(0xFF22C55E),
    successText: Color(0xFF15803D),
    warning: Color(0xFFF5A623),
    info: Color(0xFF3299FF),
    infoText: Color(0xFF1A6FCB),
    surfaceElevated: Color(0xFFDFF7E2),
  );

  static const dark = AppColors(
    success: Color(0xFF22C55E),
    successText: Color(0xFF22C55E),
    warning: Color(0xFFF5A623),
    info: Color(0xFF4FA8FF),
    infoText: Color(0xFF4FA8FF),
    surfaceElevated: Color(0xFF16453F),
  );

  @override
  AppColors copyWith({
    Color? success,
    Color? successText,
    Color? warning,
    Color? info,
    Color? infoText,
    Color? surfaceElevated,
  }) {
    return AppColors(
      success: success ?? this.success,
      successText: successText ?? this.successText,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      infoText: infoText ?? this.infoText,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      success: Color.lerp(success, other.success, t)!,
      successText: Color.lerp(successText, other.successText, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoText: Color.lerp(infoText, other.infoText, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
    );
  }
}

class AppTheme {
  // --- Legacy static consts -------------------------------------------
  // Deprecated: these back every screen this UI redesign hasn't reached yet
  // (see docs/superpowers/specs/2026-07-21-modern-ui-redesign-phase1-design.md).
  // Values are intentionally left untouched so those screens keep rendering
  // exactly as before. New/redesigned code should read
  // `Theme.of(context).colorScheme` or `Theme.of(context).extension<AppColors>()`
  // instead. Delete this block once every screen has migrated.
  @Deprecated('Use Theme.of(context).colorScheme.primary instead')
  static const Color primary = Color(0xFF8B5CF6);
  @Deprecated('Use Theme.of(context).colorScheme instead')
  static const Color primaryLight = Color(0xFFA78BFA);
  @Deprecated('Use Theme.of(context).colorScheme instead')
  static const Color primaryDark = Color(0xFF7C3AED);

  @Deprecated('Use Theme.of(context).colorScheme.surface instead')
  static const Color background = Color(0xFF0F172A);
  @Deprecated('Use Theme.of(context).colorScheme.surface instead')
  static const Color surface = Color(0xFF1E293B);
  @Deprecated('Use Theme.of(context).colorScheme instead')
  static const Color surfaceLight = Color(0xFF334155);

  @Deprecated('Use Theme.of(context).colorScheme.onSurface instead')
  static const Color textPrimary = Color(0xFFF8FAFC);
  @Deprecated('Use Theme.of(context).textTheme.bodyMedium?.color instead')
  static const Color textSecondary = Color(0xFF94A3B8);
  @Deprecated('Use Theme.of(context).textTheme.bodySmall?.color instead')
  static const Color textMuted = Color(0xFF64748B);

  @Deprecated('Use Theme.of(context).extension<AppColors>()!.success instead')
  static const Color success = Color(0xFF10B981);
  @Deprecated('Use Theme.of(context).extension<AppColors>()!.warning instead')
  static const Color warning = Color(0xFFF59E0B);
  @Deprecated('Use Theme.of(context).colorScheme.error instead')
  static const Color error = Color(0xFFEF4444);
  @Deprecated('Use Theme.of(context).extension<AppColors>()!.info instead')
  static const Color info = Color(0xFF3B82F6);

  @Deprecated('Use AppTheme.dark instead')
  static ThemeData get darkTheme => dark;

  // --- New token-driven theme -------------------------------------------

  static const _ink = Color(0xFF052224);

  static ThemeData get light => _build(
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF00D09E),
          onPrimary: _ink,
          secondary: Color(0xFF3299FF),
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: _ink,
          error: Color(0xFFEF4444),
          onError: Colors.white,
        ),
        scaffoldBackground: const Color(0xFFF1FFF3),
        textColor: _ink,
        textColorSecondary: const Color(0xFF4B6B67),
        textColorMuted: const Color(0xFF7C9A96),
        appColors: AppColors.light,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00D09E),
          onPrimary: _ink,
          secondary: Color(0xFF4FA8FF),
          onSecondary: Colors.white,
          surface: Color(0xFF123A37),
          onSurface: Color(0xFFEAFBF3),
          error: Color(0xFFF87171),
          onError: _ink,
        ),
        scaffoldBackground: const Color(0xFF04191A),
        textColor: const Color(0xFFEAFBF3),
        textColorSecondary: const Color(0xFF8FB3AC),
        textColorMuted: const Color(0xFF5E827D),
        appColors: AppColors.dark,
      );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
    required Color textColor,
    required Color textColorSecondary,
    required Color textColorMuted,
    required AppColors appColors,
  }) {
    final isDark = brightness == Brightness.dark;
    const pill = StadiumBorder();

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      extensions: [appColors],
      scaffoldBackgroundColor: scaffoldBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: textColor,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                systemNavigationBarColor: appColors.surfaceElevated,
                systemNavigationBarIconBrightness: Brightness.light,
              )
            : SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                systemNavigationBarColor: appColors.surfaceElevated,
                systemNavigationBarIconBrightness: Brightness.dark,
              ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? colorScheme.surface : appColors.surfaceElevated,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(999)),
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(999)),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(999)),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(999)),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        hintStyle: TextStyle(color: textColorMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: pill,
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: appColors.surfaceElevated,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: textColorMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? colorScheme.surface : appColors.surfaceElevated,
        thickness: 1,
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: textColor,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: textColorSecondary,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: textColorMuted,
        ),
      ),
    );
  }
}
