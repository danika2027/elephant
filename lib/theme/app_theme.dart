import 'package:flutter/material.dart';

/// 全局主题 — 极简、温暖手绘感、文字为主
class AppTheme {
  AppTheme._();

  // ---- 色彩 ----
  static const Color primaryWarm = Color(0xFFE8A87C); // 小象肤色
  static const Color bgWarm = Color(0xFFFDF6F0); // 信纸底色
  static const Color textPrimary = Color(0xFF3C3C3C);
  static const Color textSecondary = Color(0xFF8B8B8B);
  static const Color accentGreen = Color(0xFF7CB342);
  static const Color cardBg = Color(0xFFFFFBF6);
  static const Color dividerColor = Color(0xFFE8D5C4);
  static const Color mapRouteColor = Color(0xFFE8A87C);

  // ---- 圆角 ----
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 24.0;

  // ---- 间距 ----
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;

  // ---- Material Theme ----
  static ThemeData get materialTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryWarm,
          primary: primaryWarm,
          surface: bgWarm,
        ),
        scaffoldBackgroundColor: bgWarm,
        appBarTheme: const AppBarTheme(
          backgroundColor: bgWarm,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            color: textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
          titleMedium: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
          bodyLarge: TextStyle(
            color: textPrimary,
            fontSize: 16,
            height: 1.8,
          ),
          bodyMedium: TextStyle(
            color: textSecondary,
            fontSize: 14,
            height: 1.6,
          ),
          labelSmall: TextStyle(
            color: textSecondary,
            fontSize: 12,
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: dividerColor,
          thickness: 1,
        ),
        cardTheme: CardThemeData(
          color: cardBg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
        ),
      );
}
