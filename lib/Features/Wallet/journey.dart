import 'package:cloud_firestore/cloud_firestore.dart';

class Journey {
  final String id;
  final String userId;
  final String name;
  final String? type;
  final String? startDate;
  final String? endDate;
  final List<String> destinations;
  final List<Map<String, dynamic>> transportation;
  final List<Map<String, dynamic>> accommodation;
  final List<Map<String, dynamic>> activities;
  final String? notes;
  final List<String> pdfUrls;
  // Helper to safely get a URL at a specific position
  String? getUrlAt(int index) {
    if (index >= 0 && index < pdfUrls.length) {
      return pdfUrls[index];
    }
    return null;
  }
  final String? state;

  Journey({
    required this.id,
    required this.userId,
    required this.name,
    this.type,
    this.startDate,
    this.endDate,
    this.destinations = const [],
    this.transportation = const [],
    this.accommodation = const [],
    this.activities = const [],
    this.notes,
    this.pdfUrls = const [],
    this.state
  });

  factory Journey.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Journey(
      id: doc.id,
        userId: data['userId'] ?? '',
      name: data['name'] ?? 'Unnamed Journey',
      type: data['travelType'],
      startDate: data['startDate'],
      endDate: data['endDate'],
      destinations: List<String>.from(data['destinations'] ?? []),
      transportation: List<Map<String, dynamic>>.from(data['transportation'] ?? []),
      accommodation: List<Map<String, dynamic>>.from(data['accommodation'] ?? []),
      activities: List<Map<String, dynamic>>.from(data['activities'] ?? []),
      notes: data['notes'],
      pdfUrls: List<String>.from(data['pdfUrls'] ?? []),
      state: data['state'] ?? 'to_be_visited'

    );
  }
}