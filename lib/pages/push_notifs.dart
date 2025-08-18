import 'package:flutter/material.dart';
import 'package:new_rezonate/main.dart' as app;
import 'home.dart';
import 'journal.dart';
import 'settings.dart';
import 'services/user_settings.dart';

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

  @override
  void initState() {
    super.initState();
    enableAll = UserSettings.pushEnabled;
    daily = UserSettings.dailyReminderEnabled;
    replies = UserSettings.replyNotificationsEnabled;
  }

  LinearGradient _bg(BuildContext context) {
    final dark = app.ThemeControllerScope.of(context).isDark;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: dark
          ? const [Color(0xFFBDA9DB), Color(0xFF3E8F84)]
          : const [Color(0xFFFFFFFF), Color(0xFFD7C3F1), Color(0xFF41B3A2)],
    );
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: _bg(context)),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                SettingsPage(userName: widget.userName)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Push Notifications',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 48),
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
                        subtitle:
                            "Turn on to get tracking and reply notifications.",
                        value: enableAll,
                        onChanged: (v) {
                          setState(() {
                            enableAll = v;
                            UserSettings.pushEnabled = v;

                            if (!v) {
                              daily = false;
                              replies = false;
                              UserSettings.dailyReminderEnabled = false;
                              UserSettings.replyNotificationsEnabled = false;
                            }
                          });
                        },
                      ),
                      _pill(
                        title: 'Daily Tracking Reminder',
                        subtitle:
                            "Send a friendly reminder if you haven’t tracked today.",
                        value: daily,
                        onChanged: enableAll
                            ? (v) {
                                setState(() {
                                  daily = v;
                                  UserSettings.dailyReminderEnabled = v;
                                });
                              }
                            : null,
                      ),
                      _pill(
                        title: 'Replies to your Posts',
                        subtitle:
                            "Receive notifications about replies on the community feed.",
                        value: replies,
                        onChanged: enableAll
                            ? (v) {
                                setState(() {
                                  replies = v;
                                  UserSettings.replyNotificationsEnabled = v;
                                });
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              const _BottomNav(index: 2),
            ],
          ),
        ),
      ),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
              icon: Icon(Icons.home, color: c(0)),
              onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => HomePage(userName: '')))),
          IconButton(
              icon: Icon(Icons.menu_book, color: c(1)),
              onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => JournalPage(userName: '')))),
          IconButton(
              icon: Icon(Icons.settings, color: c(2)),
              onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}
