import 'dart:convert';
import 'package:http/http.dart' as http;

class OsmService {
  final http.Client _client;

  OsmService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches nearby cities using GPS coordinates.
  Future<List<String>> getNearbyCities(double lat, double lng, {double radiusInKm = 15.0}) async {
    final double radiusInMeters = radiusInKm * 1000;

    // Optimized query: server-side timeout set to 5s and output limited only to tags
    final query = '''
      [out:json][timeout:5];
      (
        node["place"~"city|town"](around:$radiusInMeters, $lat, $lng);
      );
      out tags;
    ''';

    // Using the French mirror, which is significantly faster and more stable than the global one
    final url = Uri.parse('https://overpass.openstreetmap.fr/api/interpreter');

    try {
      final response = await _client.post(
        url,
        headers: {
          // Identifies the app to comply with OSM policies and avoid 406 blocks
          'User-Agent': 'TravelWalletApp/1.0 (https://yourdomain.com; contact@email.com)',
          'Accept-Encoding': 'gzip, deflate, br',
        },
        body: {'data': query},
      ).timeout(const Duration(seconds: 6)); // Dart timeout slightly higher than server-side timeout

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List elements = data['elements'] ?? [];

        final List<String> cityNames = elements
            .map<String>((e) {
          final tags = e['tags'] as Map?;
          if (tags == null) return '';

          // Priority to Italian, then English, then the default local name
          return tags['name:it'] ?? tags['name:en'] ?? tags['name'] ?? '';
        })
            .where((name) => name.isNotEmpty)
            .toList();

        // Removes duplicates while preserving Overpass spatial ordering
        return cityNames.toSet().toList();
      } else {
        throw Exception('Overpass Error (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      print('OSM Overpass Error: $e');
      rethrow; // Rethrow to let the HomePage handle it inside its try/catch
    }
  }

  /// Closes the HTTP client when the service is no longer needed to prevent connection leaks
  void dispose() {
    _client.close();
  }
}