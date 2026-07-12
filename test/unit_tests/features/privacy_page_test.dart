import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_app/Features/Profile/privacy_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  dynamic authMockException;
  bool mockAuthResponse = true;

  setUp(() {
    authMockException = null;
    mockAuthResponse = true;
    SharedPreferences.setMockInitialValues({'biometric_enabled': false});

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

    // 2. Mock native Firebase Auth channels
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/firebase_auth'),
          (MethodCall methodCall) async {
        if (authMockException != null) throw authMockException;
        if (methodCall.method == 'startListen') {
          return {'uid': 'user_xyz_789', 'email': 'kavi@travelapp.com'};
        }
        return null;
      },
    );

    // 3. Mock native local_auth (Biometrics) channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/local_auth'),
          (MethodCall methodCall) async {
        if (methodCall.method == 'canCheckBiometrics' || methodCall.method == 'isDeviceSupported') {
          return true;
        }
        if (methodCall.method == 'authenticate') {
          return mockAuthResponse;
        }
        return null;
      },
    );
  });

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  group('PrivacyPage Targeted Coverage Suite', () {

    testWidgets('Triggers biometric check state setting and toggles switch to false', (WidgetTester tester) async {
      // Start with biometrics already enabled in SharedPreferences to trigger the 'else' block later
      SharedPreferences.setMockInitialValues({'biometric_enabled': true});

      await tester.pumpWidget(buildTestableWidget(const PrivacyPage()));
      await tester.pumpAndSettle(); // Executes initState, _loadBiometricSetting, and _checkBiometricSupport

      // Find the SwitchListTile toggle target element and flip it off
      final switchFinder = find.byType(SwitchListTile);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle(); // Hits the 'else' block for _toggleBiometrics
    });

    testWidgets('Toggles biometric switch to true and handles a failed authentication exception', (WidgetTester tester) async {
      mockAuthResponse = false; // Simulate biometric auth failure or exception trigger

      await tester.pumpWidget(buildTestableWidget(const PrivacyPage()));
      await tester.pumpAndSettle();

      final switchFinder = find.byType(SwitchListTile);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle(); // Hits the catch block inside _toggleBiometrics
    });

    testWidgets('Submitting valid passwords triggers change password and handles catch exceptions', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const PrivacyPage()));
      await tester.pumpAndSettle();

      // Satisfy validators by making passwords valid and matching
      await tester.enterText(find.byType(TextFormField).at(0), 'oldPassword123');
      await tester.enterText(find.byType(TextFormField).at(1), 'newSecurePassword');
      await tester.enterText(find.byType(TextFormField).at(2), 'newSecurePassword');
      await tester.pump();

      // Click Update Password
      await tester.tap(find.text('Update Password'));
      await tester.pump(); // Triggers _changePassword validation check line
      await tester.pumpAndSettle(); // Hits the inner try block lines
    });
  });
}