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
        if (authenticated) {
          setState(() => _isAuthorized = true);
          _fetchJourneysFromFirestore();
        }
      } catch (e) {
        debugPrint("Auth error: $e");
        _fetchJourneysFromFirestore();
      }
    } else {
      setState(() => _isAuthorized = true);
      _fetchJourneysFromFirestore();
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
      _trips.clear();
    });
    await _fetchJourneysFromFirestore();
  }

  Future<void> _fetchJourneysFromFirestore() async {
    if (!mounted) return;
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

      List<Journey> loadedTrips = snapshot.docs.map((doc) {
        return Journey.fromFirestore(doc);
      }).toList();

      if (mounted) {
        setState(() {
          _trips = loadedTrips;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching trips: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Custom Background Colors based on Journey State
  Color _getTileColor(String? state) {
    switch (state) {
      case 'visited': return Colors.green.shade100;
      case 'to_be_visited': return Colors.orange.shade100;
      case 'canceled':
      case 'cancelled': return Colors.red.shade100;
      default: return Colors.grey.shade200;
    }
  }

  // Clean Text Colors based on Journey State
  Color _getTextColor(String? state) {
    switch (state) {
      case 'visited': return Colors.green.shade900;
      case 'to_be_visited': return Colors.orange.shade900;
      case 'canceled':
      case 'cancelled': return Colors.red.shade900;
      default: return Colors.black87;
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

    // Filter master list into individual segments dynamically
    final scheduledTrips = _trips.where((t) => t.state == 'to_be_visited').toList();
    final visitedTrips = _trips.where((t) => t.state == 'visited').toList();
    final canceledTrips = _trips.where((t) => t.state == 'canceled' || t.state == 'cancelled').toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Journey️', overflow: TextOverflow.ellipsis),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF3D5A5A),
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
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, inherit: true),
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

            _trips.isEmpty && !_isLoading
                ? _buildEmptyState()
                : _isLoading
                ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF3D5A5A))),
            )
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader("🗓️ Scheduled Trips", scheduledTrips.length),
                _buildTripSubList(scheduledTrips),

                _buildSectionHeader("✅ Visited Places", visitedTrips.length),
                _buildTripSubList(visitedTrips),

                _buildSectionHeader("❌ Canceled Journeys", canceledTrips.length),
                _buildTripSubList(canceledTrips),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 18, bottom: 8),
      child: Text(
        "$title ($count)",
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildTripSubList(List<Journey> sectionList) {
    if (sectionList.isEmpty) return const SizedBox.shrink();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sectionList.length,
      itemBuilder: (context, index) {
        final journey = sectionList[index];
        // to avoid deleting or editing the wrong item indexes when filtered
        int masterIndex = _trips.indexWhere((t) => t.id == journey.id);

        return Slidable(
          key: Key('slidable_${journey.id}_${Theme.of(context).brightness.name}_$index'),
          endActionPane: ActionPane(
            extentRatio: 0.5,
            motion: const ScrollMotion(),
            children: [
              // 📝 EDIT OPTION
              SlidableAction(
                onPressed: (context) => _showConfirmDialog(context, "Edit", masterIndex),
                backgroundColor: const Color(0xFF3D5A5A),
                foregroundColor: Colors.white,
                icon: Icons.edit,
                borderRadius: BorderRadius.circular(8),
              ),
              // DELETE OPTION
              SlidableAction(
                onPressed: (context) => _showConfirmDialog(context, "Delete", masterIndex),
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
              color: _getTileColor(journey.state),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                leading: Icon(
                  journey.state == 'visited'
                      ? Icons.check_circle
                      : journey.state == 'to_be_visited'
                      ? Icons.calendar_today
                      : Icons.cancel,
                  color: _getTextColor(journey.state),
                ),
                title: Text(
                  journey.name,
                  style: TextStyle(
                    color: _getTextColor(journey.state),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.black38),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => JourneyDetailsPage(
                        existingJourney: journey,
                        isReadOnly: true,
                      ),
                    ),
                  ).then((_) => _fetchJourneysFromFirestore());
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
          "Are you bored? Let's go somewhere! 🌍",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600], fontSize: 16, fontStyle: FontStyle.italic),
        ),
      ),
    );
  }

  void _showConfirmDialog(BuildContext context, String action, int index) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
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
                style: TextStyle(
                  fontWeight: FontWeight.w500,
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
                    child: const Text("Cancel", style: TextStyle(color: Colors.white, inherit: true)),
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
                      style: TextStyle(color: isDelete ? Colors.white : Colors.black, inherit: true),
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
      String userId = tripToDelete.userId;
      String journeyId = tripToDelete.id;

      if (userId.isNotEmpty && journeyId.isNotEmpty) {
        print("🗑️ Wiping storage contents for path: media/$userId/$journeyId/");

        final ListResult pdfsDir = await FirebaseStorage.instance
            .ref()
            .child('media/$userId/$journeyId/pdfs')
            .listAll();
        for (Reference fileRef in pdfsDir.items) {
          await fileRef.delete();
        }

        final ListResult imagesDir = await FirebaseStorage.instance
            .ref()
            .child('media/$userId/$journeyId/images')
            .listAll();
        for (Reference fileRef in imagesDir.items) {
          await fileRef.delete();
        }
      }

      await NotificationService.cancelTripAutomations(tripToDelete.id);
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
    if (didUpdate == true) {
      _fetchJourneysFromFirestore();
    }
  }
}