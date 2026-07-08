import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../Auth/presentation_page.dart';
import '../../Appearance/theme_controller.dart';
import 'privacy_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isUploading = false;
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateDisplayName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _nameController.text.trim().isEmpty) return;

    try {
      await user.updateDisplayName(_nameController.text.trim());
      await user.reload();
      setState(() {}); // Refresh UI
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating name: $e')),
        );
      }
    }
  }

  void _showEditNameDialog() {
    final user = FirebaseAuth.instance.currentUser;
    _nameController.text = user?.displayName ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Username'),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            hintText: "Enter new username",
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _updateDisplayName,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );

    if (image == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('user_profiles')
          .child('${user.uid}.jpg');

      await storageRef.putFile(File(image.path));
      final downloadUrl = await storageRef.getDownloadURL();

      await user.updatePhotoURL(downloadUrl);
      await user.reload();

      setState(() {
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated!')),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final username = user?.displayName ?? 'Utente';
    final photoUrl = user?.photoURL;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: <Widget>[
              const SizedBox(height: 40),
              GestureDetector(
                onTap: _isUploading ? null : _pickAndUploadImage,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 70,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: photoUrl != null
                          ? CachedNetworkImageProvider(photoUrl)
                          : null,
                      child: photoUrl == null
                          ? const Icon(
                              Icons.person,
                              size: 80,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    if (_isUploading)
                      const CircularProgressIndicator(),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    username,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _showEditNameDialog,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              ListTile(
                leading: const Icon(Icons.notifications),
                title: const Text("Notifications"),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.lock),
                title: const Text("Privacy and Security"),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const PrivacyPage()),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.dark_mode_outlined),
                title: const Text("Dark Mode"),
                trailing: Switch(
                  value: Theme.of(context).brightness == Brightness.dark,
                  onChanged: (value) {
                    ThemeController.nextTheme();
                  },
                ),
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
