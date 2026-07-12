import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app/Models/journey.dart';

void main() {
  group('Journey Model Unit Tests', () {
    test('Fills properties cleanly from manual constructor initialization', () {
      final trip = Journey(
        id: '123',
        userId: 'user_dev',
        name: 'Explore Rome',
        type: 'Vacation',
        startDate: '2026-07-12',
        endDate: '2026-07-20',
        destinations: ['Roma'],
        transportation: [],
        accommodation: [],
        activities: [],
        notes: 'Pack light!',
        pdfUrls: ['', '', ''],
        imageUrls: [],
        state: 'to_be_visited',
      );

      expect(trip.id, '123');
      expect(trip.name, 'Explore Rome');
      expect(trip.notes, 'Pack light!');
    });
  });
}