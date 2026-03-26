import 'package:flutter/material.dart';
import 'journey.dart';
import 'journey_details.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
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
          "Are you boring?, letzzz go somewhere! 🌍",
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
        bool isDark = index % 2 != 0;

        // --- WRAP EVERYTHING IN SLIDABLE ---
        return Slidable(
          key: ValueKey(_trips[index].id), // Unique key for each trip
          endActionPane: ActionPane(
            extentRatio: 0.4, // Limits how far it slides (adjust as needed)
            motion: const ScrollMotion(),
            children: [
              // EDIT BUTTON
              SlidableAction(
                onPressed: (context) => _showConfirmDialog(context, "Edit", index),
                backgroundColor: const Color(0xFF3D5A5A),
                foregroundColor: Colors.white,
                icon: Icons.edit,
                borderRadius: BorderRadius.circular(8),
              ),
              // DELETE BUTTON
              SlidableAction(
                onPressed: (context) => _showConfirmDialog(context, "Delete", index),
                backgroundColor: Colors.red.shade900,
                foregroundColor: Colors.white,
                icon: Icons.delete,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          ),

          // This is the actual tile that users see before sliding
          child: Container(
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
              onTap: () {
                // TODO: Navigate to view details page when clicked
              },
            ),
          ),
        );
      },
    );
  }
  void _showConfirmDialog(BuildContext context, String action, int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        bool isDelete = action == "Delete";

        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Text(
                isDelete
                    ? "Are you sure you want to delete this trip?"
                    : "Are you sure you want to edit this trip?",
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // --- CANCEL BUTTON ---
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3D5A5A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel", style: TextStyle(color: Colors.white)),
                  ),

                  // --- ACTION BUTTON (Edit or Delete) ---
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDelete ? Colors.red.shade900 : const Color(0xFFD1D9D1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.pop(context); // Close the dialog
                      if (isDelete) {
                        _handleDelete(index);
                      } else {
                        _handleEdit(index);
                      }
                    },
                    child: Text(
                      action,
                      style: TextStyle(color: isDelete ? Colors.white : Colors.black),
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }
// DELETE LOGIC
  void _handleDelete(int index) {
    String tripId = _trips[index].id;

    setState(() {
      _trips.removeAt(index);
    });

    // TODO: Add Firebase deletion here
    // FirebaseFirestore.instance.collection('journeys').doc(tripId).delete();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Trip deleted successfully")),
    );
  }

// EDIT LOGIC
  void _handleEdit(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JourneyDetailsPage(
          existingJourney: _trips[index], // Pass the existing trip to the page
        ),
      ),
    ).then((updatedTrip) {
      if (updatedTrip != null) {
        setState(() {
          _trips[index] = updatedTrip; // Update the list with edited info
        });
      }
    });
  }
}