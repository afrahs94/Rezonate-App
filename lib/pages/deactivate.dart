// lib/pages/deactivate_account_page.dart

import 'package:flutter/material.dart';

class DeactivateAccountPage extends StatelessWidget {
  const DeactivateAccountPage({Key? key}) : super(key: key);

  void _confirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Deactivation'),
        content: const Text(
            'This will permanently deactivate your account. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () {
                // TODO: call deactivate API
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Account deactivated.')));
              },
              child: const Text('Deactivate')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Deactivate Account')),
      body: Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => _confirm(context),
          child: const Text('Deactivate My Account'),
        ),
      ),
    );
  }
}
