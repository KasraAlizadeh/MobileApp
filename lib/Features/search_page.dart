import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _aiSearchController = TextEditingController();
  bool _isAiLoading = false;
  String _aiResponseTitle = "AI Travel Assistant 🧠";
  List<String> _aiRecommendations = [
    "Type a destination below to get instant AI-curated spots, local dishes to try, and hidden gems!",
  ];

  Color _getMarkerColor(String? state) {
    switch (state) {
      case 'visited': return Colors.green;
      case 'to_be_visited': return Colors.orange;
      case 'canceled': return Colors.red;
      default: return Colors.grey;
    }
  }
//connecting google AI agent API for suggestions
  Future<void> _askAiAgent(String city) async {
    if (city.trim().isEmpty) return;

    setState(() {
      _isAiLoading = true; // Triggers the loading spinner safely
    });

    try {
      // Initialize the Gemini Model (here i go with gemini 2.5 model)

      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: 'AQ.Ab8RN6JgR-oHA7kFn0BhinVPtrmA0kdFsnpPGuUAbaIKKl0r4g',
      );

      // giving a testing prompt to generate a response
      final prompt = "You are an expert travel AI agent. Provide 3 quick, short bullet points for the city of $city. "
          "Point 1 must be a 'Must Visit' landmark. "
          "Point 2 must be a 'Hidden Gem' restaurant or area. "
          "Point 3 must be a 'Local Tip'. Keep each point under 15 words and start with emojis.";

      // using await to keep the app alive while waiting for the network response
      final response = await model.generateContent([Content.text(prompt)]);
      final String? responseText = response.text;

      if (responseText != null && responseText.isNotEmpty) {
        // here spliting the text response by line breaks to feed your clean list view
        List<String> rawLines = responseText.split('\n');
        List<String> cleanLines = rawLines.where((line) => line.trim().isNotEmpty).toList();

        setState(() {
          _aiResponseTitle = "AI Insights for ${city.trim()} ✨";
          _aiRecommendations = cleanLines;
          _isAiLoading = false;
        });
      } else {
        throw Exception("Empty response received from AI agent.");
      }

    } catch (err) {
      // 6. CATCH BLOCKS PREVENT CRASHES: If the network drops or the key fails, the UI handles it gracefully
      print("AI Agent Error: $err");
      setState(() {
        _aiResponseTitle = "AI Assistant Offline ❌";
        _aiRecommendations = [
          "Could not reach the travel agent right now.",
          "Error details: ${err.toString().split(':').last}",
          "Please verify your API key and internet connection."
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

        try {
          List<Location> locations = await locationFromAddress(cityName);
          if (locations.isNotEmpty) {
            final targetLocation = locations.first;
            localMarkers.add(
              Marker(
                point: LatLng(targetLocation.latitude, targetLocation.longitude),
                width: 80.0,
                height: 80.0,
                child: GestureDetector(
                  onTap: () {
                    // Clicking a pin automatically feeds that city to our AI Assistant!
                    _aiSearchController.text = cityName;
                    _askAiAgent(cityName);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Analyzing $cityName with AI...'),
                        backgroundColor: _getMarkerColor(state),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Icon(Icons.location_on, size: 45.0, color: _getMarkerColor(state)),
                ),
              ),
            );
          }
        } catch (e) {
          print("Could not locate '$cityName': $e");
        }
      }
    }
    return localMarkers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F4),
      appBar: AppBar(
        title: const Text('Journey Explorer & AI 🗺️'),
        backgroundColor: const Color(0xFF3D5A5A),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('journeys').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF3D5A5A)));
          }

          final documents = snapshot.data?.docs ?? [];

          return Column(
            children: [
              // 🗺️ SECTION 1: MAP VIEW (Takes 55% of the screen space)
              Expanded(
                flex: 55,
                child: FutureBuilder<List<Marker>>(
                  future: _buildMarkersFromTripNames(documents, context),
                  builder: (context, markerSnapshot) {
                    List<Marker> markers = markerSnapshot.data ?? [];
                    LatLng initialCenter = markers.isNotEmpty ? markers.first.point : const LatLng(41.9028, 12.4964);

                    return FlutterMap(
                      options: MapOptions(initialCenter: initialCenter, initialZoom: 4.0),
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

              // 🧠 SECTION 2: AI AGENT CONTROL PANEL (Takes 45% of the screen space)
              Expanded(
                flex: 45,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -3))],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // AI Header Text
                        Text(
                          _aiResponseTitle,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3D5A5A)),
                        ),
                        const SizedBox(height: 10),

                        // Scrollable AI Suggestions Container
                        Expanded(
                          child: _isAiLoading
                              ? const Center(child: CircularProgressIndicator(color: Color(0xFF3D5A5A)))
                              : ListView.builder(
                            itemCount: _aiRecommendations.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0F4F4),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _aiRecommendations[index],
                                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),

                        // AI Search Bar Input Box Row
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _aiSearchController,
                                decoration: InputDecoration(
                                  hintText: "Ask AI about any city...",
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFF3D5A5A), width: 2),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF3D5A5A),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.auto_awesome),
                              onPressed: () => _askAiAgent(_aiSearchController.text),
                            )
                          ],
                        ),
                      ],
                    ),
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