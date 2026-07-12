import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:travel_app/Auth/login_page.dart';
import 'package:travel_app/Auth/signup_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/firebase_core'), (MethodCall methodCall) async => {},
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/firebase_auth'), (MethodCall methodCall) async => {'uid': '123'},
    );
  });

  Widget wrap(Widget w) => MaterialApp(home: Scaffold(body: w));

  group('Auth Screens Widget Tests', () {
    testWidgets('LoginPage structural validation', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const LoginPage()));
      await tester.pump();
      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    });

    testWidgets('SignUpPage structural validation', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const SignUpPage()));
      await tester.pump();
      expect(find.widgetWithText(TextFormField, 'Full Name'), findsOneWidget);
    });
  });
}