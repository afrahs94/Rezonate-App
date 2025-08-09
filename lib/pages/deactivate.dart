// lib/pages/deactivate_account_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'home.dart';
import 'journal.dart';
import 'settings.dart';
import 'login_page.dart';

class DeactivateAccountPage extends StatefulWidget {
  final String userName;
  const DeactivateAccountPage({Key? key, required this.userName})
      : super(key: key);

  @override
  State<DeactivateAccountPage> createState() => _DeactivateAccountPageState();
}

class _DeactivateAccountPageState extends State<DeactivateAccountPage> {
  bool _working = false;

  Color get _brand => const Color(0xFF0D7C66);
  Color get _danger => const Color(0xFFE35D5D);

  LinearGradient _bg(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Light: lilac -> mint (mock)
    // Dark : deep teal -> dark mint (still readable)
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: dark
          ? const [Color(0xFF132C29), Color(0xFF1C6D60)]
          : const [Color(0xFFD7C3F1), Color(0xFFBDE8CA)],
    );
  }

  Future<void> _deleteAccount() async {
    final auth = FirebaseAuth.instance;
    final uid = auth.currentUser?.uid;

    if (uid == null) {
      _snack('No user session found.');
      return;
    }

    setState(() => _working = true);
    try {
      // 1) Delete Firestore profile (best-effort)
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();

      // 2) Delete Firebase Auth user
      await auth.currentUser!.delete();

      // 3) Go to login screen
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      // Most common: requires-recent-login
      String msg = e.message ?? 'Account deletion failed.';
      if (e.code == 'requires-recent-login') {
        msg =
            'For security, please log in again and then delete your account.';
      }
      _snack(msg);
    } catch (e) {
      _snack('Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface.withOpacity(0.9);

    return Scaffold(
      // No solid background; we paint a gradient behind everything
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: _bg(context)),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar: back + title
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back,
                          color: theme.colorScheme.onSurface),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SettingsPage(
                              userName: widget.userName,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Deactivate Account',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: onSurface,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Body text (two paragraphs, centered; bold certain words)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: theme.textTheme.titleMedium?.copyWith(
                          height: 1.4,
                          color: onSurface,
                          fontSize: 22,
                        ),
                        children: const [
                          TextSpan(
                              text:
                                  'Deleting your account will permanently remove '),
                          TextSpan(
                              text: 'all',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                          TextSpan(
                              text: ' your journal entries and data.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: theme.textTheme.titleMedium?.copyWith(
                          height: 1.4,
                          color: onSurface,
                          fontSize: 22,
                        ),
                        children: const [
                          TextSpan(text: 'This action cannot be '),
                          TextSpan(
                              text: 'undone',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                          TextSpan(
                              text:
                                  '. Please save any information you want to keep before proceeding.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Buttons row
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _working
                            ? null
                            : () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SettingsPage(
                                      userName: widget.userName,
                                    ),
                                  ),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brand,
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _working ? null : _deleteAccount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _danger,
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _working
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Delete', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),

              // Transparent bottom nav (no background)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 28, right: 28, bottom: 8, top: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _BottomIcon(
                        icon: Icons.home_rounded,
                        selected: false,
                        onTap: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                HomePage(userName: widget.userName),
                          ),
                        ),
                      ),
                      _BottomIcon(
                        icon: Icons.menu_book_rounded,
                        selected: false,
                        onTap: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                JournalPage(userName: widget.userName),
                          ),
                        ),
                      ),
                      _BottomIcon(
                        icon: Icons.settings_rounded,
                        selected: true, // we are inside settings flow
                        onTap: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SettingsPage(userName: widget.userName),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _BottomIcon({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brand = const Color(0xFF0D7C66);
    final off = Theme.of(context).colorScheme.onSurface.withOpacity(0.85);
    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: Icon(
        icon,
        size: 28,
        color: selected ? brand : off,
      ),
    );
  }
}
