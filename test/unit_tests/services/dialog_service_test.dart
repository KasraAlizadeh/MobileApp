import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app/Services/dialog_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('DialogService Comprehensive Validation Tests', () {

    testWidgets('showErrorDialog builds, displays message, and closes cleanly', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => DialogService.showErrorDialog(context, "System Critical Exception Trace"),
              child: const Text("Trigger Error"),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Trigger Error"));
      await tester.pump(); // Start dialog open frame animation

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text("Error"), findsOneWidget);
      expect(find.text("System Critical Exception Trace"), findsOneWidget);
      expect(find.text("OK"), findsOneWidget);

      await tester.tap(find.text("OK"));
      await tester.pumpAndSettle(); // Settle closing route animations

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('showSuccessSnackBar displays snackbar overlay successfully with message', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => DialogService.showSuccessSnackBar(context, "Operations Completed!"),
              child: const Text("Trigger Snack"),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Trigger Snack"));
      await tester.pump(); // Render frame for SnackBar appearance

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text("Operations Completed!"), findsOneWidget);

      await tester.pumpAndSettle();
    });
  });
}