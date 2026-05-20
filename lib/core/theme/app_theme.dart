import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/ui_constants.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = ThemeData(useMaterial3: true, brightness: brightness);
    final colorScheme = isDark
        ? const ColorScheme.dark(
            primary: Color(0xFF8FB3FF),
            secondary: Color(0xFFA8C8FF),
            surface: Color(0xFF1D2430),
            onSurface: Color(0xFFE7ECF3),
            onPrimary: Color(0xFF0F1724),
          )
        : const ColorScheme.light(
            primary: UiConstants.goOrange,
            secondary: UiConstants.goOrange,
            surface: UiConstants.warmSurface,
            onSurface: Color(0xFF111111),
            onPrimary: Colors.white,
          );
    final onSurfaceText = isDark
        ? const Color(0xFFE7ECF3)
        : const Color(0xFF111111);
    final scaffoldColor = isDark
        ? const Color(0xFF101722)
        : UiConstants.warmWhite;
    final cardColor = isDark
        ? const Color(0xFF1A2230)
        : UiConstants.warmSurface;
    final outlineSideColor = isDark
        ? const Color(0x66FFFFFF)
        : const Color(0x22000000);
    final dividerColor = isDark
        ? const Color(0x24FFFFFF)
        : const Color(0x12000000);

    final pretendardTextTheme = GoogleFonts.interTextTheme(base.textTheme);

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldColor,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: onSurfaceText,
        elevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(UiConstants.minTouchTarget),
          backgroundColor: isDark
              ? const Color(0xFFDCE8FF)
              : UiConstants.navyInk,
          foregroundColor: isDark ? const Color(0xFF121A29) : Colors.white,
          animationDuration: UiConstants.softAnimation,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(UiConstants.minTouchTarget),
          side: BorderSide(color: outlineSideColor),
          foregroundColor: onSurfaceText,
          animationDuration: UiConstants.softAnimation,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UiConstants.cardRadius),
        ),
      ),
      dividerTheme: DividerThemeData(color: dividerColor),
      textTheme: pretendardTextTheme
          .apply(bodyColor: onSurfaceText, displayColor: onSurfaceText)
          .copyWith(
            titleLarge: pretendardTextTheme.titleLarge?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
            titleMedium: pretendardTextTheme.titleMedium?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
            titleSmall: pretendardTextTheme.titleSmall?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
            bodyLarge: pretendardTextTheme.bodyLarge?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.44,
            ),
            bodyMedium: pretendardTextTheme.bodyMedium?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.44,
            ),
            bodySmall: pretendardTextTheme.bodySmall?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.44,
            ),
          ),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide(color: outlineSideColor),
      ),
    );
  }
}
