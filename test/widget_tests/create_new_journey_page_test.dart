import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app/Features/Wallet/journey_details.dart';

void main() {
  Widget wrap(Widget w) => MaterialApp(home: Scaffold(body: w));

  group('Create Screens Widget Tests', () {
    testWidgets('Renders empty creation state form layouts completely', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const JourneyDetailsPage(existingJourney: null, isReadOnly: false)));
      await tester.pump();
      expect(find.text('Save'), findsOneWidget);
    });
  });
}