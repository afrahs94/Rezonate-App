// lib/pages/settings_page.dart

import 'package:flutter/material.dart';
import 'package:new_rezonate/pages/home.dart';
import 'package:new_rezonate/pages/journal.dart';
import 'package:new_rezonate/pages/edit_profile.dart';
import 'package:new_rezonate/pages/change_password.dart';
import 'package:new_rezonate/pages/security_privacy.dart';
import 'package:new_rezonate/pages/push_notifs.dart';
import 'package:new_rezonate/pages/promotions.dart';
import 'package:new_rezonate/pages/app_updates.dart';
import 'package:new_rezonate/pages/deactivate.dart';

class SettingsPage extends StatelessWidget {
  final String userName;
  const SettingsPage({Key? key, required this.userName}) : super(key: key);

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );

  Widget _option(BuildContext ctx, String text, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(32),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.pink.shade300,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Row(
              children: [
                Expanded(
                    child: Text(text,
                        style: TextStyle(
                            fontSize: 16, color: Colors.yellow.shade600))),
                const Icon(Icons.arrow_forward, color: Colors.white),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.purple.shade300,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back → HomePage
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => HomePage(userName: userName),
                ),
              ),
            ),

            _section('Account Settings'),
            _option(context, 'Edit Profile', () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfilePage(userName: userName)));
            }),
            _option(context, 'Change Your Password', () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ChangePasswordPage()));
            }),
            _option(context, 'Security & Privacy', () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SecurityAndPrivacyPage(userName: userName)));
            }),

            _section('Notification Settings'),
            _option(context, 'Push Notifications', () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => PushNotificationsPage()));
            }),
            _option(context, 'Promotions', () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => PromotionsPage()));
            }),
            _option(context, 'App Updates', () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => AppUpdatesPage()));
            }),

            _section('Account Actions'),
            _option(context, 'Deactivate Account', () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => DeactivateAccountPage()));
            }),

            const Spacer(),
            const SizedBox(height: 16),
          ],
        ),
      ),

      bottomNavigationBar: Container(
        height: 64,
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
              label: 'Dashboard',
              selected: false,
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => HomePage(userName: userName)),
              ),
            ),
            _NavItem(
              icon: Icons.bookmarks,
              label: 'Journal',
              selected: false,
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => JournalPage(userName: userName)),
              ),
            ),
            _NavItem(
              icon: Icons.settings,
              label: 'Settings',
              selected: true,
              onTap: () {},
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
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.purple : Colors.grey.shade600;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}
