import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'Features/Wallet/journey.dart';
import 'Features/Wallet/journey_details.dart';
import 'firebase_options.dart';
import 'Appearance/theme_controller.dart';
import 'Auth/presentation_page.dart';
import 'Features/home_page.dart';
import 'Features/search_page.dart';
import 'Features/Wallet/wallet_page.dart';
import 'Features/profile_page.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'Services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.initialize();

  AwesomeNotifications().setListeners(
    onActionReceivedMethod: onActionReceivedMethod, // Points directly to top-level function
    onNotificationCreatedMethod: (ReceivedNotification receivedNotification) async {},
    onNotificationDisplayedMethod: (ReceivedNotification receivedNotification) async {},
    onDismissActionReceivedMethod: (ReceivedAction receivedAction) async {},
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
        valueListenable: ThemeController.themeNotifier,
        builder: (context, ThemeData currentTheme, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: currentTheme,
            home: PresentationPage(),
          );
        },
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key, required this.title});

  final String title;

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  final List<int> _indexesStack = [0];

  final List<Widget> _pages = [
    HomePage(),
    SearchPage(),
    WalletPage(),
    ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      //pages in the stack are always, at most, 4. If a page is already in the stack, remove
      if(_indexesStack.contains(_selectedIndex)){
        if(_selectedIndex == 0) {
          if(_indexesStack.lastIndexOf(_selectedIndex) != 0){
            _indexesStack.removeAt(_indexesStack.lastIndexOf(_selectedIndex));
          }
        } else {
          _indexesStack.remove(_selectedIndex);
        }
      }
      if(_selectedIndex != _indexesStack.last){
        _indexesStack.add(_selectedIndex);
      }
      _selectedIndex = index;
    });
  }
  @override
  void initState() {
    super.initState();
    // This will trigger the permission check as soon as this page opens
    _checkNotificationPermissions();
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: (ReceivedAction receivedAction) async {
        // Check if they clicked the Reschedule button
        if (receivedAction.buttonKeyPressed == 'RESCHEDULE_ACTION') {
          String? journeyId = receivedAction.payload?['journeyId'];
          if (journeyId != null) {
            _navigateToEditJourney(journeyId);
          }
        }
      },
    );
  }
  void _navigateToEditJourney(String journeyId) async {
    // 1. Fetch the full journey object from Firestore using the ID
    var doc = await FirebaseFirestore.instance.collection('journeys').doc(journeyId).get();
    if (doc.exists) {
      // 2. Convert it to your Journey model object
      Journey existingJourney = Journey.fromFirestore(doc); // Or however your model maps it

      // 3. Jump to edit page!
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JourneyDetailsPage(existingJourney: existingJourney),
          ),
        );
      }
    }
  }
  void _checkNotificationPermissions() {
    AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        // If permission is not allowed, prompt the user
        // You could also show a custom dialog here explaining WHY you need it
        // before calling this prompt.
        AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      //if you press "backwards"
      onPopInvokedWithResult: (didPop, result) {
        if (_indexesStack.isNotEmpty) {
          setState(() {
            _selectedIndex = _indexesStack.removeLast();
          });
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
            BottomNavigationBarItem(icon: Icon(Icons.wallet), label: 'Wallet'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}