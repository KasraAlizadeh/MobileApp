import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_app/Features/Wallet/wallet_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // 1. Force biometrics to be disabled by default to skip native login gate blocks
    SharedPreferences.setMockInitialValues({'biometric_enabled': false});

    // 2. Mock native Firebase Core communication channel
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

    // 3. Mock native Firebase Auth communication channel to present an active session
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/firebase_auth'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'startListen') {
          return {
            'uid': 'wallet_user_999',
            'email': 'user@wallet.com',
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

  group('WalletPage UI and State Machinery Suite Tests', () {

    testWidgets('Renders action buttons and initial loading indicators correctly', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const WalletPage()));

      // Let the initial asynchronous preference checks evaluate
      await tester.pump();

      // Assert scaffolding layout components appear
      expect(find.text('My Journeys ✈️'), findsOneWidget);
      expect(find.text('Add a new journey'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}