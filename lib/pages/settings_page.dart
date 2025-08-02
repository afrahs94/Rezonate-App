// settings_page.dart
import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required String userName});

  Widget _buildSettingsButton(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 205, 156, 238),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.yellow, fontSize: 16),
              ),
              const Icon(Icons.arrow_forward, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 183, 164, 227),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color.fromARGB(255, 240, 240, 236), size: 30),
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  shape: const CircleBorder(),
                  backgroundColor: Colors.transparent,
                  padding: const EdgeInsets.all(10),
                ),
              ),
              const SizedBox(height: 10),
              const Text('account settings',
                  style: TextStyle(color: Color.fromARGB(255, 236, 231, 238), fontSize: 22, fontWeight: FontWeight.bold)),
              _buildSettingsButton('edit profile', () {}),
              _buildSettingsButton('change your password', () {}),
              _buildSettingsButton('security and privacy', () {}),
              const SizedBox(height: 30),
              const Text('notification settings',
                  style: TextStyle(color: Color.fromARGB(255, 245, 245, 240), fontSize: 22, fontWeight: FontWeight.bold)),
              _buildSettingsButton('push notifications', () {}),
              _buildSettingsButton('promotions', () {}),
              _buildSettingsButton('app updates', () {}),
              const Spacer(),
              GestureDetector(
                onTap: () {},
                child: const Padding(
                  padding: EdgeInsets.only(bottom: 30),
                  child: Text(
                    'deactivate account',
                    style: TextStyle(
                      color: Color.fromARGB(255, 241, 241, 237),
                      decoration: TextDecoration.underline,
                      fontSize: 16,
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

