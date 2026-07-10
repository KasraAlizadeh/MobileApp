import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'Features/Profile/profile_page.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'Services/notification_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'Features/splash_screen.dart';


@pragma("vm:entry-point")
Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
  // This method runs in the background
  String? journeyId = receivedAction.payload?['journeyId'];
  String? actionFlag = receivedAction.payload?['action'];
  if (journeyId == null) return;

  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // If it was already initialized in this isolate somehow, catch the error gracefully
    print("Firebase initialization warning in background: $e");
  }

  if (receivedAction.buttonKeyPressed == 'YES_ACTION') {
    print("Background update: User is going to $journeyId");
    // We import cloud_firestore at top of main.dart to make this work
    await FirebaseFirestore.instance
        .collection('journeys')
        .doc(journeyId)
        .update({'state': 'visited'});
    await AwesomeNotifications().cancel(journeyId.hashCode + 2);
    print("User reacted. Second reminder canceled successfully.");
  }
  else if (receivedAction.buttonKeyPressed == 'CANCEL_ACTION') {
    print("Background update: User cancelled trip $journeyId");
    await FirebaseFirestore.instance
        .collection('journeys')
        .doc(journeyId)
        .update({'state': 'canceled'});
    for (int i = 1; i <= 6; i++) {
      await AwesomeNotifications().cancel(journeyId.hashCode + i);
    }
  }
  else if (actionFlag == 'edit_photos') {
    print("User clicked photo reminder! Redirecting to edit screen for $journeyId");
    // Handled smoothly when app transitions to foreground state
  }

}

// Dummy background handlers to satisfy requirements
@pragma("vm:entry-point")
Future<void> onNotificationCreatedMethod(ReceivedNotification receivedNotification) async {}

@pragma("vm:entry-point")
Future<void> onNotificationDisplayedMethod(ReceivedNotification receivedNotification) async {}

@pragma("vm:entry-point")
Future<void> onDismissActionReceivedMethod(ReceivedAction receivedAction) async {}
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.initialize();

  AwesomeNotifications().setListeners(
    onActionReceivedMethod: onActionReceivedMethod, // Points directly to top-level function
    onNotificationCreatedMethod: onNotificationCreatedMethod,
    onNotificationDisplayedMethod: onNotificationDisplayedMethod,
    onDismissActionReceivedMethod: onDismissActionReceivedMethod,
  );
  await dotenv.load(fileName: ".env");
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
            title: 'TravelMate',
            //home: PresentationPage(),
            home: const SplashPage(),
          );
        },
    );
  }
}
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Color(0xFF3D5A5A))),
          );
        }
        // If logged in, send them straight to the main app dashboard navigation stack
        if (snapshot.hasData) {
          return const MainPage(title: "Welcome home!");
        }
        // If logged out, show your partner's landing PresentationPage
        return const PresentationPage();
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
  static int _selectedIndex = 0;
  static final List<int> _indexesStack = [0];

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
    _checkNotificationPermissions();
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: (ReceivedAction receivedAction) async {
        String? journeyId = receivedAction.payload?['journeyId'];
        String? actionFlag = receivedAction.payload?['action'];

        if (journeyId != null && actionFlag == 'edit_photos') {
          // Triggers your existing built-in navigation logic perfectly!
          _navigateToEditJourney(journeyId);
        }
        else if (journeyId != null && receivedAction.buttonKeyPressed == 'RESCHEDULE_ACTION') {
          print("User clicked Reschedule button! Navigating to edit sheet...");
          _navigateToEditJourney(journeyId);
        }
      },
    );
    /*AwesomeNotifications().setListeners(
      onActionReceivedMethod: (ReceivedAction receivedAction) async {
        String? journeyId = receivedAction.payload?['journeyId'];
        if (journeyId == null) return;
        if (receivedAction.buttonKeyPressed == 'YES_ACTION') {
          print("User confirmed going on journey: $journeyId");
          await FirebaseFirestore.instance
              .collection('journeys')
              .doc(journeyId)
              .update({'state': 'visited'}); // Or 'ongoing', depending on your naming preference!

          // Force a notification block update alert on screen if app is running
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Awesome! Have a wonderful trip! 🌍")),
            );
          }
        }
        else if (receivedAction.buttonKeyPressed == 'DELETE_ACTION') {
          print("User cancelled journey: $journeyId");
          await FirebaseFirestore.instance
              .collection('journeys')
              .doc(journeyId)
              .update({'state': 'cancelled'});

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Journey marked as cancelled.")),
            );
          }
        }
        else if (receivedAction.buttonKeyPressed == 'RESCHEDULE_ACTION') {
          _navigateToEditJourney(journeyId);
        }
      },
    );*/
  }
  void _navigateToEditJourney(String journeyId) async {

    var doc = await FirebaseFirestore.instance.collection('journeys').doc(journeyId).get();
    if (doc.exists) {
      Journey existingJourney = Journey.fromFirestore(doc); // Or however the model maps it
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
        AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
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