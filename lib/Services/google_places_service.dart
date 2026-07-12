import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';
import '../constants.dart';

class GooglePlacesService {
  final String _apiKey = googleMapsApiKey;

  static final Map<String, String> _photoUrlCache = {};

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

  Future<String> getCityStats(String cityName) async {
    String regionInfo = "";

    try {
      List<Location> locations = await locationFromAddress(cityName).timeout(const Duration(seconds: 2));
      if (locations.isNotEmpty) {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          locations.first.latitude,
          locations.first.longitude,
        ).timeout(const Duration(seconds: 2));

        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final region = p.administrativeArea ?? "";
          final province = p.subAdministrativeArea ?? "";
          if (region.isNotEmpty) {
            regionInfo += "🗺️ Region: $region\n";
          }
          if (province.isNotEmpty) {
            regionInfo += "📍 Province: $province\n";
          }
        }
      }
    } catch (e) {
      print("Geocoding service error: $e");
    }

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
      
      if (searchResults.isEmpty) {
        return regionInfo.isNotEmpty ? regionInfo + "No detailed stats found." : "No data found for $cityName.";
      }
      
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

      if (wikidataId == null) {
        return regionInfo + "No technical data found.";
      }

      final dataUrl = Uri.parse(
          'https://www.wikidata.org/w/api.php'
          '?action=wbgetentities'
          '&ids=$wikidataId'
          '&props=claims'
          '&format=json'
      );

      final dataRes = await http.get(dataUrl);
      final entities = jsonDecode(dataRes.body)['entities'];
      if (entities == null || entities[wikidataId] == null) return regionInfo + "Data error.";

      final claims = entities[wikidataId]['claims'];
      if (claims == null) return regionInfo + "No claims found.";

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

      if (popStr == null && areaStr == null) {
        return regionInfo + "Detailed stats are empty.";
      }

      StringBuffer buffer = StringBuffer();
      buffer.write(regionInfo);

      double? p;
      double? a;

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
        if (a != null) {
          buffer.writeln("📐 Surface: ${a.toStringAsFixed(2)} km²");
        }
      }

      if (p != null && a != null && a > 0) {
        double dens = p / a;
        buffer.writeln("🏙️ Density: ${dens.toStringAsFixed(2)} ab/km²");
      }

      return buffer.toString().trim();
    } catch (e) {
      print("Stats Wikidata error: $e");
    }
    return regionInfo + "Could not retrieve detailed statistics.";
  }

  Future<String?> getPlacePhotoUrl(String cityName) async {
    final cleanCityName = cityName.trim().toLowerCase();

    // 1. Check in-memory cache
    if (_photoUrlCache.containsKey(cleanCityName)) {
      return _photoUrlCache[cleanCityName];
    }

    // 2. Check persistent cache (SharedPreferences)
    final prefs = await SharedPreferences.getInstance();
    final cachedUrl = prefs.getString('photo_url_$cleanCityName');
    if (cachedUrl != null) {
      _photoUrlCache[cleanCityName] = cachedUrl;
      return cachedUrl;
    }

    // 3. If not cached, fetch from Google
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
            final url = 'https://maps.googleapis.com/maps/api/place/photo'
                '?maxwidth=600'
                '&photo_reference=$photoReference'
                '&key=$_apiKey';
            
            // Save to caches
            _photoUrlCache[cleanCityName] = url;
            await prefs.setString('photo_url_$cleanCityName', url);
            
            return url;
          }
        }
      }
    } catch (e) {
      print('Error Fetching Photo: $e');
    }
    return null;
  }
}
