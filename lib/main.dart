import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'firebase_options.dart';
import 'Appearance/theme_controller.dart';
import 'Auth/presentation_page.dart';
import 'Features/Home/home_page.dart';
import 'Features/Search/search_page.dart';
import 'Features/Wallet/wallet_page.dart';
import 'Features/Profile/profile_page.dart';
import 'Services/notification_service.dart';
import 'Features/splash_screen.dart';

// Global key to manage navigation from anywhere in the app
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.initialize();

  // SINGLE configuration for global listeners at the application level
  AwesomeNotifications().setListeners(
    onActionReceivedMethod: NotificationService.onActionReceivedMethod,
    onNotificationCreatedMethod: (ReceivedNotification receivedNotification) async {},
    onNotificationDisplayedMethod: (ReceivedNotification receivedNotification) async {},
    onDismissActionReceivedMethod: (ReceivedAction receivedAction) async {},
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
          navigatorKey: navigatorKey, // Assigning the global key
          debugShowCheckedModeBanner: false,
          theme: currentTheme,
          title: 'TravelMate',
          home: const SplashPage(), // The splash page will show the logo and then push to AuthGate
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
        // If the user is logged in, send them straight to MainPage
        if (snapshot.hasData) {
          return const MainPage(title: "Welcome home!");
        }
        // If logged out, show the presentation page
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

  final List<Widget> _pages = [
    HomePage(),
    SearchPage(),
    WalletPage(),
    ProfilePage(),
  ];

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return; // Avoid consecutive duplicates in the history

    setState(() {
      // Simplified tab history management
      _indexesStack.remove(index);
      _indexesStack.add(_selectedIndex);
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _checkNotificationPermissions();
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
      canPop: _indexesStack.isEmpty, // Informs the system if Flutter can handle the "Back" action
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
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