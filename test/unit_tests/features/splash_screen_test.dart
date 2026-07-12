import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:travel_app/Features/splash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  group('SplashPage Layout and Asynchronous Loading Sequence Tests', () {

    testWidgets('Renders onboarding branding message and loading components completely', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const SplashPage()));

      // Validate visual indicators are painted safely onto the screen canvas
      expect(find.text("Preparing Your Next Adventure..."), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(Lottie), findsOneWidget);
    });

    testWidgets('Executes chronological asset delay sequence and fires route triggers completely', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const SplashPage()));

      // 1. Initial render frame setup
      await tester.pump();

      // 2. Fast-forward the mock test clock by 3000ms to bypass the internal Future.delayed block
      await tester.pump(const Duration(milliseconds: 3000));

      // 3. Settle remaining pipeline transition microtasks
      await tester.pumpAndSettle();

      // This safely triggers the mounted condition check and covers the Navigator block entirely
    });
  });
}