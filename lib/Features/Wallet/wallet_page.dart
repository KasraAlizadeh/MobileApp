import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'journey.dart';
import 'journey_details.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  // --- STATE VARIABLES ---
  List<Journey> _trips = [];
  bool _isLoading = true; // Shows a loading spinner while fetching data initially

  @override
  void initState() {
    super.initState();
    // Fetch all journeys from Firestore right when the screen opens
    _fetchJourneysFromFirestore();
  }

  // --- ONE-TIME FETCH LOGIC ---
  Future<void> _fetchJourneysFromFirestore() async {
    setState(() => _isLoading = true);
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('journeys').get();

      // Convert Firestore documents into Journey objects
      List<Journey> loadedTrips = snapshot.docs.map((doc) {
        return Journey.fromFirestore(doc); // Ensure your journey.dart has this factory!
      }).toList();

      setState(() {
        _trips = loadedTrips;
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching trips: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Journeys ✈️'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),

          // --- ADD BUTTON ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3D5A5A),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                // Navigate and wait to see if the user saved a new journey
                final bool? didSaveNewTrip = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const JourneyDetailsPage()),
                );

                // If the details page returns 'true', re-fetch the data!
                if (didSaveNewTrip == true) {
                  _fetchJourneysFromFirestore();
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF3D5A5A)))
                : _trips.isEmpty
                ? _buildEmptyState()
                : _buildTripList(),
          ),
        ],
      ),
    );
  }

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

  Widget _buildTripList() {
    return ListView.builder(
      itemCount: _trips.length,
      itemBuilder: (context, index) {
        bool isDark = index % 2 != 0;
        final journey = _trips[index];

        return Slidable(
          key: ValueKey(journey.id),
          endActionPane: ActionPane(
            extentRatio: 0.4,
            motion: const ScrollMotion(),
            children: [
              SlidableAction(
                onPressed: (context) => _showConfirmDialog(context, "Edit", index),
                backgroundColor: const Color(0xFF3D5A5A),
                foregroundColor: Colors.white,
                icon: Icons.edit,
                borderRadius: BorderRadius.circular(8),
              ),
              SlidableAction(
                onPressed: (context) => _showConfirmDialog(context, "Delete", index),
                backgroundColor: Colors.red.shade900,
                foregroundColor: Colors.white,
                icon: Icons.delete,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF3D5A5A) : const Color(0xFFD1D9D1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              title: Text(
                journey.name,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              ),
              onTap: () {
                // TODO: Navigate to view-only details page
                // e.g. Navigator.push(context, MaterialPageRoute(builder: (_) => JourneyViewPage(journey: journey)));
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
      builder: (BuildContext dialogContext) { // Renamed context to dialogContext for safety
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
                    ? "Are you sure you want to delete this trip and its files?"
                    : "Are you sure you want to edit this trip?",
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3D5A5A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text("Cancel", style: TextStyle(color: Colors.white)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDelete ? Colors.red.shade900 : const Color(0xFFD1D9D1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.pop(dialogContext); // Close the dialog
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

  // --- BACKGROUND DELETE LOGIC (Zero Cost UI Update) ---
  Future<void> _handleDelete(int index) async {
    Journey tripToDelete = _trips[index];

    // 1. Instantly remove from UI so it feels lightning fast for the user
    setState(() {
      _trips.removeAt(index);
    });

    try {
      // 2. Background Task: Delete all connected PDFs in Firebase Storage
      if (tripToDelete.pdfUrls.isNotEmpty) {
        for (String url in tripToDelete.pdfUrls) {
          await FirebaseStorage.instance.refFromURL(url).delete();
        }
      }

      // 3. Background Task: Delete the Firestore document
      await FirebaseFirestore.instance.collection('journeys').doc(tripToDelete.id).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Trip and files deleted successfully")),
        );
      }
    } catch (e) {
      // 4. If something fails (e.g. no internet), put it back in the list!
      if (mounted) {
        setState(() {
          _trips.insert(index, tripToDelete);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error deleting trip: $e")),
        );
      }
    }
  }

  // --- EDIT LOGIC ---
  Future<void> _handleEdit(int index) async {
    final bool? didUpdate = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JourneyDetailsPage(existingJourney: _trips[index]),
      ),
    );

    // If the edit page successfully saved, re-fetch to get the fresh data
    if (didUpdate == true) {
      _fetchJourneysFromFirestore();
    }
  }
}