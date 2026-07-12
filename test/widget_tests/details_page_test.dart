import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app/Models/journey.dart';
import 'package:travel_app/Features/Wallet/journey_details.dart';

void main() {
  Widget wrap(Widget w) => MaterialApp(home: Scaffold(body: w));

  group('Detail Screens Widget Tests', () {
    testWidgets('Renders existing journey data inside ReadOnly layout boundaries', (WidgetTester tester) async {
      final mockJourney = Journey(
        id: 'trip_111',
        userId: 'traveller_456',
        name: 'Historic Rome Tour',
        type: 'Vacation',
        startDate: '2026-09-01',
        endDate: '2026-09-10',
        destinations: ['Roma'],
        transportation: [],
        accommodation: [],
        activities: [],
        notes: '',
        pdfUrls: ['', '', ''],
        imageUrls: [],
        state: 'to_be_visited',
      );

      await tester.pumpWidget(wrap(JourneyDetailsPage(existingJourney: mockJourney, isReadOnly: true)));
      await tester.pump();
      expect(find.text('Edit Trip'), findsOneWidget);
    });
  });
}