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
    final searchUrl = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/findplacefromtext/json' //we send a text and want an answer in json
            '?input=${Uri.encodeComponent(cityName)}' //the input is codified to be read by the browser
            '&inputtype=textquery' //the input is a generic text string
            '&fields=place_id' //we only want the place_id
            '&key=$_apiKey'
    );

    try {
      final searchResponse = await http.get(searchUrl); //calling searchUrl
      print("");
      if (searchResponse.statusCode == 200) { //if the answer is correct...
        final searchData = jsonDecode(searchResponse.body);
        final candidates = searchData['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final placeId = candidates[0]['place_id'];

          final detailsUrl = Uri.parse( //once the id has been found, let's create a new address
              'https://maps.googleapis.com/maps/api/place/details/json'
                  '?place_id=$placeId'
                  '&fields=editorial_summary'
                  '&key=$_apiKey'
          );

          final detailsResponse = await http.get(detailsUrl); //second call (to obtain the summary)
          if (detailsResponse.statusCode == 200) {
            final detailsData = jsonDecode(detailsResponse.body);
            final summary = detailsData['result']?['editorial_summary']?['overview'];
            return summary ?? 'No available description for this city';
          }
        }
      }
    } catch (e) {
      print('Error Fetching Description: $e');
    }
    return 'Impossible to fetch the description';
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

  Future<List<String>> getNearbyCities(double lat, double lng) async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
            '?location=$lat,$lng'
            '&rankby=distance'
            '&type=locality'
            '&key=$_apiKey'
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List results = data['results'] ?? [];

        return results
            .map<String>((result) => result['name'] as String)
            .where((name) => name.isNotEmpty)
            .toSet()
            .take(10)
            .toList();
      }
    } catch (e) {
      print('Error Fetching Nearby Cities: $e');
    }
    return [];
  }
}