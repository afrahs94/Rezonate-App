// lib/pages/push_notifications_page.dart

import 'package:flutter/material.dart';

class PushNotificationsPage extends StatefulWidget {
  const PushNotificationsPage({Key? key}) : super(key: key);

  @override
  _PushNotificationsPageState createState() => _PushNotificationsPageState();
}

class _PushNotificationsPageState extends State<PushNotificationsPage> {
  bool _enabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Push Notifications')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Enable Push Notifications'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Daily Reminders'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
        ],
      ),
    );
  }
}
