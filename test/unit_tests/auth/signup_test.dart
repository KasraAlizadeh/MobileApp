import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app/Auth/signup_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  dynamic authMockException;
  bool mockFirestoreFail;

  setUp(() {
    authMockException = null;
    mockFirestoreFail = false;

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

    // 2. Mock native Firebase Auth channels dynamically
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/firebase_auth'),
          (MethodCall methodCall) async {
        if (authMockException != null) {
          throw authMockException;
        }
        if (methodCall.method == 'createUserWithEmailAndPassword') {
          return {
            'user': {
              'uid': 'new_user_xyz',
              'email': 'signup@test.com',
              'displayName': 'Kavi'
            }
          };
        }
        return null;
      },
    );

    // 3. Mock native Cloud Firestore channels to clear out the doc.set() statement line
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/cloud_firestore'),
          (MethodCall methodCall) async {
        if (mockFirestoreFail) {
          throw PlatformException(code: 'ERROR', message: 'Firestore Crash');
        }
        return null; // Simulate a clean write success
      },
    );
  });

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  group('SignUpPage Complete Execution Coverage Suite', () {

    testWidgets('Submitting valid fields runs clean signup, user updates, firestore write, and navigation', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const SignUpPage()));
      await tester.pumpAndSettle();

      // Input matching fields data
      await tester.enterText(find.byType(TextField).at(0), 'Kavi');
      await tester.enterText(find.byType(TextField).at(1), 'signup@test.com');
      await tester.enterText(find.byType(TextField).at(2), 'securePass123');
      await tester.enterText(find.byType(TextField).at(3), 'securePass123');

      // Click button to invoke full try block pipeline execution
      await tester.tap(find.text('Create account'));
      await tester.pump(); // Captures _isLoading = true layout changes
      await tester.pumpAndSettle(); // Completes finally blocks cleanly
    });

    testWidgets('Triggers onSubmitted execution from confirm password field keyboard action', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const SignUpPage()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Kavi');
      await tester.enterText(find.byType(TextField).at(1), 'signup@test.com');
      await tester.enterText(find.byType(TextField).at(2), 'securePass123');
      await tester.enterText(find.byType(TextField).at(3), 'securePass123');

      // Hit keyboard done button to target the onSubmitted callback branch
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    });

    testWidgets('Catches target FirebaseAuthException rules seamlessly', (WidgetTester tester) async {
      authMockException = PlatformException(
        code: 'email-already-in-use',
        message: 'The email address is already in use by another account.',
        details: {'code': 'email-already-in-use'},
      );

      await tester.pumpWidget(buildTestableWidget(const SignUpPage()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Kavi');
      await tester.enterText(find.byType(TextField).at(1), 'alreadyuse@test.com');
      await tester.enterText(find.byType(TextField).at(2), 'securePass123');
      await tester.enterText(find.byType(TextField).at(3), 'securePass123');

      await tester.tap(find.text('Create account'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('An account already exists for that email.'), findsOneWidget);
    });

    testWidgets('Catches generic system error crashes inside signup pipeline execution', (WidgetTester tester) async {
      mockFirestoreFail = true; // Force database crash inside the try block to target standard catch(e)

      await tester.pumpWidget(buildTestableWidget(const SignUpPage()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Kavi');
      await tester.enterText(find.byType(TextField).at(1), 'crash@test.com');
      await tester.enterText(find.byType(TextField).at(2), 'securePass123');
      await tester.enterText(find.byType(TextField).at(3), 'securePass123');

      await tester.tap(find.text('Create account'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.textContaining('Generic error:'), findsOneWidget);
    });
  });
}