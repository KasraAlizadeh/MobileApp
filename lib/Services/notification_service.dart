import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import '../firebase_options.dart';

/// Handler of background actions
@pragma("vm:entry-point")
Future<void> onBackgroundActionReceivedMethod(ReceivedAction receivedAction) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print("Firebase initialization warning in background isolate: $e");
  }

  String? journeyId = receivedAction.payload?['journeyId'];
  if (journeyId == null) return;

  if (receivedAction.buttonKeyPressed == 'YES_ACTION') {
    try {
      await FirebaseFirestore.instance
          .collection('journeys')
          .doc(journeyId)
          .update({'state': 'visited'});
      await AwesomeNotifications().cancel(journeyId.hashCode + 2);
    } catch (err) {
      print("Error confirming trip in background: $err");
      await FirebaseFirestore.instance.collection('logs').add({
        'timestamp': FieldValue.serverTimestamp(),
        'journeyId': journeyId,
        'errorMessage': err.toString(),
        'location': 'YES_ACTION_BACKGROUND'
      });
    }
  }
  else if (receivedAction.buttonKeyPressed == 'CANCEL_ACTION') {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('journeys').doc(journeyId).get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        List<dynamic> pdfUrls = data['pdfUrls'] ?? [];

        for (String url in pdfUrls) {
          if (url.isNotEmpty) {
            try {
              await FirebaseStorage.instance.refFromURL(url).delete();
            } catch (storageErr) {
              print("Warning: Failed to delete storage file, might not exist: $storageErr");
            }
          }
        }
        await FirebaseFirestore.instance.collection('journeys').doc(journeyId).delete();
      }
    } catch (err) {
      print("Error canceling trip in background: $err");
    }
  }
}

class NotificationService {
  //Main notification channel initialization
  static Future<void> initialize() async {
    await AwesomeNotifications().initialize(
      null, // Use the default app icon
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

  /// Automatic planning of temporal sequence of notifications
  static Future<void> scheduleTripAutomations(
      String journeyId,
      String journeyName,
      String startDateStr,
      String endDateStr
      ) async {
    try {
      DateTime startDate = DateFormat('yyyy-MM-dd').parse(startDateStr);
      DateTime endDate = DateFormat('yyyy-MM-dd').parse(endDateStr);

      // Temporal triggers based on the lifecycle of the trip
      DateTime notification1Time = startDate.subtract(const Duration(days: 1)).copyWith(hour: 12, minute: 0);
      DateTime notification2Time = startDate.copyWith(hour: 7, minute: 0);
      DateTime notification3Time = endDate.copyWith(hour: 18, minute: 0);

      DateTime photoReminder1 = endDate.add(const Duration(days: 1)).copyWith(hour: 11, minute: 0);
      DateTime photoReminder2 = endDate.add(const Duration(days: 2)).copyWith(hour: 16, minute: 0);
      DateTime photoReminder3 = endDate.add(const Duration(days: 7)).copyWith(hour: 10, minute: 0);

      final now = DateTime.now();

      // 1. Reminder of the day before
      if (notification1Time.isAfter(now)) {
        await _createScheduledNotification(
          id: journeyId.hashCode + 1,
          journeyId: journeyId,
          title: "✈️ Trip Tomorrow: $journeyName!",
          body: "Your journey starts tomorrow! Are you packed and ready to go?",
          targetTime: notification1Time,
        );
      }

      // 2. Checking the state before leaving
      if (notification2Time.isAfter(now)) {
        await _createScheduledNotification(
          id: journeyId.hashCode + 2,
          journeyId: journeyId,
          title: "✈️ Trip Day: $journeyName!",
          body: "Still going on your trip today?",
          targetTime: notification2Time,
        );
      }

      // 3. Welcome home
      if (notification3Time.isAfter(now)) {
        await _createScheduledNotification(
          id: journeyId.hashCode + 3,
          journeyId: journeyId,
          title: "🏡 Welcome Back from $journeyName!",
          body: "Hope your journey went beautifully! Review your trip details now.",
          targetTime: notification3Time,
        );
      }

      // 4. First photo reminder, the day after
      if (photoReminder1.isAfter(now)) {
        await _createPhotoReminderNotification(
          id: journeyId.hashCode + 4,
          journeyId: journeyId,
          title: "📸 Relive your trip to $journeyName!",
          body: "Tap here to add your favorite photos to your travel journal before you forget!",
          targetTime: photoReminder1,
        );
      }

      // 5. Second photo reminder, 2 days later
      if (photoReminder2.isAfter(now)) {
        await _createPhotoReminderNotification(
          id: journeyId.hashCode + 5,
          journeyId: journeyId,
          title: "✨ Capture the memories from $journeyName",
          body: "Don't leave your travel memories behind! Upload your trip photos now.",
          targetTime: photoReminder2,
        );
      }

      // 6. Third photo reminder, one week later
      if (photoReminder3.isAfter(now)) {
        await _createPhotoReminderNotification(
          id: journeyId.hashCode + 6,
          journeyId: journeyId,
          title: "⏳ One week since $journeyName!",
          body: "Wrap up your travel wallet. Tap to add any remaining trip photos!",
          targetTime: photoReminder3,
        );
      }
    } catch (e) {
      debugPrint("Error setting automated schedules: $e");
    }
  }

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
        channelKey: 'trip_reminders',
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
        payload: {'journeyId': journeyId, 'action': 'edit_photos'},
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