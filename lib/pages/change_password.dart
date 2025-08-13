import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:new_rezonate/main.dart' as app; // ThemeControllerScope

class ChangePasswordPage extends StatefulWidget {
  final String userName;
  const ChangePasswordPage({Key? key, required this.userName}) : super(key: key);

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentCtl = TextEditingController();
  final _newCtl = TextEditingController();
  final _confirmCtl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _currentCtl.dispose();
    _newCtl.dispose();
    _confirmCtl.dispose();
    super.dispose();
  }

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

  Future<void> _save() async {
    final current = _currentCtl.text.trim();
    final next = _newCtl.text.trim();
    final confirm = _confirmCtl.text.trim();

    if (next.isEmpty || confirm.isEmpty || current.isEmpty) {
      _snack('Please fill out all fields.');
      return;
    }
    if (next != confirm) {
      _snack('New passwords do not match.');
      return;
    }

    setState(() => _saving = true);
    try {
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;
      if (user == null) {
        _snack('No user is signed in.');
        return;
      }

      // Reauthenticate (required by Firebase to change sensitive info)
      final email = user.email;
      if (email == null) {
        _snack('No email found on this account.');
        return;
      }
      final cred = EmailAuthProvider.credential(email: email, password: current);
      await user.reauthenticateWithCredential(cred);

      await user.updatePassword(next);
      _snack('Password changed successfully!');
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? 'Password change failed');
    } catch (e) {
      _snack('Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  InputDecoration _decor(String label,
      {bool highlight = false, BuildContext? context}) {
    final green = const Color(0xFF0D7C66);
    return InputDecoration(
      labelText: label,
      labelStyle:
          highlight ? TextStyle(color: green, fontWeight: FontWeight.w600) : null,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: highlight ? green : Colors.black26),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: green, width: 2),
      ),
      filled: true,
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
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Change Password',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _currentCtl,
                        obscureText: true,
                        decoration: _decor('Current Password',
                            highlight: true, context: context),
                        style: TextStyle(color: green), // text dark green
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _newCtl,
                        obscureText: true,
                        decoration: _decor('New Password'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirmCtl,
                        obscureText: true,
                        decoration: _decor('Confirm Password'),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 220,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: green,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28)),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Save', style: TextStyle(fontSize: 18)),
                        ),
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

/// Transparent bottom nav used across pages
class _BottomNav extends StatelessWidget {
  final int index; // 0 home, 1 journal, 2 settings
  const _BottomNav({required this.index});

  @override
  Widget build(BuildContext context) {
    final green = const Color(0xFF0D7C66);
    Color colorFor(int i) => i == index ? green : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(icon: Icon(Icons.home, color: colorFor(0)),
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst)),
          IconButton(icon: Icon(Icons.menu_book, color: colorFor(1)),
              onPressed: () {}),
          IconButton(icon: Icon(Icons.settings, color: colorFor(2)),
              onPressed: () {}),
        ],
      ),
    );
  }
}
