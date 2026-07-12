import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app/Features/Search/search_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
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

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/firebase_auth'),
          (MethodCall methodCall) async {
        if (methodCall.method == 'startListen') {
          return {
            'uid': 'explorer_dev_123',
            'email': 'test@travelapp.com',
          };
        }
        return null;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/geocoding'),
          (MethodCall methodCall) async {
        if (methodCall.method == 'locationFromAddress') {
          return [
            {
              'latitude': 41.9028,
              'longitude': 12.4964,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            }
          ];
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

  group('SearchPage Interactive Map and AI Layout Suite Tests', () {

    testWidgets('Renders map panels, bottom prompt input, and category filter chips cleanly', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const SearchPage()));

      // Let initial async stream builders transition smoothly
      await tester.pump();

      // Assert main viewport elements mount correctly
      expect(find.text('Journey Explorer'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Local Food'), findsOneWidget);
    });

    testWidgets('Triggers validation feedback alert when submitting an empty input prompt line', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const SearchPage()));
      await tester.pump();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle(); // Render feedback notice update layout frame

      expect(find.text("Please enter a city name first."), findsOneWidget);
    });
  });
}