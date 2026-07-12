import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

String apiKey = dotenv.env['GEMINI_API_KEY'] ?? 'Key not found';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  static final ValueNotifier<String?> triggeredCitySearchNotifier = ValueNotifier<String?>(null);
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _aiSearchController = TextEditingController();
  final DraggableScrollableController _sheetController = DraggableScrollableController();


  late final Stream<QuerySnapshot> _userJourneysStream;

  final Map<String, LatLng> _geocodingCache = {};

  bool _isAiLoading = false;
  String _aiResponseTitle = "AI Travel Assistant 🧠";
  String _selectedCategory = 'All';
  double _currentSheetSize = 0.35;
  final List<Map<String, dynamic>> _categories = [
    {'id': 'All', 'label': 'Overview', 'icon': Icons.explore},
    {'id': 'Food', 'label': 'Local Food', 'icon': Icons.restaurant},
    {'id': 'History', 'label': 'Historic', 'icon': Icons.account_balance},
    {'id': 'Adventure', 'label': 'Adventure', 'icon': Icons.terrain},
    {'id': 'Stays', 'label': 'Top Stays', 'icon': Icons.hotel},
  ];
  List<Map<String, String>> _allRecommendations = [
    {
      'category': 'All',
      'emoji': '🗺️',
      'title': 'Welcome to Journey Explorer',
      'body': 'Tap a pin or enter a city to unlock local dishes, top restaurants, landmarks, hidden adventures, and accommodation hubs!'
    }
  ];

  @override
  void initState() {
    super.initState();
    SearchPage.triggeredCitySearchNotifier.addListener(_handleIncomingDeepLinkSearch);

    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _userJourneysStream = FirebaseFirestore.instance
        .collection('journeys')
        .where('userId', isEqualTo: currentUid)
        .snapshots();
  }

  Color _getMarkerColor(String? state) {
    switch (state) {
      case 'visited': return Colors.green;
      case 'to_be_visited': return Colors.orange;
      case 'canceled': return Colors.red;
      default: return Colors.grey;
    }
  }
  Future<void> _askAiAgent(String city) async {
    if (city.trim().isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a city name first.")),
      );
      return;
    }

    setState(() {
      _isAiLoading = true;
    });

    _sheetController.animateTo(
      0.80,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );

    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
      );

      final prompt = "You are an expert commercial travel travel agent. Provide a detailed guide for $city. "
          "You must generate exactly 7 points following this precise tokenization syntax (no headers, no markdown bolding):\n"
          "All | 🏛️ | Must Visit | Short description of top landmark\n"
          "All | 💎 | Hidden Gem | Short description of a unique local spot\n"
          "Food | 🍝 | Local Dishes | List 2 typical local foods to try\n"
          "Food | 🍴 | Best Restaurant | Name a top rated dining venue and specialty\n"
          "History | 📜 | History Spot | Name a notable historic site or monument\n"
          "Adventure | 🎒 | Adventure Action | Mention an outdoor activity or exciting tour option\n"
          "Stays | 🏨 | Recommended Stay | Mention the best neighborhood or top-rated hotel option\n"
          "Keep each description under 15 words.";

      final response = await model.generateContent([Content.text(prompt)]);
      final String? responseText = response.text;

      if (!mounted) return;

      if (responseText != null && responseText.isNotEmpty) {
        List<String> rawLines = responseText.split('\n');
        List<Map<String, String>> parsingList = [];

        for (var line in rawLines) {
          if (!line.contains('|')) continue;
          List<String> segments = line.split('|');
          if (segments.length >= 4) {
            parsingList.add({
              'category': segments[0].trim(),
              'emoji': segments[1].trim(),
              'title': segments[2].trim(),
              'body': segments[3].trim(),
            });
          }
        }

        setState(() {
          _aiResponseTitle = "AI Curation for ${city.trim()} ✨";
          _selectedCategory = 'All';
          _allRecommendations = parsingList.isNotEmpty ? parsingList : [
            {'category': 'All', 'emoji': '✨', 'title': 'Guide Generated', 'body': responseText.trim()}
          ];
          _isAiLoading = false;
        });
      } else {
        throw Exception("Empty payload response metadata state.");
      }
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _aiResponseTitle = "AI Assistant Offline ❌";
        _allRecommendations = [
          {'category': 'All', 'emoji': '⚠️', 'title': 'Connection Error', 'body': 'Could not reach the travel agent right now.'},
          {'category': 'All', 'emoji': '🔧', 'title': 'Details', 'body': err.toString().split(':').last}
        ];
        _isAiLoading = false;
      });
    }
  }
  Future<List<Marker>> _buildMarkersFromTripNames(List<QueryDocumentSnapshot> docs, BuildContext context) async {
    List<Marker> localMarkers = [];
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final String? state = data['state'];
      final List<dynamic> destinationList = data['destinations'] ?? [];

      for (var destination in destinationList) {
        final String cityName = destination.toString().trim();
        if (cityName.isEmpty) continue;

        if (_geocodingCache.containsKey(cityName)) {
          final cachedPoint = _geocodingCache[cityName]!;
          localMarkers.add(_createMapMarker(cityName, cachedPoint, state));
          continue;
        }

        try {
          List<Location> locations = await locationFromAddress(cityName).timeout(
            const Duration(seconds: 2),
            onTimeout: () => [],
          );
          if (locations.isNotEmpty) {
            final targetLocation = locations.first;
            final point = LatLng(targetLocation.latitude, targetLocation.longitude);

            _geocodingCache[cityName] = point;
            localMarkers.add(_createMapMarker(cityName, point, state));
          }
        } catch (e) {
          debugPrint("Location error for $cityName: $e");
        }
      }
    }
    return localMarkers;
  }

  Marker _createMapMarker(String cityName, LatLng point, String? state) {
    return Marker(
      point: point,
      width: 50.0,
      height: 50.0,
      child: GestureDetector(
        onTap: () {
          _aiSearchController.text = cityName;
          _askAiAgent(cityName);
        },
        child: Icon(Icons.location_on, size: 40.0, color: _getMarkerColor(state)),
      ),
    );
  }
  @override
  void dispose() {
    SearchPage.triggeredCitySearchNotifier.removeListener(_handleIncomingDeepLinkSearch);
    super.dispose();
  }

  void _handleIncomingDeepLinkSearch() async {
    final cityName = SearchPage.triggeredCitySearchNotifier.value;
    if (cityName == null || cityName.isEmpty) return;
    SearchPage.triggeredCitySearchNotifier.value = null;
    print("Executing Deep-Link AI Search parameters for city target: $cityName");
    _aiSearchController.text = cityName;
    await _askAiAgent(cityName);

  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF4F6F4),
      appBar: AppBar(
        title: const Text('Journey Explorer', overflow: TextOverflow.ellipsis),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _userJourneysStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF3D5A5A)));
          }

          final documents = snapshot.data?.docs ?? [];

          return Stack(
            children: [
              // Map View Layer
              Positioned.fill(
                child: FutureBuilder<List<Marker>>(
                  future: _buildMarkersFromTripNames(documents, context),
                  builder: (context, markerSnapshot) {
                    List<Marker> markers = markerSnapshot.data ?? [];
                    LatLng initialCenter = markers.isNotEmpty ? markers.first.point : const LatLng(41.9028, 12.4964);

                    return FlutterMap(
                      options: MapOptions(initialCenter: initialCenter, initialZoom: 4.5),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.travel_app',
                        ),
                        MarkerLayer(markers: markers),
                      ],
                    );
                  },
                ),
              ),

              // Swipeable AI Sheet Panel
              SafeArea(
                top: false, left: false, right: false, bottom: true,
                child: NotificationListener<DraggableScrollableNotification>(
                  onNotification: (notification) {
                    _currentSheetSize = notification.extent;
                    return true;
                  },
                  child: DraggableScrollableSheet(
                    controller: _sheetController,
                    initialChildSize: _currentSheetSize,
                    minChildSize: 0.35,
                    maxChildSize: 0.85,
                    snap: true,
                    builder: (context, scrollController) {
                      final filteredList = _allRecommendations.where((item) {
                        if (_selectedCategory == 'All') return true;
                        return item['category'] == _selectedCategory;
                      }).toList();

                      return Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, -2))],
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              bottom: 80,
                              child: ListView(
                                controller: scrollController,
                                padding: const EdgeInsets.only(top: 12, bottom: 16),
                                children: [
                                  Center(
                                    child: Container(
                                      width: 40, height: 5,
                                      decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    child: Text(
                                      _aiResponseTitle,
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  SizedBox(
                                    height: 38,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.symmetric(horizontal: 14),
                                      itemCount: _categories.length,
                                      itemBuilder: (context, idx) {
                                        final cat = _categories[idx];
                                        bool isSelected = _selectedCategory == cat['id'];
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                          child: ChoiceChip(
                                            showCheckmark: false,
                                            avatar: Icon(cat['icon'], size: 16, color: isSelected ? Colors.white : const Color(0xFF3D5A5A)),
                                            label: Text(cat['label'], style: Theme.of(context).textTheme.titleSmall),
                                            selected: isSelected,
                                            selectedColor: const Color(0xFF3D5A5A),
                                            onSelected: (bool selected) {
                                              setState(() {
                                                _selectedCategory = cat['id'];
                                              });
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 16),
                                    child: Divider(height: 24),
                                  ),

                                  if (_isAiLoading)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 40),
                                      child: Center(child: CircularProgressIndicator(color: Color(0xFF3D5A5A))),
                                    )
                                  else if (filteredList.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 40),
                                      child: Center(
                                        child: Text(
                                          "No recommendations here. Tap another tab!",
                                          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                                        ),
                                      ),
                                    )
                                  else
                                    ...filteredList.map((item) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                        child: Card(
                                          elevation: 0,
                                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          child: ListTile(
                                            leading: Text(item['emoji'] ?? '📍', style: const TextStyle(fontSize: 24)),
                                            title: Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                            subtitle: Padding(
                                              padding: const EdgeInsets.only(top: 4.0),
                                              child: Text(item['body'] ?? '', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                    ),
                                ],
                              ),
                            ),

                            Positioned(
                              left: 0, right: 0, bottom: 0,
                              child: Container(
                                color: Theme.of(context).scaffoldBackgroundColor,
                                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _aiSearchController,
                                        decoration: InputDecoration(
                                          hintText: "Ask AI about any city...",
                                          fillColor: Theme.of(context).cardColor,
                                          filled: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    FloatingActionButton.small(
                                      backgroundColor: const Color(0xFF3D5A5A),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      onPressed: () => _askAiAgent(_aiSearchController.text),
                                      child: const Icon(Icons.auto_awesome),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}