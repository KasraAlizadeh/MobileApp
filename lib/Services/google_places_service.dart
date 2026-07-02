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

  Future<String> getPlaceDescription(String cityName) async {
    try {
      // Step 1: Search Wikipedia for the city specifically to avoid ambiguity (e.g., cheese vs town)
      final searchUrl = Uri.parse(
          'https://en.wikipedia.org/w/api.php'
          '?action=query'
          '&list=search'
          '&srsearch=${Uri.encodeComponent('$cityName city')}'
          '&format=json'
          '&utf8=1'
      );

      final searchResponse = await http.get(searchUrl);
      String? bestTitle;

      if (searchResponse.statusCode == 200) {
        final searchData = jsonDecode(searchResponse.body);
        final List searchResults = searchData['query']?['search'] ?? [];
        if (searchResults.isNotEmpty) {
          // The search result with 'city' appended usually yields the geographical entity
          bestTitle = searchResults[0]['title'];
        }
      }

      // Use the best title found, or fallback to the original cityName
      final finalTitle = (bestTitle ?? cityName).replaceAll(' ', '_');

      // Step 2: Fetch the summary for the identified title
      final summaryUrl = Uri.parse(
          'https://en.wikipedia.org/api/rest_v1/page/summary/$finalTitle'
      );

      final response = await http.get(summaryUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['extract'] ?? 'No available description';
      } else if (response.statusCode == 404) {
        return 'No description found for $cityName.';
      }
    } catch (e) {
      print('Wikipedia error: $e');
    }
    return 'Impossible to load the description';
  }

  Future<String?> getPlacePhotoUrl(String cityName) async {
    final searchUrl = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/findplacefromtext/json'
            '?input=${Uri.encodeComponent(cityName)}'
            '&inputtype=textquery'
            '&fields=photos'
            '&key=$_apiKey'
    );

    try {
      final searchResponse = await http.get(searchUrl);
      if (searchResponse.statusCode == 200) {
        final searchData = jsonDecode(searchResponse.body);
        final candidates = searchData['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final photos = candidates[0]['photos'] as List?;
          if (photos != null && photos.isNotEmpty) {
            final photoReference = photos[0]['photo_reference'];
            return 'https://maps.googleapis.com/maps/api/place/photo'
                '?maxwidth=800'
                '&photo_reference=$photoReference'
                '&key=$_apiKey';
          }
        }
      }
    } catch (e) {
      print('Error Fetching Photo: $e');
    }
    return null;
  }
}
