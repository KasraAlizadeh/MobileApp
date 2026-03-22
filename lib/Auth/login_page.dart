import 'package:flutter/material.dart';

import '../main.dart';
import 'signup_page.dart';

class LoginPage extends StatelessWidget {
  LoginPage({super.key});

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _login(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const MainPage(title: "Ciao"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _login(context),
              child: const Text("Login"),
            ),
            TextButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SignUpPage()),
                );

                if (!context.mounted) return;

                if (result != null) {
                  String email = result["email"];
                  String password = result["password"];

                  _emailController.text = email;
                  _passwordController.text = password;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Registrazione completata")),
                  );
                }
              },
              child: const Text("Non hai un account? Registrati"),
            ),
          ],
        ),
      ),
    );
  }
}