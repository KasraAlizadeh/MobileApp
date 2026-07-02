import 'dart:convert';
import 'package:http/http.dart' as http;

class OsmService {
  final http.Client _client;

  OsmService({http.Client? client}) : _client = client ?? http.Client();

  /// Recupera i comuni limitrofi usando le coordinate GPS.
  Future<List<String>> getNearbyCities(double lat, double lng, {double radiusInKm = 15.0}) async {
    final double radiusInMeters = radiusInKm * 1000;

    // Query ottimizzata: inserito timeout di 5s lato server e output limitato ai soli tags
    final query = '''
      [out:json][timeout:5];
      (
        node["place"~"city|town"](around:$radiusInMeters, $lat, $lng);
      );
      out tags;
    ''';

    // Usiamo il mirror francese, decisamente più scattante e stabile di quello globale
    final url = Uri.parse('https://overpass.openstreetmap.fr/api/interpreter');

    try {
      final response = await _client.post(
        url,
        headers: {
          // Identifica l'app per rispettare le policy di OSM ed evitare il blocco 406
          'User-Agent': 'TravelWalletApp/1.0 (https://tuodominio.com; contact@email.com)',
          'Accept-Encoding': 'gzip, deflate, br',
        },
        body: {'data': query},
      ).timeout(const Duration(seconds: 6)); // Timeout Dart leggermente superiore a quello del server

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List elements = data['elements'] ?? [];

        final List<String> cityNames = elements
            .map<String>((e) {
          final tags = e['tags'] as Map?;
          if (tags == null) return '';

          // Priorità alla lingua italiana, poi inglese, poi il nome nativo locale
          return tags['name:it'] ?? tags['name:en'] ?? tags['name'] ?? '';
        })
            .where((name) => name.isNotEmpty)
            .toList();

        // Rimuove i duplicati mantenendo l'ordinamento spaziale di Overpass
        return cityNames.toSet().toList();
      } else {
        throw Exception('Errore Overpass (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      print('OSM Overpass Error: $e');
      rethrow; // Rilanciamo l'errore per farlo gestire dal try/catch della HomePage
    }
  }
}