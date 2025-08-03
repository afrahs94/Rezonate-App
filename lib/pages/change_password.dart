// lib/pages/change_password_page.dart

import 'package:flutter/material.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({Key? key}) : super(key: key);

  @override
  _ChangePasswordPageState createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentCtl = TextEditingController();
  final _newCtl = TextEditingController();
  final _confirmCtl = TextEditingController();

  // In a real app, fetch this from your auth logic
  final String _storedPassword = 'password123';

  void _save() {
    final current = _currentCtl.text.trim();
    final next = _newCtl.text.trim();
    final confirm = _confirmCtl.text.trim();

    if (current != _storedPassword) {
      _showError('Current password is incorrect.');
      return;
    }
    if (next != confirm) {
      _showError('New passwords do not match.');
      return;
    }
    // TODO: call your backend to update password
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password changed successfully!')),
    );
    Navigator.pop(context);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Widget _field(String label, TextEditingController ctl, {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 24.0),
      child: TextField(
        controller: ctl,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Password'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _field('Current Password', _currentCtl, obscure: true),
          _field('New Password', _newCtl, obscure: true),
          _field('Confirm New Password', _confirmCtl, obscure: true),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
