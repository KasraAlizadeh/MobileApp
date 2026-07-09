import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../firebase_options.dart';
import '../main.dart';
import '../Features/Wallet/journey.dart';
import '../Features/Wallet/journey_details.dart';

class NotificationService {

  static Future<void> initialize() async {
    await AwesomeNotifications().initialize(
      null,
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
  }

  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    String? journeyId = receivedAction.payload?['journeyId'];
    if (journeyId == null) return;

    if (receivedAction.buttonKeyPressed == 'YES_ACTION') {
      try {
        await FirebaseFirestore.instance.collection('journeys').doc(journeyId).update({'state': 'visited'});
        print("Trip updated to visited!");
      } catch (err) {
        print("Error confirming trip notification: $err");
        await FirebaseFirestore.instance.collection('logs').add({
          'timestamp': FieldValue.serverTimestamp(),
          'journeyId': journeyId,
          'errorMessage': err.toString(),
          'location': 'YES_ACTION_BACKGROUND'
        });
      }

    } else if (receivedAction.buttonKeyPressed == 'RESCHEDULE_ACTION') {
      print("User wants to reschedule. Opening app and fetching data...");
      try {
        DocumentSnapshot doc = await FirebaseFirestore.instance.collection('journeys').doc(journeyId).get();
        if (doc.exists) {
          Journey existingJourney = Journey.fromFirestore(doc);

          // Direct global navigation push across layers using the global key
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => JourneyDetailsPage(existingJourney: existingJourney),
            ),
          );
        }
      } catch (err) {
        print("Error redirecting to reschedule page: $err");
      }

    } else if (receivedAction.buttonKeyPressed == 'CANCEL_ACTION') {
      try {
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
      } catch (err) {
        print("Error deleting canceled trip: $err");
      }
    }
  }

  static Future<void> showTripNotification(String journeyId, String tripName) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: journeyId.hashCode,
        channelKey: 'trip_reminders',
        title: '✈️ Trip Day: $tripName!',
        body: 'Are you still going on your trip today?',
        notificationLayout: NotificationLayout.Default,
        payload: {'journeyId': journeyId},
      ),
      actionButtons: [
        NotificationActionButton(key: 'YES_ACTION', label: 'Yes, I am going!', color: Colors.green, actionType: ActionType.SilentBackgroundAction),
        NotificationActionButton(key: 'RESCHEDULE_ACTION', label: 'Rescheduled', color: Colors.orange, actionType: ActionType.Default),
        NotificationActionButton(key: 'CANCEL_ACTION', label: 'Canceled', color: Colors.red, isDangerousOption: true, actionType: ActionType.SilentBackgroundAction),
      ],
    );
  }
}