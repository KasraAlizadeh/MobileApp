import 'package:flutter/material.dart';

class AppTheme {
  // Brand color constants
  static const Color brandGreen = Color(0xFF52796F);
  static const Color darkGreen = Color(0xFF2F3E46);
  static const Color sageGreen = Color(0xFF84A98C);
  static const Color pastelGreen = Color(0xFFCAD2C5);
  static const Color mutedGrey = Color(0xFF848282);

  // =====================================================================
  // THEME 1: LIGHT MODE
  // =====================================================================
  static final ThemeData theme1 = ThemeData(
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.teal,
      primary: brandGreen,
    ),
    appBarTheme: const AppBarThemeData(
      toolbarHeight: 80,
      titleTextStyle: TextStyle(
        fontFamily: 'montserrat',
        fontSize: 30,
        fontWeight: FontWeight.bold,
        color: brandGreen,
      ),
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.bold,
        color: brandGreen,
      ),
      titleMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: brandGreen,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      selectedItemColor: darkGreen,
      unselectedItemColor: mutedGrey,
      showSelectedLabels: true,
      showUnselectedLabels: false,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: sageGreen,
        foregroundColor: Colors.white, // Proper M3 way to set text/icon color
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: sageGreen),
        foregroundColor: sageGreen, // Proper M3 way to set text color for outlined items
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: darkGreen,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(25),
      ),
      titleTextStyle: const TextStyle(
        fontFamily: 'montserrat',
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      contentTextStyle: const TextStyle(
        fontSize: 16,
        color: Colors.white70,
      ),
    ),
    useMaterial3: true,
  );

  // =====================================================================
  // THEME 2: DARK MODE
  // =====================================================================
  static final ThemeData theme2 = ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: brandGreen,
      brightness: Brightness.dark,
      primary: sageGreen,
      surface: darkGreen,
    ),
    scaffoldBackgroundColor: darkGreen,
    appBarTheme: const AppBarThemeData(
      toolbarHeight: 80,
      backgroundColor: darkGreen,
      titleTextStyle: TextStyle(
        fontFamily: 'montserrat',
        fontSize: 30,
        fontWeight: FontWeight.bold,
        color: sageGreen,
      ),
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.bold,
        color: pastelGreen,
      ),
      titleMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: sageGreen,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: darkGreen,
      elevation: 8,
      selectedItemColor: pastelGreen,
      unselectedItemColor: mutedGrey,
      showSelectedLabels: true,
      showUnselectedLabels: false,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: brandGreen,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(color: Colors.white24),
    dialogTheme: DialogThemeData(
      backgroundColor: darkGreen,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(25),
      ),
      titleTextStyle: const TextStyle(
        fontFamily: 'montserrat',
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: pastelGreen,
      ),
      contentTextStyle: const TextStyle(
        fontSize: 16,
        color: Colors.white70,
      ),
    ),
    useMaterial3: true,
  );

  // Expose the global themes list array
  static final List<ThemeData> themes = [
    theme1,
    theme2,
  ];
}