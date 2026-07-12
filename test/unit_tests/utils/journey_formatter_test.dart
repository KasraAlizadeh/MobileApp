import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app/Utils/journey_formatter.dart';

void main() {
  group('JourneyFormatter Logic Unit Tests', () {
    test('extractText cleans and filters empty controllers cleanly', () {
      final c1 = TextEditingController(text: '  Milano  ');
      final c2 = TextEditingController(text: '');
      final c3 = TextEditingController(text: 'Roma');

      final result = JourneyFormatter.extractText([c1, c2, c3]);
      expect(result, ['Milano', 'Roma']);
    });

    test('convertUiToDbDate transforms dates or falls back smoothly on errors', () {
      // Test successful bidirectional formatting conversion
      final dbDate = JourneyFormatter.convertUiToDbDate('12/07/2026');
      expect(dbDate, '2026-07-12');

      // Test bad string handling fallback format loop
      final fallback = JourneyFormatter.convertUiToDbDate('malformed_date_string');
      expect(fallback, 'malformed_date_string');
    });

    test('extractRows processes text controller maps successfully', () {
      final rowMap = {
        'mode': 'Airline',
        'controller': TextEditingController(text: ' AZ402 ')
      };

      final result = JourneyFormatter.extractRows([rowMap]);
      expect(result.first['controller'], 'AZ402');
      expect(result.first['mode'], 'Airline');
    });
  });
}