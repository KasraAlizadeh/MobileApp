import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app/Appearance/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppTheme Configuration Suite Coverage Tests', () {

    test('Verifies static assets and colors are declared correctly', () {
      // Accessing the static color property triggers evaluation field coverage
      expect(AppTheme.brandGreen, const Color(0xFF52796F));
    });

    test('Loads theme1 configuration parameters completely', () {
      final theme = AppTheme.theme1;

      expect(theme.useMaterial3, isTrue);
      expect(theme.appBarTheme.toolbarHeight, 80);
      expect(theme.colorScheme.primary, AppTheme.brandGreen);
      expect(theme.textTheme.titleLarge?.fontSize, 30);
    });

    test('Loads theme2 configuration parameters completely', () {
      final theme = AppTheme.theme2;
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, const Color(0xFF2f3e46));
      expect(theme.dividerTheme.color, Colors.white24);
    });

    test('Themes list aggregation compiles with correct index mapping counts', () {
      final allThemes = AppTheme.themes;
      expect(allThemes.length, 2);
      expect(allThemes[0], AppTheme.theme1);
      expect(allThemes[1], AppTheme.theme2);
    });
  });
}