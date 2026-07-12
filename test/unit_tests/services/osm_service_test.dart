import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:travel_app/Services/osm_service.dart';

// 1. Mock the specific http Client package cleanly
class MockHttpClient extends Mock implements http.Client {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockHttpClient mockClient;

  setUpAll(() {
    registerFallbackValue(Uri());
  });

  setUp(() {
    mockClient = MockHttpClient();
  });

  group('OsmService Overpass Engine Coverage Tests', () {

    test('getNearbyCities parses successful OpenStreetMap payload correctly', () async {
      final mockResponseData = {
        'elements': [
          {
            'tags': {'name': 'Milano', 'name:en': 'Milan', 'name:it': 'Milano'}
          },
          {
            'tags': {'name': 'Monza'}
          }
        ]
      };

      // Stub the post request to return our mock JSON string
      when(() => mockClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer((_) async => http.Response(jsonEncode(mockResponseData), 200));

      final service = OsmService(client: mockClient);
      final cities = await service.getNearbyCities(45.4642, 9.1900);

      expect(cities.length, 2);
      expect(cities, contains('Milano'));
      expect(cities, contains('Monza'));
    });

    test('getNearbyCities fallback logic selects localized names correctly', () async {
      final mockResponseData = {
        'elements': [
          {
            'tags': {'name:en': 'Rome', 'name': 'Roma'} // Missing name:it, should fall back to name:en
          },
          {
            'tags': {'name': 'Napoli'} // Missing localization, should fall back to raw name
          }
        ]
      };

      when(() => mockClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer((_) async => http.Response(jsonEncode(mockResponseData), 200));

      final service = OsmService(client: mockClient);
      final cities = await service.getNearbyCities(41.9028, 12.4964);

      expect(cities, contains('Rome'));
      expect(cities, contains('Napoli'));
    });

    test('getNearbyCities throws Exception when server returns a non-200 code', () async {
      when(() => mockClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer((_) async => http.Response('Internal Server Error', 500));

      final service = OsmService(client: mockClient);

      expect(
            () => service.getNearbyCities(45.4642, 9.1900),
        throwsA(isA<Exception>()),
      );
    });
  });
}