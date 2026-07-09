import 'package:flutter/material.dart';

class AppTheme {
  static const Color brandGreen = Color(0xFF52796F);
  static const Color darkGreen = Color(0xFF2f3e46);

  static final theme1 = ThemeData(
    colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        primary: brandGreen
    ),
    appBarTheme: const AppBarThemeData(
      toolbarHeight: 80,
      titleTextStyle: TextStyle(
        fontFamily: 'montserrat',
        fontSize: 30,
        fontWeight: FontWeight.bold,
        color: brandGreen,
      )
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
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      selectedItemColor: darkGreen,
      unselectedItemColor: Color(0xFF848282),
      showSelectedLabels: true,
      showUnselectedLabels: false,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF84a98c),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)
        ),
        textStyle: TextStyle(
          color: Colors.white,
        )
      )
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFF84a98c)),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)
        ),
        textStyle: TextStyle(
          color: Colors.white,
        )
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

  static final theme2 = ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: brandGreen,
      brightness: Brightness.dark,
      primary: const Color(0xFF84a98c),
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
          color: Color(0xFF84a98c),
        )
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.bold,
        color: Color(0xFFcad2c5),
      ),
      titleMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Color(0xFF84a98c),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: darkGreen,
      elevation: 8,
      selectedItemColor: Color(0xFFcad2c5),
      unselectedItemColor: Color(0xFF848282),
      showSelectedLabels: true,
      showUnselectedLabels: false,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
            backgroundColor: brandGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)
            ),
        )
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
        color: Color(0xFFcad2c5),
      ),
      contentTextStyle: const TextStyle(
        fontSize: 16,
        color: Colors.white70,
      ),
    ),
    useMaterial3: true,
  );

  static final List<ThemeData> themes = [
    theme1,
    theme2,
  ];
}
