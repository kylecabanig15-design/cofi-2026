import 'package:flutter/material.dart';

import 'colors.dart';

/// Shared interaction styling for the user, business, and admin applications.
///
/// Feature screens can still provide their own layout, but controls and system
/// feedback should feel like they belong to the same product.
abstract final class AppTheme {
  static const _canvas = Color(0xFF090707);
  static const _surface = Color(0xFF1A1817);
  static const _surfaceRaised = Color(0xFF24211F);
  static const _outline = Color(0xFF3B3531);
  static const _danger = Color(0xFFFF6B6B);

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: primary,
      onPrimary: Colors.white,
      secondary: Color(0xFFD69A77),
      onSecondary: Color(0xFF24120B),
      surface: _surface,
      onSurface: Colors.white,
      error: _danger,
      onError: Color(0xFF2B0808),
      outline: _outline,
    );

    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: _canvas,
      useMaterial3: true,
      splashFactory: InkSparkle.splashFactory,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _surfaceRaised,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
        actionTextColor: const Color(0xFFFFC7A6),
        disabledActionTextColor: Colors.white38,
        closeIconColor: Colors.white70,
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        insetPadding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _outline),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        elevation: 20,
        shadowColor: Colors.black.withValues(alpha: 0.55),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
        contentTextStyle: const TextStyle(
          color: Color(0xFFC4BFBB),
          fontSize: 14,
          height: 1.45,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: _outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF4A4542),
          disabledForegroundColor: Colors.white54,
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
          shape: rounded,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF4A4542),
          disabledForegroundColor: Colors.white54,
          elevation: 0,
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
          shape: rounded,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: const BorderSide(color: Color(0xFF625A54)),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          shape: rounded,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFFFC7A6),
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: rounded,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Color(0xFFFFC7A6),
        linearTrackColor: Color(0xFF3B3531),
        circularTrackColor: Color(0xFF3B3531),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: _surfaceRaised,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _outline),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
