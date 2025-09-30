import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'home.dart';
import 'journal.dart';
import 'settings.dart';
import 'package:new_rezonate/pages/services/firestore_service.dart';
import 'dart:io' show Platform;             
import 'package:permission_handler/permission_handler.dart';


class PushNotificationsPage extends StatefulWidget {
  final String userName;
  const PushNotificationsPage({super.key, required this.userName});

  @override
  State<PushNotificationsPage> createState() => _PushNotificationsPageState();
}

class NoTransitionPageRoute<T> extends MaterialPageRoute<T> {
  NoTransitionPageRoute({required WidgetBuilder builder}) : super(builder: builder);
  @override
  Widget buildTransitions(BuildContext context, Animation<double> a, Animation<double> b, Widget child) => child;
}

class _PushNotificationsPageState extends State<PushNotificationsPage> {
  bool enableAll = false;
  bool daily = false;
  bool replies = false;
  bool mentions = false;
  bool reactions = false;

  final _auth = FirebaseAuth.instance;
  final _firestoreService = FirestoreService();
  StreamSubscription<String>? _tokenSub;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    // keep token fresh
    _tokenSub = FirebaseMessaging.instance.onTokenRefresh.listen((t) async {
      final uid = _auth.currentUser?.uid;
      if (uid != null && t.isNotEmpty) {
        await _firestoreService.updateFcmToken(uid, t);
      }
    });
  }

  @override
  void dispose() {
    _tokenSub?.cancel();
    super.dispose();
  }

  LinearGradient _bg(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? const [Color(0xFFBDA9DB), Color(0xFF3E8F84)]
          : const [Color(0xFFFFFFFF), Color(0xFFD7C3F1), Color(0xFF41B3A2)],
    );
  }

  Future<void> _loadSettings() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final s = await _firestoreService.getNotificationSettings(uid);

    setState(() {
      // defaults = on (you can flip to false if you prefer opt-in)
      enableAll = s['push_enabled'] ?? false;
      daily     = s['reminders_enabled'] ?? false;
      replies   = s['replies_enabled'] ?? false;
      mentions  = s['mentions_enabled'] ?? false;
      reactions = s['reactions_enabled'] ?? false;
    });
  }

  Future<void> _saveSettings({
    bool? push,
    bool? reminders,
    bool? repliesOn,
    bool? mentionsOn,
    bool? reactionsOn,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final pushState = push ?? enableAll;

    await _firestoreService.updateNotificationSettings(
      uid,
      pushEnabled: pushState,
      remindersEnabled: reminders ?? daily,
      repliesEnabled: repliesOn ?? replies,
      mentionsEnabled: mentionsOn ?? mentions,
      reactionsEnabled: reactionsOn ?? reactions,
    );

    if (pushState) {
      await _registerFcmToken();
    }
  }

  Future<bool> _requestNotificationPermission() async {
  if (Platform.isAndroid) {
    final status = await Permission.notification.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification permission denied.')),
        );
      }
      return false;
    }
  }
  final settings = await FirebaseMessaging.instance.requestPermission(
    alert: true, badge: true, sound: true, provisional: true,
  );
  final ok = settings.authorizationStatus == AuthorizationStatus.authorized ||
             settings.authorizationStatus == AuthorizationStatus.provisional;
  if (ok) await _registerFcmToken();
  return ok;
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
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(.9))),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: Colors.white.withOpacity(.5),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onText = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: _bg(context)),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 16, 6),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: onText),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Push Notifications',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: onText.withOpacity(0.9),
                            fontSize: 20,
                          ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: Column(
                    children: [
                      _pill(
                        title: 'Receive Push Notifications',
                        subtitle: "Turn on to get daily writing reminders and activity on your posts.",
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
                              mentions = false;
                              reactions = false;
                            }
                          });
                          await _saveSettings(
                            push: v,
                            reminders: v ? daily : false,
                            repliesOn: v ? replies : false,
                            mentionsOn: v ? mentions : false,
                            reactionsOn: v ? reactions : false,
                          );
                        },
                      ),
                      _pill(
                        title: 'Daily Writing Reminder',
                        subtitle: "Get a gentle nudge to journal each day.",
                        value: daily,
                        onChanged: enableAll
                            ? (v) async {
                                setState(() => daily = v);
                                await _saveSettings(reminders: v);
                              }
                            : null,
                      ),
                      _pill(
                        title: 'Replies to Your Posts',
                        subtitle: "Notifications for new replies on the Community feed.",
                        value: replies,
                        onChanged: enableAll
                            ? (v) async {
                                setState(() => replies = v);
                                await _saveSettings(repliesOn: v);
                              }
                            : null,
                      ),
                      _pill(
                        title: 'Mentions (@you)',
                        subtitle: "When someone mentions you in a post or reply.",
                        value: mentions,
                        onChanged: enableAll
                            ? (v) async {
                                setState(() => mentions = v);
                                await _saveSettings(mentionsOn: v);
                              }
                            : null,
                      ),
                      _pill(
                        title: 'Reactions',
                        subtitle: "When someone reacts to your post or reply.",
                        value: reactions,
                        onChanged: enableAll
                            ? (v) async {
                                setState(() => reactions = v);
                                await _saveSettings(reactionsOn: v);
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
              ),

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color _c(int i) => i == index ? (isDark ? const Color(0xFF9B5DE5) : _teal) : Colors.white;

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
                NoTransitionPageRoute(builder: (_) => HomePage(userName: userName)),
              ),
            ),
            IconButton(
              icon: Icon(Icons.menu_book_rounded, color: _c(1)),
              onPressed: () => Navigator.pushReplacement(
                context,
                NoTransitionPageRoute(builder: (_) => JournalPage(userName: userName)),
              ),
            ),
            IconButton(
              icon: Icon(Icons.settings, color: _c(2)),
              onPressed: () => Navigator.pushReplacement(
                context,
                NoTransitionPageRoute(builder: (_) => SettingsPage(userName: userName)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
