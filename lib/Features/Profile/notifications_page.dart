import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../Services/notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _notificationsEnabled = true;

  late final Stream<QuerySnapshot> _historyStream;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreference();

    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _historyStream = FirebaseFirestore.instance
        .collection('notification_history')
        .where('userId', isEqualTo: currentUid)
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots();
  }

  Future<void> _loadNotificationPreference() async {
    bool enabled = await NotificationService.areNotificationsEnabled();
    if (mounted) {
      setState(() {
        _notificationsEnabled = enabled;
      });
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    await NotificationService.setNotificationsEnabled(value);
    if (mounted) {
      setState(() {
        _notificationsEnabled = value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F4),
      appBar: AppBar(
        title: const Text('Notification Settings'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 0,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: SwitchListTile(
              title: const Text('Enable Notifications', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Receive reminders and updates about your trips'),
              value: _notificationsEnabled,
              onChanged: _toggleNotifications,
              activeThumbColor: const Color(0xFF3D5A5A),
              secondary: const Icon(Icons.notifications_active, color: Color(0xFF3D5A5A)),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Text(
              'Notification History',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _historyStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF3D5A5A)));
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text('Query Error: ${snapshot.error}\n\n*If it mentions an Index, click the link in your console to build it!*', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.red)),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none, size: 50, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        const Text('No notification history yet.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final title = data['title'] ?? 'No Title';
                    final body = data['body'] ?? 'No Body';
                    final timestamp = data['timestamp'] as Timestamp?;

                    final dateStr = timestamp != null
                        ? DateFormat('dd MMM yyyy, HH:mm').format(timestamp.toDate())
                        : 'Unknown date';

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade100),
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE8EFE8),
                          child: Icon(Icons.info_outline, color: Color(0xFF3D5A5A)),
                        ),
                        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(body, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                              const SizedBox(height: 6),
                              Text(
                                dateStr,
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}