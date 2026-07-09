import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../main.dart';


class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {

  @override
  void initState() {
    super.initState();
    _startLoadingSequence();
  }

  Future<void> _startLoadingSequence() async {
    // ⏳ SIMULATE LOADING ASSETS/COMPONENTS
    // This gives the plane animation 3 seconds to fly across the screen
    // while your app securely links dependencies in the background.
    await Future.delayed(const Duration(milliseconds: 3000));

    if (mounted) {
      // Smoothly jump to your main wallet page and clear the history stack
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthGate()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Matches the signature dark teal palette of your application
      backgroundColor: const Color(0xFF3D5A5A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ✈️ THE LOTTIE PLANE ANIMATION
            SizedBox(
              width: 220,
              height: 220,
              child: Lottie.asset(
                'assets/animations/plane-animation.json',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 15),

            // Premium travel branding subtitle
            const Text(
              "Preparing Your Next Adventure...",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 20),

            // Sleek flat material loader bar matching the white accents
            const SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                color: Colors.white,
                backgroundColor: Colors.white24,
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}