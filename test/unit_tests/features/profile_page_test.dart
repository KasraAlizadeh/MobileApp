import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app/Features/Profile/profile_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // 1. Stub native Firebase Core channel layer
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

    // 2. Stub native Firebase Auth channel layer to prevent profile initialization crash loops
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/firebase_auth'),
          (MethodCall methodCall) async {
        if (methodCall.method == 'startListen') {
          return {
            'uid': 'user_abc_123',
            'email': 'kavi@travelapp.com',
            'displayName': 'Kavi Dev',
            'photoURL': null,
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

  group('ProfilePage Visual Architecture & Action State Coverage Tests', () {

    testWidgets('Renders layout menus, branding username, and configuration elements completely', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const ProfilePage()));
      await tester.pumpAndSettle();

      // Assert basic profile text strings render correctly
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Privacy and Security'), findsOneWidget);
      expect(find.text('Dark Mode'), findsOneWidget);
      expect(find.text('Log out'), findsOneWidget);
    });

    testWidgets('Tapping username edit button shows interactive modal window layout', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const ProfilePage()));
      await tester.pumpAndSettle();

      // Locate the small username edit icon gesture wrapper
      final editIconFinder = find.byIcon(Icons.edit).at(1);
      await tester.tap(editIconFinder);
      await tester.pump(); // Render dialog window layer animation frame

      // Assert modal window elements display cleanly
      expect(find.text('Edit Username'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });
  });
}