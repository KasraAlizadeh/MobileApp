import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:travel_app/Auth/login_page.dart';
import 'package:travel_app/Auth/signup_page.dart';

class PresentationPage extends StatelessWidget {
  PresentationPage({super.key});

  // Change current page to login page
  void _go_to_login(BuildContext context) {
    Navigator.pushReplacement( //without the possibility to go back
      context, //where is the widget inside the application components' tree => what page to substitute
      MaterialPageRoute( //it handles the animation between the two pages
        builder: (context) => LoginPage(),
      ),
    );
  }

  // Change current page to signup page
  void _go_to_signup(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SignUpPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFcad2c5),
              Color(0xFF2f3e46),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 20, //avoids status bar
            bottom: MediaQuery.of(context).padding.bottom + 20, //avoids taskbar
            left: 20,
            right: 20
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: const Text(
                    'TravelMate',
                    style: TextStyle(
                        fontFamily: 'lobster',
                        fontSize: 40,
                        color: Colors.white
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: SizedBox(
                    width: 120,
                    height: 120,
                    child: SvgPicture.asset('assets/icons/globe.svg'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: const Text(
                    'Simplify every journey',
                    style: TextStyle(
                      fontFamily: 'roboto',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
                Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => _go_to_login(context),
                      style: Theme.of(context).elevatedButtonTheme.style,
                      child: const Text(
                        'Log in',
                        style: TextStyle(
                            color: Colors.white
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => _go_to_signup(context),
                      style: Theme.of(context).outlinedButtonTheme.style,
                      child: const Text(
                        'Create an account',
                        style: TextStyle(
                            color: Colors.white
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}