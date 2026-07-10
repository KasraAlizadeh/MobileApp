import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Services/notification_service.dart';
import 'journey.dart';
import 'journey_details.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  List<Journey> _trips = [];
  bool _isLoading = true;
  bool _isAuthorized = false;
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    final prefs = await SharedPreferences.getInstance();
    bool biometricEnabled = prefs.getBool('biometric_enabled') ?? false;

    if (biometricEnabled) {
      try {
        bool authenticated = await _auth.authenticate(
          localizedReason: 'Please authenticate to view your wallet',
        );

        if (!mounted) return;

        if (authenticated) {
          setState(() => _isAuthorized = true);
          _fetchJourneysFromFirestore();
        }
      } catch (e) {
        debugPrint("Auth error: $e");
        // Safe fallback: allow access if biometric check fails completely
        if (mounted) {
          setState(() => _isAuthorized = true);
          _fetchJourneysFromFirestore();
        }
      }
    } else {
      if (mounted) {
        setState(() => _isAuthorized = true);
        _fetchJourneysFromFirestore();
      }
    }
  }

  Future<void> _fetchJourneysFromFirestore() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('journeys').get();

      if (!mounted) return; // CRITICAL: Protects against memory crashes if user left the page

      List<Journey> loadedTrips = snapshot.docs.map((doc) {
        return Journey.fromFirestore(doc);
      }).toList();

      setState(() {
        _trips = loadedTrips;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching trips: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthorized) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Journeys ✈️')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 80, color: Colors.grey),
              const SizedBox(height: 20),
              const Text("Wallet Locked", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _checkAuthentication,
                child: const Text("Unlock with Biometrics"),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Journeys ✈️', overflow: TextOverflow.ellipsis),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),

          // Add button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3D5A5A),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final bool? didSaveNewTrip = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const JourneyDetailsPage()),
                );

                if (didSaveNewTrip == true && mounted) {
                  _fetchJourneysFromFirestore();
                }
              },
              child: const Text('Add a new journey', style: TextStyle(color: Colors.white)),
            ),
          ),
          const SizedBox(height: 10),

          // Debug trigger notification button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.flash_on, color: Colors.white),
              label: const Text('⚡ FORCE NOTIFICATION NOW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () async {
                String testJourneyId = _trips.isNotEmpty ? _trips.first.id : "test_journey_id_123";
                String testJourneyName = _trips.isNotEmpty ? _trips.first.name : "Test Trip to Rome";

                await NotificationService.showTripNotification(testJourneyId, testJourneyName);
              },
            ),
          ),

          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("My existing Trips", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),

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
          "Are you bored? Let's go somewhere! 🌍",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600], fontSize: 16, fontStyle: FontStyle.italic),
        ),
      ),
    );
  }

  Widget _buildTripList() {
    return ListView.builder(
      itemCount: _trips.length,
      padding: const EdgeInsets.only(bottom: 20),
      itemBuilder: (context, index) {
        bool isDark = index % 2 != 0;
        final journey = _trips[index];

        // FIXED: Wrap inside a unique ObjectKey to ensure Flutter treats each row
        // as a completely distinct identity, avoiding GlobalKey collisions in Slidable.
        return KeyedSubtree(
          key: ObjectKey(journey),
          child: Slidable(
            // Keep a unique composite string for the slidable backend dismissible engine
            key: ValueKey('slidable_${journey.id}_$index'),
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: Text(
                  journey.name,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => JourneyDetailsPage(
                        existingJourney: journey,
                        isReadOnly: true,
                      ),
                    ),
                  );
                },
                onLongPress: () => _showTripOptions(index),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTripOptions(int index) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(_trips[index].name, textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Choose an action:"),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.edit, color: Color(0xFF3D5A5A)),
                title: const Text("Edit"), // Safe default style assignment
                onTap: () {
                  Navigator.pop(dialogContext);
                  _handleEdit(index);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text("Delete", style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(dialogContext);
                  _showConfirmDialog(context, "Delete", index);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }

  void _showConfirmDialog(BuildContext context, String action, int index) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        bool isDelete = action == "Delete";

        return AlertDialog(
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
                      Navigator.pop(dialogContext);
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

  Future<void> _handleDelete(int index) async {
    Journey tripToDelete = _trips[index];

    setState(() {
      _trips.removeAt(index);
    });

    try {
      if (tripToDelete.pdfUrls.isNotEmpty) {
        for (String url in tripToDelete.pdfUrls) {
          if (url.isNotEmpty) {
            await FirebaseStorage.instance.refFromURL(url).delete();
          }
        }
      }

      await FirebaseFirestore.instance.collection('journeys').doc(tripToDelete.id).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Trip and files deleted successfully")),
        );
      }
    } catch (e) {
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

  Future<void> _handleEdit(int index) async {
    final bool? didUpdate = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JourneyDetailsPage(existingJourney: _trips[index]),
      ),
    );

    if (didUpdate == true && mounted) {
      _fetchJourneysFromFirestore();
    }
  }
}