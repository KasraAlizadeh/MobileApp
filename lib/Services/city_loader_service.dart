import 'dart:convert';
import 'package:flutter/services.dart';

class CityLoaderService {
  static Future<List<String>> loadCities() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/data/it.json');
      final List<dynamic> jsonResponse = jsonDecode(jsonString);
      final Set<String> uniqueCities = jsonResponse
          .map((item) => item['city'].toString().trim())
          .where((cityName) => cityName.isNotEmpty)
          .toSet();
      return uniqueCities.toList()..sort();
    } catch (e) {
      return [];
    }
  }
}