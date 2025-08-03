import 'package:flutter/material.dart';
import 'package:new_rezonate/pages/home.dart';
import 'package:new_rezonate/pages/journal.dart';
import 'package:new_rezonate/pages/settings.dart';
import 'package:new_rezonate/pages/services/user_settings.dart';

class SecurityAndPrivacyPage extends StatefulWidget {
  final String userName;
  const SecurityAndPrivacyPage({Key? key, required this.userName}) : super(key: key);

  @override
  _SecurityAndPrivacyPageState createState() => _SecurityAndPrivacyPageState();
}

class _SecurityAndPrivacyPageState extends State<SecurityAndPrivacyPage> {
  bool _anon = UserSettings.anonymous;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // Back button → Settings
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => SettingsPage(userName: widget.userName)),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                'Security & Privacy',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),

            // Anonymous toggle
            SwitchListTile(
              title: const Text('Go Anonymous'),
              subtitle: const Text('Hide your username on public posts'),
              value: _anon,
              onChanged: (v) {
                setState(() {
                  _anon = v;
                  UserSettings.anonymous = v;
                });
              },
            ),
            const Divider(),

            // Other items
            ListTile(
              title: const Text('Help'),
              trailing: const Icon(Icons.help_outline),
              onTap: () {}, // TODO
            ),
            ListTile(
              title: const Text('Privacy Policy'),
              trailing: const Icon(Icons.policy),
              onTap: () {}, // TODO
            ),
            ListTile(
              title: const Text('Hidden Words'),
              trailing: const Icon(Icons.visibility_off),
              onTap: () {}, // TODO
            ),
            const Spacer(),

            // Bottom nav
            Container(
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _NavItem(
                    icon: Icons.home,
                    label: 'dashboard',
                    isSelected: false,
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => HomePage(userName: widget.userName)),
                    ),
                  ),
                  _NavItem(
                    icon: Icons.bookmarks,
                    label: 'journal',
                    isSelected: false,
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => JournalPage(userName: widget.userName)),
                    ),
                  ),
                  _NavItem(
                    icon: Icons.settings,
                    label: 'settings',
                    isSelected: true,
                    onTap: () {}, // already here
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? Colors.blueGrey : Colors.grey.shade600;
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 28, color: color),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ]),
    );
  }
}
