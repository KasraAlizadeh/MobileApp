import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import '../firebase_options.dart';

// BACKGROUND ACTION LISTENER
@pragma("vm:entry-point")
Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
//this is crucial for the background binary messenger channel
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase (Required if the app was completely closed)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  String? journeyId = receivedAction.payload?['journeyId'];
  if (journeyId == null) return;

  if (receivedAction.buttonKeyPressed == 'YES_ACTION') {
    // UPDATE STATUS TO VISITED
    try{
      await FirebaseFirestore.instance.collection('journeys').doc(journeyId).update({'state': 'visited'});
      print("Trip updated to visited!");
    }
    catch(err){
      print("error at confirming trip notiication: $err");
      // THE LOG CATCHER: Force the background worker to write its failure to the cloud
      await FirebaseFirestore.instance.collection('logs').add({
        'timestamp': FieldValue.serverTimestamp(),
        'journeyId': journeyId,
        'errorMessage': err.toString(),
        'location': 'YES_ACTION_BACKGROUND'
      });
    }

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


// NOTIFICATION SERVICE CLASS
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
  }
  static Future<void> scheduleTripAutomations(
      String journeyId,
      String journeyName,
      String startDateStr,
      String endDateStr
      ) async {
    try {
      DateTime startDate = DateFormat('yyyy-MM-dd').parse(startDateStr);
      DateTime endDate = DateFormat('yyyy-MM-dd').parse(endDateStr);
      DateTime endOfTripDay = endDate.copyWith(hour: 23, minute: 59, second: 59);

      // Define clear trigger times
      // Temporary test offsets inside scheduleTripAutomations:
      /*DateTime notification1Time = DateTime.now().add(const Duration(minutes: 1));
      DateTime notification2Time = DateTime.now().add(const Duration(minutes: 3));
      DateTime notification3Time = DateTime.now().add(const Duration(minutes: 5));*/

      DateTime notification1Time = startDate.subtract(const Duration(days: 1)).copyWith(hour: 12, minute: 0); // 1 day before at Noon
      DateTime notification2Time = startDate.copyWith(hour: 7, minute: 0);  // Trip Day Morning at 7:00 AM
      DateTime notification3Time = endDate.copyWith(hour: 18, minute: 0);   // Finishing Day at 6:00 PM

      DateTime photoReminder1 = endOfTripDay.add(const Duration(days: 1)).copyWith(hour: 11, minute: 0); // 1 day after at 11:00 AM
      DateTime photoReminder2 = endOfTripDay.add(const Duration(days: 2)).copyWith(hour: 16, minute: 0); // 2 days after at 4:00 PM
      DateTime photoReminder3 = endOfTripDay.add(const Duration(days: 7)).copyWith(hour: 10, minute: 0); // 1 week after at 10:00 AM

      // Notification 1: Day before warning
      if (notification1Time.isAfter(DateTime.now())) {
        await _createScheduledNotification(
          id: journeyId.hashCode + 1,
          journeyId: journeyId,
          title: "✈️ Trip Tomorrow: $journeyName!",
          body: "Your journey starts tomorrow! Are you packed and ready to go?",
          targetTime: notification1Time,
        );
      }

      // Notification 2: Trip day confirmation check
      if (notification2Time.isAfter(DateTime.now())) {
        await _createScheduledNotification(
          id: journeyId.hashCode + 2,
          journeyId: journeyId,
          title: "✈️ Trip Day: $journeyName!",
          body: "Are you still going on your trip today?",
          targetTime: notification2Time,
        );
      }

      // Notification 3: Return wrap-up
      if (notification3Time.isAfter(DateTime.now())) {
        await _createScheduledNotification(
          id: journeyId.hashCode + 3,
          journeyId: journeyId,
          title: "🏡 Welcome Back from $journeyName!",
          body: "Hope your journey went beautifully! Review your trip details now.",
          targetTime: notification3Time,
        );
      }
      if (photoReminder1.isAfter(DateTime.now())) {
        await _createPhotoReminderNotification(
          id: journeyId.hashCode + 4,
          journeyId: journeyId,
          title: "📸 Relive your trip to $journeyName!",
          body: "Tap here to add your favorite photos to your travel journal before you forget!",
          targetTime: photoReminder1,
        );
        //  Photo Reminder: 2 Days After
        if (photoReminder2.isAfter(DateTime.now())) {
          await _createPhotoReminderNotification(
            id: journeyId.hashCode + 5,
            journeyId: journeyId,
            title: "✨ Capture the memories from $journeyName",
            body: "Don't leave your travel memories behind! Upload your trip photos now.",
            targetTime: photoReminder2,
          );
        }

        //  Photo Reminder: 1 Week After
        if (photoReminder3.isAfter(DateTime.now())) {
          await _createPhotoReminderNotification(
            id: journeyId.hashCode + 6,
            journeyId: journeyId,
            title: "⏳ One week since $journeyName!",
            body: "Wrap up your travel wallet. Tap to add any remaining trip photos!",
            targetTime: photoReminder3,
          );
        }
      }
    } catch (e) {
      debugPrint("Error setting automated schedules: $e");
    }
  }
  // Helper template method to schedule individual stages safely
  static Future<void> _createScheduledNotification({
    required int id,
    required String journeyId,
    required String title,
    required String body,
    required DateTime targetTime,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: 'trip_reminders', // Kept matching your original key
        title: title,
        body: body,
        payload: {'journeyId': journeyId},
        autoDismissible: false,
        locked: false,
        notificationLayout: NotificationLayout.Default,
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'YES_ACTION',
          label: 'Yes, I am going!',
          color: Colors.green,
          actionType: ActionType.SilentBackgroundAction,
        ),
        NotificationActionButton(
          key: 'RESCHEDULE_ACTION',
          label: 'Rescheduled',
          color: Colors.orange,
          actionType: ActionType.Default,
        ),
        NotificationActionButton(
          key: 'CANCEL_ACTION',
          label: 'Canceled',
          color: Colors.red,
          isDangerousOption: true,
          actionType: ActionType.SilentBackgroundAction,
        ),
      ],
      schedule: NotificationCalendar.fromDate(date: targetTime),
    );
  }
  static Future<void> _createPhotoReminderNotification({
    required int id,
    required String journeyId,
    required String title,
    required String body,
    required DateTime targetTime,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: 'trip_reminders',
        title: title,
        body: body,
        payload: {'journeyId': journeyId, 'action': 'edit_photos'}, // Custom action flag
        autoDismissible: true,
        notificationLayout: NotificationLayout.Default,
        actionType: ActionType.Default,
      ),
      schedule: NotificationCalendar.fromDate(date: targetTime),
    );
  }
  static Future<void> cancelTripAutomations(String journeyId) async {
    for (int i = 1; i <= 6; i++) {
      await AwesomeNotifications().cancel(journeyId.hashCode + i);
    }
  }

}