import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'Appearance/theme_controller.dart';
import 'Auth/presentation_page.dart';

import 'Features/home_page.dart';
import 'Features/search_page.dart';
import 'Features/wallet_page.dart';
import 'Features/profile_page.dart';

void main() {
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