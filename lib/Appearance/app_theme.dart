import 'package:flutter/material.dart';

class AppTheme {
  static final theme1 = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
    appBarTheme: AppBarThemeData(
      toolbarHeight: 80,
      titleTextStyle: TextStyle(
        fontFamily: 'montserrat',
        fontSize: 30,
        fontWeight: FontWeight.bold,
        color: Color(0xFF52796F),
      )
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      selectedItemColor: Color(0xFF354F52),
      unselectedItemColor: Color(0xFF848282),
      showSelectedLabels: true,
      showUnselectedLabels: false,
    ),
    useMaterial3: true,
  );
  static final theme2 = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
    useMaterial3: true,
  );
  static final theme3 = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
    useMaterial3: true,
  );

  static final List<ThemeData> themes = [
    theme1,
    theme2,
    theme3,
  ];
}