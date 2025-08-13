import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:new_rezonate/main.dart' as app;
import 'home.dart';
import 'journal.dart';
import 'settings.dart';

class SecurityAndPrivacyPage extends StatefulWidget {
  final String userName;
  const SecurityAndPrivacyPage({Key? key, required this.userName})
      : super(key: key);

  @override
  State<SecurityAndPrivacyPage> createState() => _SecurityAndPrivacyPageState();
}

class _SecurityAndPrivacyPageState extends State<SecurityAndPrivacyPage> {
  bool _appLock = false;
  bool _shareWithUsername = true;
  bool _anonymous = false;

  LinearGradient _bg(BuildContext context) {
    final dark = app.ThemeControllerScope.of(context).isDark;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: dark
        ? const [Color(0xFFBDA9DB), Color(0xFF3E8F84)]
        : const [Color(0xFFFFFFFF), Color(0xFFD7C3F1), Color(0xFF41B3A2)]
    );
  }

  @override
  Widget build(BuildContext context) {
    final green = const Color(0xFF0D7C66);

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
                      child: Text('Security & Privacy',
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // App lock pill
                      Container(
                        decoration: BoxDecoration(
                          color: green.withOpacity(.75),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 6)
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('App Lock',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16)),
                                  SizedBox(height: 2),
                                  Text('Enable PIN / Biometrics',
                                      style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                            Switch(
                              value: _appLock,
                              onChanged: (v) => setState(() => _appLock = v),
                              activeColor: Colors.white,
                              activeTrackColor: Colors.white54,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),
                      const _Header('Encryption'),
                      const Text('All journal entries are encrypted',
                          style: TextStyle(fontSize: 14)),
                      const SizedBox(height: 18),

                      const _Header('Default Entry Visibility'),
                      const Text('Always private (you control sharing)',
                          style: TextStyle(fontSize: 14)),
                      const SizedBox(height: 18),

                      const _Header('Public Sharing Options'),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Share with Username'),
                        value: _shareWithUsername,
                        onChanged: (v) =>
                            setState(() => _shareWithUsername = v ?? false),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Share Anonymously'),
                        value: _anonymous,
                        onChanged: (v) =>
                            setState(() => _anonymous = v ?? false),
                      ),
                      const SizedBox(height: 6),

                      const _Header('Privacy Policy'),
                      // -> White body text as requested
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white, // make body white
                          ),
                          children: [
                            const TextSpan(
                                text:
                                    'When entry is shared publicly, it will appear in the community feed. '
                                    'If "Share Anonymously" is selected, your identity won\'t be shown. '
                                    'If you want to learn more please click '),
                            TextSpan(
                              text: 'here.',
                              style: const TextStyle(
                                  decoration: TextDecoration.underline,
                                  color: Colors.white),
                              recognizer: TapGestureRecognizer()..onTap = () {},
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
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

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
          IconButton(icon: Icon(Icons.home, color: c(0)),
              onPressed: () => Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (_) => HomePage(userName: '')))),
          IconButton(icon: Icon(Icons.menu_book, color: c(1)),
              onPressed: () => Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (_) => JournalPage(userName: '')))),
          IconButton(icon: Icon(Icons.settings, color: c(2)),
              onPressed: () => Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (_) => SettingsPage(userName: '')))),
        ],
      ),
    );
  }
}
