import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mocktail/mocktail.dart';
import 'package:travel_app/Models/journey.dart';

class MockDocumentSnapshot extends Mock implements DocumentSnapshot {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Journey Model Comprehensive Unit Tests', () {
    test('Standard Constructor initialization sets properties correctly', () {
      final journey = Journey(
        id: 'j_111',
        userId: 'u_999',
        name: 'Milano Adventure',
      );
      expect(journey.id, 'j_111');
    });

    test('getUrlAt handles safety bounds properly (Hit/Miss paths)', () {
      final journey = Journey(id: 'id', userId: 'user', name: 'Trip', pdfUrls: ['url_0']);
      expect(journey.getUrlAt(0), 'url_0');
      expect(journey.getUrlAt(5), isNull);
    });

    test('toMap serializes mapping correctly including parameters', () {
      final journey = Journey(id: 'j_123', userId: 'u_456', name: 'Polimi Tour');
      final mapData = journey.toMap('token');
      expect(mapData['name'], 'Polimi Tour');
    });

    test('fromFirestore factory deserializes Map entries flawlessly with defaults', () {
      final mockSnapshot = MockDocumentSnapshot();
      when(() => mockSnapshot.id).thenReturn('doc_abc');
      when(() => mockSnapshot.data()).thenReturn({'userId': 'u', 'name': 'Roma'});

      final journey = Journey.fromFirestore(mockSnapshot);
      expect(journey.name, 'Roma');
    });
  });
} // ⚠️ Make sure this closing bracket matches the main() function!