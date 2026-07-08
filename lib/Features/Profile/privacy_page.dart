import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key});

  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final LocalAuthentication _auth = LocalAuthentication();
  bool _isUploading = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _biometricEnabled = false;
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricSetting();
    _checkBiometricSupport();
  }

  Future<void> _loadBiometricSetting() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
      });
    }
  }

  Future<void> _checkBiometricSupport() async {
    try {
      bool canCheck = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (mounted) {
        setState(() {
          _canCheckBiometrics = canCheck;
        });
      }
    } catch (e) {
      debugPrint("Error checking biometrics: $e");
    }
  }

  Future<void> _toggleBiometrics(bool value) async {
    if (value) {
      try {
        // Soluzione ultra-compatibile: eliminiamo gli import extra e usiamo la sintassi nativa lineare
        bool authenticated = await _auth.authenticate(
          localizedReason: 'Confirm your identity to enable biometric access',
        );

        if (authenticated) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('biometric_enabled', true);
          if (mounted) {
            setState(() => _biometricEnabled = true);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled', false);
      if (mounted) {
        setState(() => _biometricEnabled = false);
      }
    }
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) return;

      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _oldPasswordController.text,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newPasswordController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully!')),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String message = 'An error occurred';
      if (e.code == 'wrong-password') {
        message = 'The old password is incorrect.';
      } else if (e.code == 'weak-password') {
        message = 'The new password is too weak.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Security'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Biometric Authentication",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (_canCheckBiometrics)
              SwitchListTile(
                title: const Text("Use Fingerprint / FaceID"),
                subtitle: const Text("Use biometrics to secure your access"),
                value: _biometricEnabled,
                onChanged: _toggleBiometrics,
                secondary: const Icon(Icons.fingerprint),
                contentPadding: EdgeInsets.zero,
              )
            else
              const Text(
                "Biometric authentication is not supported on this device.",
                style: TextStyle(color: Colors.grey),
              ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(),
            ),

            const Text(
              "Change Password",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _oldPasswordController,
                    obscureText: _obscureOld,
                    decoration: InputDecoration(
                      labelText: "Old Password",
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureOld ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscureOld = !_obscureOld),
                      ),
                    ),
                    validator: (value) => value!.isEmpty ? "Enter your current password" : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: _obscureNew,
                    decoration: InputDecoration(
                      labelText: "New Password",
                      prefixIcon: const Icon(Icons.lock_reset),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureNew ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return "Enter a new password";
                      if (value.length < 6) return "Password must be at least 6 characters";
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirm,
                    decoration: InputDecoration(
                      labelText: "Confirm New Password",
                      prefixIcon: const Icon(Icons.check_circle_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    validator: (value) {
                      if (value != _newPasswordController.text) return "Passwords do not match";
                      return null;
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            _isUploading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
              onPressed: _changePassword,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text("Update Password"),
            ),
          ],
        ),
      ),
    );
  }
}