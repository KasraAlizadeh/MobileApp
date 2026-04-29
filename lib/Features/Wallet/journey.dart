class Journey {
  final String id;
  final String name;
  final String? destination;
  final String? startDate;
  final String? endDate;
  final String? type; // e.g., Business, Vacation

  Journey({
    required this.id,
    required this.name,
     this.destination,
    this.startDate,
    this.endDate,
    this.type,
  });

  get destinations => null;

  String? operator [](String other) {}
}