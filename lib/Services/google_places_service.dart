import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

class GooglePlacesService {

  final String _apiKey = googleMapsApiKey;

  Future<List<Map<String, dynamic>>> getSuggestions(String input) async {
    if (input.trim().isEmpty) return [];

    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
            '?input=${Uri.encodeComponent(input)}'
            '&types=(cities)'
            '&components=country:it'
            '&key=$_apiKey'
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List predictions = data['predictions'] ?? [];

        return predictions.map<Map<String, dynamic>>((p) => {
          'description': p['description'],
          'placeId': p['place_id'],
        }).toList();
      }
    } catch (e) {
      print('Errore Autocomplete: $e');
    }
    return [];
  }
}