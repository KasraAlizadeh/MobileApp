import 'package:flutter/material.dart';
import 'app_theme.dart';

class ThemeController {
  static int _currentIndex = 0;

  static ValueNotifier<ThemeData> themeNotifier =
  ValueNotifier(AppTheme.themes[_currentIndex]);

  static void nextTheme() {
    _currentIndex = (_currentIndex+1) % AppTheme.themes.length;
    themeNotifier.value = AppTheme.themes[_currentIndex];
  }
}