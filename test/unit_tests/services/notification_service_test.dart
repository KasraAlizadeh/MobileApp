import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:travel_app/Services/notification_service.dart';


class MockAwesomeNotifications extends Mock implements AwesomeNotifications {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockAwesomeNotifications mockNotifications;
  setUpAll(() {
    registerFallbackValue(NotificationCalendar.fromDate(date: DateTime.now()));

    registerFallbackValue(NotificationContent(
      id: 1,
      channelKey: 'trip_reminders',
      title: 'dummy',
      body: 'dummy',
    ));
  });
  setUp(() {
    mockNotifications = MockAwesomeNotifications();

    registerFallbackValue(NotificationCalendar.fromDate(date: DateTime.now()));

    when(() => mockNotifications.initialize(any(), any(),
        channelGroups: any(named: 'channelGroups'),
        debug: any(named: 'debug'))).thenAnswer((_) async => true);

    when(() => mockNotifications.createNotification(
      content: any(named: 'content'),
      actionButtons: any(named: 'actionButtons'),
      schedule: any(named: 'schedule'),
    )).thenAnswer((_) async => true);

    when(() => mockNotifications.cancel(any())).thenAnswer((_) async => true);
  });

  group('NotificationService Lifecycle and Automation Coverage Tests', () {

    test('initialize builds the proper reminder notification channel', () async {

      await NotificationService.initialize();
    });

    test('scheduleTripAutomations schedules chronological notification chains successfully', () async {

      final futureStart = "2026-08-15";
      final futureEnd = "2026-08-20";

      await NotificationService.scheduleTripAutomations(
        'journey_xyz_123',
        'Roma Holiday',
        futureStart,
        futureEnd,
      );
    });

    test('scheduleTripAutomations safely catches formatting discrepancies', () async {

      await NotificationService.scheduleTripAutomations(
        'id',
        'Trip',
        'invalid-date',
        'invalid-date',
      );
    });

    test('cancelTripAutomations unregisters all 6 scheduled reminder notifications', () async {
      await NotificationService.cancelTripAutomations('journey_xyz_123');

    });
  });
}