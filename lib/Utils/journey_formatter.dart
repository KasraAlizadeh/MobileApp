import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class JourneyFormatter {
  static final DateFormat uiDateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat dbDateFormat = DateFormat('yyyy-MM-dd');

  static List<String> extractText(List<TextEditingController> controllers) {
    return controllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
  }

  static List<Map<String, dynamic>> extractRows(List<Map<String, dynamic>> rows) {
    return rows.map((row) {
      final Map<String, dynamic> cleanRow = {};
      row.forEach((key, value) {
        if (value is TextEditingController) {
          cleanRow[key] = value.text.trim();
        } else {
          cleanRow[key] = value;
        }
      });
      return cleanRow;
    }).toList();
  }

  static String convertUiToDbDate(String uiDate) {
    if (uiDate.isEmpty) return '';
    try {
      DateTime parsed = uiDateFormat.parse(uiDate);
      return dbDateFormat.format(parsed);
    } catch (_) {
      return uiDate;
    }
  }
}