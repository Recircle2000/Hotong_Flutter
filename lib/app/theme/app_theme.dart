import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    return ThemeData(
      primaryColor: Colors.white,
      scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF8F9FA),
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.grey[100],
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.grey,
        background: Colors.white,
        surface: Colors.white,
        surfaceVariant: Colors.grey[100]!,
        onSurfaceVariant: Colors.grey[800]!,
        primary: Colors.grey[800]!,
        onPrimary: Colors.white,
        secondary: Colors.grey[600]!,
        onSecondary: Colors.white,
        tertiary: Colors.grey[400]!,
        onTertiary: Colors.black,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(Colors.black),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      useMaterial3: true,
    );
  }

  static ThemeData dark() {
    return ThemeData(
      primaryColor: const Color(0xFF121212),
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF121212),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.grey[900],
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.grey[900]!,
        background: const Color(0xFF121212),
        surface: Colors.grey[900]!,
        surfaceVariant: const Color(0xFF1E1E1E),
        onSurfaceVariant: Colors.grey[300]!,
        primary: Colors.grey[300]!,
        onPrimary: const Color(0xFF121212),
        secondary: Colors.grey[500]!,
        onSecondary: Colors.black,
        tertiary: Colors.grey[600]!,
        onTertiary: Colors.white,
        brightness: Brightness.dark,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(Colors.white),
          foregroundColor: WidgetStateProperty.all(Colors.black),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      textTheme: Typography.whiteMountainView,
      useMaterial3: true,
    );
  }
}
