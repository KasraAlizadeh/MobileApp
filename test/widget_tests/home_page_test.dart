import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app/Features/Home/home_page.dart';

void main() {
  // Wrapped inside a Scaffold and MaterialApp to provide MediaQuery and Theme bounds
  Widget wrap(Widget w) => MaterialApp(
    home: Scaffold(
      body: w,
    ),
  );

  group('Home Screen Widget Tests', () {
    testWidgets('HomePage welcome shell layout verification', (WidgetTester tester) async {
      // Mount the widget with the necessary deep link search callback stub
      await tester.pumpWidget(
        wrap(
          HomePage(
            onDeepLinkSearch: (int targetIndex, String queryCity) {},
          ),
        ),
      );

      // Changed from pump() to pumpAndSettle() to ensure all internal text animations
      // and state initializations finish rendering completely.
      await tester.pumpAndSettle();

      // Uses findsAtLeastNWidgets(1) or findsAnyWidget to verify the layout safely
      expect(find.textContaining('Welcome'), findsOneWidget);
    });
  });
}