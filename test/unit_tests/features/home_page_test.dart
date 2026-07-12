import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app/Features/Home/home_page.dart';

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
          return {'uid': 'dummy_uid', 'email': 'test@test.com'};
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
              'latitude': 45.4642,
              'longitude': 9.1900,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            }
          ];
        }
        if (methodCall.method == 'placemarkFromCoordinates') {
          return [
            {
              'name': 'Milano',
              'street': 'Duomo',
              'isoCountryCode': 'IT',
              'country': 'Italy',
              'postalCode': '20121',
              'administrativeArea': 'Lombardia',
              'subAdministrativeArea': 'Milano',
              'locality': 'Milano',
              'subLocality': '',
            }
          ];
        }
        return null;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/geolocator'),
          (MethodCall methodCall) async {
        if (methodCall.method == 'isLocationServiceEnabled') {
          return true;
        }
        if (methodCall.method == 'checkPermission' || methodCall.method == 'requestPermission') {
          return 3; // LocationPermission.whileInUse index mapping integer
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

  group('HomePage Visual State and Error Handling Suite Tests', () {

    testWidgets('Renders immediate progress indicators during initial data sync execution', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          HomePage(onDeepLinkSearch: (index, query) {}),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    test('SuggestedCity class object stores initialized properties correctly', () {
      final city = SuggestedCity(
        name: 'Venezia',
        imageUrl: 'https://test.com/venice.jpg',
        subtitle: 'Explore nearby',
        region: 'Veneto',
        province: 'Venezia',
      );

      expect(city.name, 'Venezia');
      expect(city.imageUrl, 'https://test.com/venice.jpg');
      expect(city.subtitle, 'Explore nearby');
      expect(city.region, 'Veneto');
      expect(city.province, 'Venezia');
    });
  });
}