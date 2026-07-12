import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_app/Services/google_places_service.dart';

class MockHttpOverrides extends HttpOverrides {
  final String Function(Uri url) responseProvider;
  MockHttpOverrides(this.responseProvider);

  @override
  HttpClient createHttpClient(SecurityContext? context) => MockHttpClient(responseProvider);
}

class MockHttpClient implements HttpClient {
  final String Function(Uri url) responseProvider;
  MockHttpClient(this.responseProvider);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => MockHttpClientRequest(url, responseProvider);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockHttpClientRequest implements HttpClientRequest {
  final Uri url;
  final String Function(Uri url) responseProvider;
  MockHttpClientRequest(this.url, this.responseProvider);

  @override
  HttpHeaders get headers => MockHttpHeaders();

  @override
  Future<HttpClientResponse> get done => Future.value(MockHttpClientResponse(url, responseProvider));

  @override
  Future<HttpClientResponse> close() async => Future.value(MockHttpClientResponse(url, responseProvider));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockHttpClientResponse implements HttpClientResponse {
  final Uri url;
  final String Function(Uri url) responseProvider;

  @override
  final int statusCode = 200;

  MockHttpClientResponse(this.url, this.responseProvider);

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    final bodyString = responseProvider(url);
    final data = utf8.encode(bodyString);
    return Stream<List<int>>.fromIterable([data]).listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockHttpHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/geocoding'),
          (MethodCall methodCall) async {
        if (methodCall.method == 'locationFromAddress') {
          return [
            {'latitude': 45.4642, 'longitude': 9.1900, 'timestamp': 123456}
          ];
        }
        if (methodCall.method == 'placemarkFromCoordinates') {
          return [
            {
              'administrativeArea': 'Lombardia',
              'subAdministrativeArea': 'Milano',
            }
          ];
        }
        return null;
      },
    );
  });

  group('GooglePlacesService Method Engine Coverage Tests', () {

    test('getSuggestions handles successful network parse paths seamlessly', () async {
      final mockData = {
        'predictions': [
          {'description': 'Milano, Italy', 'place_id': 'milano_id_001'}
        ]
      };
      HttpOverrides.global = MockHttpOverrides((_) => jsonEncode(mockData));

      final service = GooglePlacesService();
      final results = await service.getSuggestions('Mil');

      expect(results.first['description'], 'Milano, Italy');
      expect(results.first['placeId'], 'milano_id_001');
    });

    test('getPlaceDescription resolves clean Wikipedia extraction paths', () async {
      HttpOverrides.global = MockHttpOverrides((url) {
        if (url.toString().contains('search')) {
          return jsonEncode({
            'query': {
              'search': [{'title': 'Milan'}]
            }
          });
        }
        return jsonEncode({'extract': 'Milano is a gorgeous northern city in Italy.'});
      });

      final service = GooglePlacesService();
      final desc = await service.getPlaceDescription('Milano');
      expect(desc, 'Milano is a gorgeous northern city in Italy.');
    });

    test('getCityStats compiles geocoding and wikidata claims correctly', () async {
      HttpOverrides.global = MockHttpOverrides((url) {
        if (url.toString().contains('search')) {
          return jsonEncode({
            'query': {
              'search': [{'title': 'Milan'}]
            }
          });
        }
        if (url.toString().contains('pageprops')) {
          return jsonEncode({
            'query': {
              'pages': {
                '123': {
                  'pageprops': {'wikibase_item': 'Q1490'}
                }
              }
            }
          });
        }
        return jsonEncode({
          'entities': {
            'Q1490': {
              'claims': {
                'P1082': [{'mainsnak': {'datavalue': {'value': {'amount': '+1350000'}}}}],
                'P2046': [{'mainsnak': {'datavalue': {'value': {'amount': '+181.7'}}}}],
              }
            }
          }
        });
      });

      final service = GooglePlacesService();
      final stats = await service.getCityStats('Milano');

      expect(stats, contains('Region: Lombardia'));
      expect(stats, contains('Province: Milano'));
      expect(stats, contains('Population: 1,350,000'));
      expect(stats, contains('Surface: 181.70 km²'));
    });

    test('getPlacePhotoUrl fetches, stores, and targets memory-cache fields', () async {
      SharedPreferences.setMockInitialValues({});

      final mockPhotoPayload = {
        'candidates': [
          {
            'photos': [{'photo_reference': 'ref_abc_123'}]
          }
        ]
      };
      HttpOverrides.global = MockHttpOverrides((_) => jsonEncode(mockPhotoPayload));

      final service = GooglePlacesService();
      final url = await service.getPlacePhotoUrl('Milano');

      expect(url, contains('photo_reference=ref_abc_123'));
    });
  });
}