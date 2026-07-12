import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app/Auth/login_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Explicitly keep track of what the native mock channel should throw
  dynamic authMockException;

  setUp(() {
    authMockException = null;

    // 1. Mock native Firebase Core channels
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/firebase_core'),
          (MethodCall methodCall) async {
        if (methodCall.method == 'initializeApp') {
          return {
            'name': methodCall.arguments['appName'],
            'options': methodCall.arguments['options'],
            'pluginConstants': {},
          };
        }
        return null;
      },
    );

    // 2. Mock native Firebase Auth channels dynamically based on the active test case state
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/firebase_auth'),
          (MethodCall methodCall) async {
        if (authMockException != null) {
          throw authMockException;
        }
        if (methodCall.method == 'startListen') {
          return {'uid': 'dummy_uid', 'email': 'test@travel.com'};
        }
        // Return dummy success data for signInWithEmailAndPassword calls when no error is requested
        if (methodCall.method == 'signInWithEmailAndPassword') {
          return {
            'user': {'uid': 'dummy_uid', 'email': 'test@travel.com'}
          };
        }
        return null;
      },
    );
  });

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  group('LoginPage Detailed Execution Coverage Tests', () {

    testWidgets('Submitting valid credentials covers successful login and navigation', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const LoginPage()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'test@travel.com');
      await tester.enterText(find.byType(TextField).at(1), 'password123');

      await tester.tap(find.text('Log In'));
      await tester.pump(); // Captures the _isLoading = true state frame
      await tester.pumpAndSettle();
    });

    testWidgets('Triggers onSubmitted execution from password text field', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const LoginPage()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'test@travel.com');
      await tester.enterText(find.byType(TextField).at(1), 'password123');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    });

    testWidgets('Handles target FirebaseAuthException codes cleanly', (WidgetTester tester) async {
      // Set the error to be thrown by our mock channel handler
      authMockException = PlatformException(
        code: 'wrong-password',
        message: 'The password provided is incorrect.',
        details: {'code': 'wrong-password'},
      );

      await tester.pumpWidget(buildTestableWidget(const LoginPage()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'bad@travel.com');
      await tester.enterText(find.byType(TextField).at(1), 'wrong');

      await tester.tap(find.text('Log In'));
      await tester.pump(); // Let exception bubble and trigger setState()
      await tester.pumpAndSettle(); // Settle dialog rendering

      expect(find.text('Incorrect email or password.'), findsOneWidget);

      // Dismiss dialog
      final okButton = find.text('OK');
      if (tester.any(okButton)) {
        await tester.tap(okButton);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('Handles unexpected generic system exceptions inside runtime block', (WidgetTester tester) async {
      // Force a generic platform crash
      authMockException = PlatformException(code: 'UNKNOWN_ERROR', message: 'Fatal generic error');

      await tester.pumpWidget(buildTestableWidget(const LoginPage()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'error@travel.com');
      await tester.enterText(find.byType(TextField).at(1), 'password');

      await tester.tap(find.text('Log In'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('An unexpected error occurred.'), findsOneWidget);
    });
  });
}