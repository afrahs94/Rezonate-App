import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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

    final pushState = push ?? enableAll;

    await _firestoreService.updateNotificationSettings(
      uid,
      pushEnabled: pushState,
      dailyReminderEnabled: dailyReminder ?? daily,
      replyNotificationsEnabled: replyNotifications ?? replies,
    );

    if (pushState) {
      await _registerFcmToken();
    }
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

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _firestoreService.updateFcmToken(uid, token);
      }
    } catch (e) {
      debugPrint('FCM token registration failed: $e');
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
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface.withOpacity(0.9);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFD7C3F1), Color(0xFFBDE8CA)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 16, 6),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back,
                          color: theme.colorScheme.onSurface),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),

                    const SizedBox(width: 4),
                    Text(
                      'Push Notifications',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: onSurface,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),

              // Notification toggle list
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: Column(
                    children: [
                      _pill(
                        title: 'Receive Push Notifications',
                        subtitle:
                            "Turn on to get tracking and reply notifications.",
                        value: enableAll,
                        onChanged: (v) async {
                          if (v) {
                            final granted =
                                await _requestNotificationPermission();
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
              ),

              // Bottom navigation
              _BottomNav(index: 2, userName: widget.userName),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int index;
  final String userName;
  const _BottomNav({required this.index, required this.userName});

  Color get _teal => const Color(0xFF0D7C66);
  Color _c(int i) => i == index ? _teal : Colors.white;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: Icon(Icons.home_filled, color: _c(0)),
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => HomePage(userName: userName),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.menu_book_rounded, color: _c(1)),
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => JournalPage(userName: userName),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.settings, color: _c(2)),
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsPage(userName: userName),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}




