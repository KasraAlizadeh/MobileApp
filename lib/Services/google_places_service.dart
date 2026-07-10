import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import '../constants.dart';

class GooglePlacesService {
  final String _apiKey = googleMapsApiKey;

  // In-memory cache to store fetched image URLs and prevent redundant network requests
  final Map<String, String?> _photoUrlCache = {};

  Future<List<Map<String, dynamic>>?> getSuggestions(String input) async {
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
      print('Autocomplete Error: $e');
    }
    return [];
  }

  Future<String> getPlaceDescription(String cityName) async {
    try {
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
          bestTitle = searchResults[0]['title'];
        }
      }

      final finalTitle = (bestTitle ?? cityName).replaceAll(' ', '_');

      final summaryUrl = Uri.parse('https://en.wikipedia.org/api/rest_v1/page/summary/$finalTitle');
      final response = await http.get(summaryUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['extract'] ?? 'No available description';
      } else if (response.statusCode == 404) {
        return 'No description found for $cityName.';
      }
    } catch (e) {
      print('Wikipedia Error: $e');
    }
    return 'Impossible to load the description';
  }

  Future<Map<String, String>> getCityStats(String cityName) async {
    String stats = "";
    StringBuffer buffer = StringBuffer();

    try {
      List<Location> locations = await locationFromAddress('$cityName, Italy');
      if (locations.isNotEmpty) {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          locations.first.latitude,
          locations.first.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          if (p.subAdministrativeArea != null) buffer.writeln("🏛️ Province: ${p.subAdministrativeArea}");
          if (p.administrativeArea != null) buffer.writeln("🗺️ Region: ${p.administrativeArea}");
        }
      }
    } catch (_) {}

    try {
      final searchUrl = Uri.parse(
          'https://en.wikipedia.org/w/api.php'
              '?action=query'
              '&list=search'
              '&srsearch=${Uri.encodeComponent('$cityName city')}'
              '&format=json'
      );
      final searchRes = await http.get(searchUrl);
      final searchData = jsonDecode(searchRes.body);
      final List searchResults = searchData['query']?['search'] ?? [];

      if (searchResults.isNotEmpty) {
        final String title = searchResults[0]['title'];
        final propUrl = Uri.parse(
            'https://en.wikipedia.org/w/api.php'
                '?action=query'
                '&prop=pageprops'
                '&titles=${Uri.encodeComponent(title)}'
                '&format=json'
        );
        final propRes = await http.get(propUrl);
        final Map pages = jsonDecode(propRes.body)['query']['pages'];
        final wikidataId = pages.values.first['pageprops']?['wikibase_item'];

        if (wikidataId != null) {
          final dataUrl = Uri.parse(
              'https://www.wikidata.org/w/api.php'
                  '?action=wbgetentities'
                  '&ids=$wikidataId'
                  '&props=claims'
                  '&format=json'
          );

          final dataRes = await http.get(dataUrl);
          final entities = jsonDecode(dataRes.body)['entities'];
          if (entities != null && entities[wikidataId] != null) {
            final claims = entities[wikidataId]['claims'];
            if (claims != null) {
              String? getClaimValue(List? claimList) {
                if (claimList == null || claimList.isEmpty) return null;
                for (var claim in claimList.reversed) {
                  final datavalue = claim['mainsnak']?['datavalue']?['value'];
                  if (datavalue != null && datavalue['amount'] != null) {
                    return datavalue['amount'].toString();
                  }
                }
                return null;
              }

              String? popStr = getClaimValue(claims['P1082']);
              String? areaStr = getClaimValue(claims['P2046']);
              double? p, a;

              if (popStr != null) {
                p = double.tryParse(popStr.replaceAll('+', ''));
                if (p != null) {
                  final formattedPop = p.toInt().toString().replaceAllMapped(
                      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                          (Match m) => '${m[1]},');
                  buffer.writeln("👥 Population: $formattedPop");
                }
              }

              if (areaStr != null) {
                a = double.tryParse(areaStr.replaceAll('+', ''));
                if (a != null) buffer.writeln("📐 Surface: ${a.toStringAsFixed(2)} km²");
              }

              if (p != null && a != null && a > 0) {
                buffer.writeln("🏙️ Density: ${(p / a).toStringAsFixed(2)} pop/km²");
              }
            }
          }
        }
      }
    } catch (e) {
      print("Stats Error: $e");
    }

    stats = buffer.toString().trim();
    if (stats.isEmpty) stats = "No detailed information found for $cityName.";

    return {'stats': stats, 'geo': ''};
  }

  Future<String?> getPlacePhotoUrl(String cityName) async {
    final String lookupKey = cityName.trim().toLowerCase();

    if (_photoUrlCache.containsKey(lookupKey)) {
      return _photoUrlCache[lookupKey];
    }

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
            final finalUrl = 'https://maps.googleapis.com/maps/api/place/photo'
                '?maxwidth=800'
                '&photo_reference=$photoReference'
                '&key=$_apiKey';

            _photoUrlCache[lookupKey] = finalUrl;
            return finalUrl;
          }
        }
      }
    } catch (e) {
      print('Error Fetching Photo: $e');
    }

    _photoUrlCache[lookupKey] = null;
    return null;
  }

  void clearCache() {
    _photoUrlCache.clear();
  }

  /// Checks if the photo URL for a specific city is already in memory
  bool isPhotoCached(String lowercaseCityName) {
    return _photoUrlCache.containsKey(lowercaseCityName);
  }

  /// Synchronously gets the cached photo URL
  String? getCachedPhotoUrl(String lowercaseCityName) {
    return _photoUrlCache[lowercaseCityName];
  }
}