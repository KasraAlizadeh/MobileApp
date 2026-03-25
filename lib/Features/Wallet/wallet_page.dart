import 'package:flutter/material.dart';
import 'journey.dart';
import 'journey_details.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  // This list will hold our data
  List<Journey> _trips = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Journeys ✈️'),
        //centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),

          // --- ADD BUTTON ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3D5A5A), // Dark Green from your image
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
                onPressed: () async {
                  // Navigate and wait for the result
                  final String? newTripName = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const JourneyDetailsPage()),
                  );

                  // If we got a name back, add it to our list!
                  if (newTripName != null && newTripName.isNotEmpty) {
                    setState(() {
                      _trips.add(Journey(id: DateTime.now().toString(), name: newTripName));
                    });
                  }
                },
              child: const Text('Add a new journey', style: TextStyle(color: Colors.white)),
            ),
          ),

          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("My existing Trips", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),

          // --- THE LIST OR EMPTY MESSAGE ---
          Expanded(
            child: _trips.isEmpty
                ? _buildEmptyState()
                : _buildTripList(),
          ),
        ],
      ),
    );
  }

  // A helper method for the empty text you requested
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Text(
          "Still there is no any trips, letz go somewhere! 🌍",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600], fontSize: 16, fontStyle: FontStyle.italic),
        ),
      ),
    );
  }

  // A helper method to build the scrollable list
  Widget _buildTripList() {
    return ListView.builder(
      itemCount: _trips.length,
      itemBuilder: (context, index) {
        bool isDark = index % 2 != 0; // Alternating colors like your design
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF3D5A5A) : const Color(0xFFD1D9D1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            title: Text(
              _trips[index].name,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
          ),
        );
      },
    );
  }

}