import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  // state viariables
  List<Journey> _trips = [];
  bool _isLoading = true; // loading spinner while fetching data initially
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
        if (authenticated) {
          setState(() => _isAuthorized = true);
          _fetchJourneysFromFirestore();
        } else {
          // Stay in unauthorized state
        }
      } catch (e) {
        debugPrint("Auth error: $e");
        // In case of error, you might want to allow or block access
        // For now, let's allow access if biometric check fails badly
        _fetchJourneysFromFirestore();
      }
    } else {
      setState(() => _isAuthorized = true);
      _fetchJourneysFromFirestore();
    }
  }
  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true; // Show the custom screen loading spinners
      _trips.clear();    // Flush existing entries to prevent UI flashes
    });
    await _fetchJourneysFromFirestore();
  }
  // one time fetch logic
  Future<void> _fetchJourneysFromFirestore() async {
    if (!_isLoading) {
      setState(() => _isLoading = true);
    }
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('journeys')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      // convert Firestore documents into Journey objects
      List<Journey> loadedTrips = snapshot.docs.map((doc) {
        return Journey.fromFirestore(doc);
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'My Journeys ✈️',
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body:RefreshIndicator(
        onRefresh: _refreshData, // Points to the fresh refresh tracking sequence
        color: const Color(0xFF3D5A5A), // Matches the primary branding color
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 20),

            // Add Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3D5A5A),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    inherit: true, // Force agreement between the light/dark transition layers
                  ),
                ),
                onPressed: () async {
                  final bool? didSaveNewTrip = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const JourneyDetailsPage()),
                  );

                  if (didSaveNewTrip == true) {
                    _fetchJourneysFromFirestore();
                  }
                },

                child: Text(
                  'Add a new journey',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Force Notification Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade800,
                  minimumSize: const Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    inherit: true,
                  ),
                ),
                icon: const Icon(Icons.flash_on, color: Colors.white),

                label: Text(
                  '⚡ FORCE NOTIFICATION NOW',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () async {
                  print("🚀 Forcing local notification trigger...");
                  String testJourneyId = _trips.isNotEmpty ? _trips.first.id : "test_journey_id_123";
                  String testJourneyName = _trips.isNotEmpty ? _trips.first.name : "Test Trip to Rome";

                  await NotificationService.showTripNotification(
                      testJourneyId,
                      testJourneyName
                  );
                },
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                  "My existing Trips",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  )
              ),
            ),
          ),

          // Handling list or empty messages
          _isLoading
              ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(color: Color(0xFF3D5A5A))),
          )
              : _trips.isEmpty
              ? _buildEmptyState()
              : _buildTripList(),
        ],
      ),
    ));
  }

  // Updated to use simple un-bounded listing rendering structure
  Widget _buildTripList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _trips.length,
      itemBuilder: (context, index) {
        bool isDark = index % 2 != 0;
        final journey = _trips[index];

        return Slidable(
          key: Key('slidable_${journey.id}_${Theme.of(context).brightness.name}_$index'),
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
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                title: Text(
                  journey.name,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
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
              ),
            ),
          ),
        );
      },
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
                style: TextStyle(fontWeight: FontWeight.w500,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
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
                    child: const Text("Cancel", style: TextStyle(color: Colors.white, inherit: true,)),
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
                      style: TextStyle(color: isDelete ? Colors.white : Colors.black, inherit: true,),
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

  // background delete logic
  Future<void> _handleDelete(int index) async {
    Journey tripToDelete = _trips[index];

    // instantly remove from UI so it feels lightning fast for the user
    setState(() {
      _trips.removeAt(index);
    });

    try {
      String userId = tripToDelete.userId;
      String journeyId = tripToDelete.id;

      if (userId.isNotEmpty && journeyId.isNotEmpty) {
        print("🗑️ Wiping storage contents for path: media/$userId/$journeyId/");

        // 1. Wipe the entire 'pdfs' subfolder content
        final ListResult pdfsDir = await FirebaseStorage.instance
            .ref()
            .child('media/$userId/$journeyId/pdfs')
            .listAll();
        for (Reference fileRef in pdfsDir.items) {
          await fileRef.delete();
        }

        // 2. Wipe the entire 'images' subfolder content
        final ListResult imagesDir = await FirebaseStorage.instance
            .ref()
            .child('media/$userId/$journeyId/images')
            .listAll();
        for (Reference fileRef in imagesDir.items) {
          await fileRef.delete();
        }
      }
      /*// background Task: Delete all connected PDFs in Firebase Storage
      if (tripToDelete.pdfUrls.isNotEmpty) {
        for (String url in tripToDelete.pdfUrls) {
          await FirebaseStorage.instance.refFromURL(url).delete();
        }
      }*/

      // background Task: Delete the Firestore document
      await FirebaseFirestore.instance.collection('journeys').doc(tripToDelete.id).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Trip and files deleted successfully")),
        );
      }
    } catch (e) {
      // if something fails, put it back in the list!
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

  //edit logic
  Future<void> _handleEdit(int index) async {
    final bool? didUpdate = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JourneyDetailsPage(existingJourney: _trips[index]),
      ),
    );

    // if the edit page successfully saved, re-fetch to get the fresh data
    if (didUpdate == true) {
      _fetchJourneysFromFirestore();
    }
  }

}