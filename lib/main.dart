import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'Models/journey.dart';
import 'Features/Wallet/journey_details.dart';
import 'firebase_options.dart';
import 'Appearance/theme_controller.dart';
import 'Auth/presentation_page.dart';
import 'Features/Home/home_page.dart';
import 'Features/Search/search_page.dart';
import 'Features/Wallet/wallet_page.dart';
import 'Features/Profile/profile_page.dart';
import 'Services/notification_service.dart';
import 'Features/splash_screen.dart';

/// Entry point for code execution
@pragma("vm:entry-point")
Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
  String? journeyId = receivedAction.payload?['journeyId'];
  if (journeyId == null) return;

  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print("Firebase initialization warning in background: $e");
  }

  if (receivedAction.buttonKeyPressed == 'YES_ACTION') {
    await FirebaseFirestore.instance
        .collection('journeys')
        .doc(journeyId)
        .update({'state': 'visited'});
    await AwesomeNotifications().cancel(journeyId.hashCode + 2);
  }
  else if (receivedAction.buttonKeyPressed == 'CANCEL_ACTION') {
    await FirebaseFirestore.instance
        .collection('journeys')
        .doc(journeyId)
        .update({'state': 'canceled'});
    for (int i = 1; i <= 6; i++) {
      await AwesomeNotifications().cancel(journeyId.hashCode + i);
    }
  }
}

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
    onActionReceivedMethod: onBackgroundActionReceivedMethod,
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
    return ValueListenableBuilder<ThemeData>(
      valueListenable: ThemeController.themeNotifier,
      builder: (context, ThemeData currentTheme, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: currentTheme,
          title: 'TravelMate',
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
        if (snapshot.hasData) {
          return const MainPage(title: "Welcome home!");
        }
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
  int _selectedIndex = 0;
  final List<int> _indexesStack = [0];

  late final List<Widget> _pages =  [
    HomePage(
      onDeepLinkSearch: (targetIndex, queryCity) {
        handleDeepLinkSearch(targetIndex: targetIndex, queryCity: queryCity);
      },
    ),
    const SearchPage(),
    const WalletPage(),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _checkNotificationPermissions();
    //Let's re-initialize the listener to get the foreground event of navigation
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: (ReceivedAction receivedAction) async {
        String? journeyId = receivedAction.payload?['journeyId'];
        String? actionFlag = receivedAction.payload?['action'];

        if (journeyId != null && (actionFlag == 'edit_photos' || receivedAction.buttonKeyPressed == 'RESCHEDULE_ACTION')) {
          _navigateToEditJourney(journeyId);
        } else {
          await onBackgroundActionReceivedMethod(receivedAction);
        }
      },
      onNotificationCreatedMethod: onNotificationCreatedMethod,
      onNotificationDisplayedMethod: onNotificationDisplayedMethod,
      onDismissActionReceivedMethod: onDismissActionReceivedMethod,
    );
  }

  //Check the lifecycle with "mounted" protocol
  void _navigateToEditJourney(String journeyId) async {
    final doc = await FirebaseFirestore.instance.collection('journeys').doc(journeyId).get();
    if (doc.exists && mounted) {
      final existingJourney = Journey.fromFirestore(doc);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => JourneyDetailsPage(existingJourney: existingJourney),
        ),
      );
    }
  }

  void _checkNotificationPermissions() {
    AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return; //Don't do nothing if you press on tab you're already on
    setState(() {
      _indexesStack.remove(index); //Removes old occurences
      _indexesStack.add(_selectedIndex); //Keeps in memory the current index before changing
      _selectedIndex = index;
    });
  }
  // Inside your _MainPageState class:
  void handleDeepLinkSearch({required int targetIndex, required String queryCity}) {
    setState(() {
      _selectedIndex = targetIndex; // Switch tab view layout target index to 1 (SearchPage)
    });

    // Give the UI a split second to finish the tab layout transition animation,
    // then pass the city parameter straight down to the active SearchPage state instance!
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // We send a global notification event or read the key reference hook to trigger auto search execution
      // Alternately, you can pass this via a global state manager or static router argument parameter!
      SearchPage.triggeredCitySearchNotifier.value = queryCity;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_indexesStack.isNotEmpty) {
          setState(() {
            _selectedIndex = _indexesStack.removeLast();
          });
        } else {
          SystemNavigator.pop(); //if the stack is empty, exit from the app
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