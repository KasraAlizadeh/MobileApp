import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

// =====================================================================
// 1. BACKGROUND ACTION LISTENER (MUST BE A TOP-LEVEL FUNCTION!)
// =====================================================================
@pragma("vm:entry-point")
Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
  // Initialize Firebase (Required if the app was completely closed)
  await Firebase.initializeApp();

  String? journeyId = receivedAction.payload?['journeyId'];
  if (journeyId == null) return;

  if (receivedAction.buttonKeyPressed == 'YES_ACTION') {
    // UPDATE STATUS TO VISITED
    await FirebaseFirestore.instance.collection('journeys').doc(journeyId).update({'status': 'visited'});
    print("Trip updated to visited!");

  } else if (receivedAction.buttonKeyPressed == 'RESCHEDULE_ACTION') {
    // The app will open. We will handle the routing to the Edit Page in main.dart
    print("User wants to reschedule. Opening app...");

  } else if (receivedAction.buttonKeyPressed == 'CANCEL_ACTION') {
    // DELETE THE JOURNEY AND PDFs
    DocumentSnapshot doc = await FirebaseFirestore.instance.collection('journeys').doc(journeyId).get();

    if (doc.exists) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      List<dynamic> pdfUrls = data['pdfUrls'] ?? [];

      for (String url in pdfUrls) {
        if (url.isNotEmpty) {
          await FirebaseStorage.instance.refFromURL(url).delete();
        }
      }
      await FirebaseFirestore.instance.collection('journeys').doc(journeyId).delete();
      print("Trip canceled and deleted!");
    }
  }
}

// =====================================================================
// 2. NOTIFICATION SERVICE CLASS
// =====================================================================
class NotificationService {

  // Call this once in main.dart when the app starts
  static Future<void> initialize() async {
    await AwesomeNotifications().initialize(
      null, // null means it will use the default app icon
      [
        NotificationChannel(
          channelGroupKey: 'trip_reminders_group',
          channelKey: 'trip_reminders',
          channelName: 'Trip Reminders',
          channelDescription: 'Notifications for upcoming trips',
          defaultColor: const Color(0xFF3D5A5A),
          ledColor: Colors.white,
          importance: NotificationImportance.High,
        )
      ],
    );

    // Set up the listener to listen for button clicks
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: onActionReceivedMethod,
    );
  }

  // =====================================================================
  // 3. YOUR FUNCTION TO SHOW THE NOTIFICATION
  // =====================================================================
  static Future<void> showTripNotification(String journeyId, String tripName) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: journeyId.hashCode,
        channelKey: 'trip_reminders',
        title: '✈️ Trip Day: $tripName!',
        body: 'Are you still going on your trip today?',
        notificationLayout: NotificationLayout.Default,
        payload: {'journeyId': journeyId}, // Hidden data for the buttons
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'YES_ACTION',
          label: 'Yes, I am going!',
          color: Colors.green,
        ),
        NotificationActionButton(
          key: 'RESCHEDULE_ACTION',
          label: 'Rescheduled',
          color: Colors.orange,
        ),
        NotificationActionButton(
          key: 'CANCEL_ACTION',
          label: 'Canceled',
          color: Colors.red,
          isDangerousOption: true,
        ),
      ],
    );
  }
}