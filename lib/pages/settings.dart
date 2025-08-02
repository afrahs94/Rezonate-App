// lib/pages/settings_page.dart

import 'package:flutter/material.dart';
import 'package:new_rezonate/pages/home.dart';
import 'package:new_rezonate/pages/journal.dart';
import 'package:new_rezonate/pages/edit_profile.dart';

class SettingsPage extends StatelessWidget {
  final String userName;
  const SettingsPage({super.key, required this.userName});

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );

  Widget _option(BuildContext ctx, String text, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 24.0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(32),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: Colors.pink.shade300,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.yellow.shade600,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_forward, color: Colors.white, size: 24),
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
            // Back button navigates to HomePage
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: InkWell(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HomePage(userName: userName),
                    ),
                  );
                },
                customBorder: const CircleBorder(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                ),
              ),
            ),

            // Account Settings
            _sectionTitle('account settings'),
            _option(context, 'edit profile', () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfilePage(userName: userName),
                ),
              );
            }),
            _option(context, 'change your password', () { /* TODO */ }),
            _option(context, 'security and privacy', () { /* TODO */ }),

            const SizedBox(height: 24),
            // Notification Settings
            _sectionTitle('notification settings'),
            _option(context, 'push notifications', () { /* TODO */ }),
            _option(context, 'promotions', () { /* TODO */ }),
            _option(context, 'app updates', () { /* TODO */ }),

            const Spacer(),
            // Deactivate Account
            Center(
              child: TextButton(
                onPressed: () { /* TODO deactivate */ },
                child: const Text(
                  'deactivate account',
                  style: TextStyle(
                    decoration: TextDecoration.underline,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // Bottom navigation bar
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
                    icon: Icons.grid_view,
                    label: 'dashboard',
                    isSelected: false,
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => HomePage(userName: userName)),
                      );
                    },
                  ),
                  _NavItem(
                    icon: Icons.favorite_border,
                    label: 'home',
                    isSelected: false,
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => JournalPage(userName: userName)),
                      );
                    },
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
    final color = isSelected ? Colors.purple : Colors.grey.shade600;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
