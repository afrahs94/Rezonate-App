import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:new_rezonate/theme/app_gradient_scaffold.dart';

import 'home.dart';
import 'journal.dart';
import 'settings.dart';
import 'package:new_rezonate/pages/services/firestore_service.dart';

class PushNotificationsPage extends StatefulWidget {
  final String userName;
  const PushNotificationsPage({super.key, required this.userName});

  @override
  State<PushNotificationsPage> createState() => _PushNotificationsPageState();
}

class _PushNotificationsPageState extends State<PushNotificationsPage> {
  bool enableAll = false;
  bool daily = false;
  bool replies = false;

  final _auth = FirebaseAuth.instance;
  final _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final settings = await _firestoreService.getNotificationSettings(uid);
    setState(() {
      enableAll = settings['push_notifications_enabled'] ?? false;
      daily = settings['daily_reminder_enabled'] ?? false;
      replies = settings['reply_notifications_enabled'] ?? false;
    });
  }

  Future<void> _saveSettings({
    bool? push,
    bool? dailyReminder,
    bool? replyNotifications,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _firestoreService.updateNotificationSettings(
      uid,
      pushEnabled: push ?? enableAll,
      dailyReminderEnabled: dailyReminder ?? daily,
      replyNotificationsEnabled: replyNotifications ?? replies,
    );
  }

  Future<bool> _requestNotificationPermission() async {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission();
    final granted = settings.authorizationStatus == AuthorizationStatus.authorized;

    if (granted) {
      await _registerFcmToken();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification permission denied.')),
      );
    }

    return granted;
  }

  Future<void> _registerFcmToken() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await _firestoreService.updateFcmToken(uid, token);
    }
  }

  Widget _pill({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final green = const Color(0xFF0D7C66);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: green.withOpacity(.75),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(subtitle,
                      style: TextStyle(color: Colors.white.withOpacity(.9))),
                ]
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: Colors.white.withOpacity(.5),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppGradientScaffold(
      appBar: AppBar(
        title: const Text('Push Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => SettingsPage(userName: widget.userName),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          children: [
            _pill(
              title: 'Receive Push Notifications',
              subtitle: "Turn on to get tracking and reply notifications.",
              value: enableAll,
              onChanged: (v) async {
                if (v) {
                  final granted = await _requestNotificationPermission();
                  if (!granted) return;
                }

                setState(() {
                  enableAll = v;
                  if (!v) {
                    daily = false;
                    replies = false;
                  }
                });

                await _saveSettings(
                  push: v,
                  dailyReminder: v ? daily : false,
                  replyNotifications: v ? replies : false,
                );
              },
            ),
            _pill(
              title: 'Daily Tracking Reminder',
              subtitle:
                  "Send a friendly reminder if you haven’t tracked today.",
              value: daily,
              onChanged: enableAll
                  ? (v) async {
                      setState(() => daily = v);
                      await _saveSettings(dailyReminder: v);
                    }
                  : null,
            ),
            _pill(
              title: 'Replies to your Posts',
              subtitle:
                  "Receive notifications about replies on the community feed.",
              value: replies,
              onChanged: enableAll
                  ? (v) async {
                      setState(() => replies = v);
                      await _saveSettings(replyNotifications: v);
                    }
                  : null,
            ),
          ],
        ),
      ),
      bottomNavigationBar: const _BottomNav(index: 2),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int index;
  const _BottomNav({required this.index});

  @override
  Widget build(BuildContext context) {
    final green = const Color(0xFF0D7C66);
    Color c(int i) => i == index ? green : Colors.white;

    return Container(
      color: Colors.white, // Fixes the black area
      padding: const EdgeInsets.only(bottom: 8, top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(Icons.home, color: c(0)),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => HomePage(userName: ''),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.menu_book, color: c(1)),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => JournalPage(userName: ''),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.settings, color: c(2)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}


