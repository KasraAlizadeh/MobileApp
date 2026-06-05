import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Auth/presentation_page.dart';

class ProfilePage extends StatelessWidget{
  ProfilePage({super.key});

  @override
  Widget build(BuildContext context){
    final user = FirebaseAuth.instance.currentUser;
    final username = user?.displayName ?? 'Utente';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: <Widget>[
              const SizedBox(height: 40),
              CircleAvatar(
                radius: 70,
                backgroundColor: Colors.grey,
                child: const Icon(
                  Icons.person,
                  size: 80,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                username,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 40),
              ListTile(
                leading: const Icon(Icons.eighteen_mp),
                title: const Text("Diciotto"),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.eighteen_mp),
                title: const Text("Diciotto"),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.eighteen_mp),
                title: const Text("Diciotto"),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.eighteen_mp),
                title: const Text("Diciotto"),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.eighteen_mp),
                title: const Text("Diciotto"),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.eighteen_mp),
                title: const Text("Diciotto"),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Log out', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  bool confirm = await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Are you sure?'),
                      content: const Text('Do you want to log out?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Log out', style: TextStyle(color: Colors.red)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ) ?? false;

                  if (confirm) {
                    await FirebaseAuth.instance.signOut();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => PresentationPage()),
                      (route) => false,
                    );
                  }
                },
              ),
              const SizedBox(height: 20), //extra space for scrolling
            ],
          ),
        ),
      ),
    );
  }
}