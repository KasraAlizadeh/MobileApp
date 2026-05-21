enum DestinationState {
  visited('visited'),
  notVisited('not_visited'),
  toBeVisited('to_be_visited');

  final String value;
  const DestinationState(this.value);

  static DestinationState fromString(String state) {
    return DestinationState.values.firstWhere(
      (e) => e.value == state,
      orElse: () => DestinationState.toBeVisited,
    );
  }
}

class Destination {
  final String id;
  final String name;
  final String image;
  final String description;
  final DestinationState state;

  Destination({
    required this.id,
    required this.name,
    required this.image,
    required this.description,
    required this.state,
  });

  factory Destination.fromFirestore(String id, Map<String, dynamic> data) {
    return Destination(
      id: id,
      name: data['name'] ?? 'No name',
      image: data['image'] ?? '',
      description: data['description'] ?? 'No description',
      state: DestinationState.fromString(data['state'] ?? 'to_be_visited'),
    );
  }
}
