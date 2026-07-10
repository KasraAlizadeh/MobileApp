import 'package:flutter/material.dart';
import 'app_theme.dart';

class ThemeController {
  // Keeps track of the current theme style index
  static int _currentIndex = 0;

  // Global listener notifier to automatically broadcast theme alterations across the app
  static ValueNotifier<ThemeData> themeNotifier =
  ValueNotifier(AppTheme.themes[_currentIndex]);

  /// Cycles to the next available theme inside the AppTheme configuration collection.
  /// Loops back to the first theme automatically when reaching the end.
  static void nextTheme() {
    _currentIndex = (_currentIndex + 1) % AppTheme.themes.length;
    themeNotifier.value = AppTheme.themes[_currentIndex];
  }
}