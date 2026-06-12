import 'package:flutter/material.dart';

class AppTheme {
  static const Color brandGreen = Color(0xFF52796F);

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
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      selectedItemColor: Color(0xFF354F52),
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
    useMaterial3: true,
  );

  static final List<ThemeData> themes = [
    theme1,
  ];
}