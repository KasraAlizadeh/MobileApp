import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:travel_app/Services/location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Create a tracking variable to let us dynamically toggle permissions in tests
  late String mockPermissionState;
  late bool mockServiceEnabled;
  late bool simulateChannelCrash;

  setUp(() {
    mockPermissionState = 'whileInUse'; // Default permission state
    mockServiceEnabled = true;          // Default hardware state
    simulateChannelCrash = false;

    // Intercept geolocator native system channel operations cleanly
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/geolocator'),
          (MethodCall methodCall) async {
        if (simulateChannelCrash) {
          throw PlatformException(code: 'ERROR', message: 'Hardware failure');
        }

        switch (methodCall.method) {
          case 'isLocationServiceEnabled':
            return mockServiceEnabled;
          case 'checkPermission':
          case 'requestPermission':
            if (mockPermissionState == 'denied') return 0;
            if (mockPermissionState == 'deniedForever') return 1;
            if (mockPermissionState == 'whileInUse') return 3;
            return 0;
          case 'getCurrentPosition':
            return {
              'latitude': 45.4642,
              'longitude': 9.1900,
              'timestamp': 0,
              'accuracy': 1.0,
              'altitude': 0.0,
              'heading': 0.0,
              'speed': 0.0,
              'speed_accuracy': 0.0
            };
          default:
            return null;
        }
      },
    );
  });

  group('LocationService Comprehensive Branch Coverage Tests', () {

    test('Returns position successfully when service is enabled and permission granted', () async {
      final service = LocationService();
      final position = await service.getCurrentLocation();

      expect(position, isNotNull);
      expect(position!.latitude, 45.4642);
      expect(position.longitude, 9.1900);
    });

    test('Returns null immediately when hardware GPS service is disabled', () async {
      mockServiceEnabled = false;

      final service = LocationService();
      final position = await service.getCurrentLocation();

      expect(position, isNull);
    });

    test('Returns null when checkPermission is denied and requestPermission remains denied', () async {
      mockPermissionState = 'denied';

      final service = LocationService();
      final position = await service.getCurrentLocation();

      expect(position, isNull);
    });

    test('Returns null immediately if permission is deniedForever', () async {
      mockPermissionState = 'deniedForever';

      final service = LocationService();
      final position = await service.getCurrentLocation();

      expect(position, isNull);
    });

    test('Catch block triggers and returns null on native platform exceptions', () async {
      simulateChannelCrash = true;

      final service = LocationService();
      final position = await service.getCurrentLocation();

      expect(position, isNull);
    });
  });
}