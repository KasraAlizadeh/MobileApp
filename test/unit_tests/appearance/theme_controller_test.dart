import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app/Appearance/app_theme.dart';
import 'package:travel_app/Appearance/theme_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeController State Machine Coverage Tests', () {

    test('Initializes with default first theme index layout', () {
      // Accessing the structural template forces notifier field evaluation
      final currentThemeData = ThemeController.themeNotifier.value;

      expect(currentThemeData, equals(AppTheme.themes[0]));
    });

    test('nextTheme increments rotation math loop correctly across elements', () {
      // First toggle: moves from index 0 to index 1
      ThemeController.nextTheme();
      expect(ThemeController.themeNotifier.value, equals(AppTheme.themes[1]));

      // Second toggle: moves from index 1 back to index 0 (modulo bounds check)
      ThemeController.nextTheme();
      expect(ThemeController.themeNotifier.value, equals(AppTheme.themes[0]));
    });
  });
}