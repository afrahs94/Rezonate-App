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

class NoTransitionPageRoute<T> extends MaterialPageRoute<T> {
  NoTransitionPageRoute({required WidgetBuilder builder})
      : super(builder: builder);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child; // no animation
  }
}

class _DeactivateAccountPageState extends State<DeactivateAccountPage> {
  bool _working = false;

  Color get _brand => const Color(0xFF0D7C66);
  Color get _danger => const Color(0xFFE35D5D);

  LinearGradient _bg(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: dark
          // unified dark gradient
          ? const [Color(0xFFBDA9DB), Color(0xFF3E8F84)]
          : const [Color(0xFFFFFFFF), Color(0xFFD7C3F1), Color(0xFF41B3A2)],
    );
  }

  // Ask the user to confirm before deleting
  Future<void> _confirmAndDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Delete account?'),
        content: const Text(
          'This will permanently remove your account and all data. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _deleteAccount();
    }
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
      String msg = e.message ?? 'Account deletion failed.';
      if (e.code == 'requires-recent-login') {
        msg = 'For security, please log in again and then delete your account.';
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
    final isDark = theme.brightness == Brightness.dark;
    final onText =
        isDark ? Colors.white : theme.colorScheme.onSurface.withOpacity(0.9);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: _bg(context)),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar: back + title (slightly smaller)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 16, 6),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: onText),
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          Navigator.of(context).pushReplacement(
                            PageRouteBuilder(
                              pageBuilder: (_, __, ___) =>
                                  SettingsPage(userName: widget.userName),
                              transitionDuration: Duration.zero,
                              reverseTransitionDuration: Duration.zero,
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Deactivate Account',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: onText,
                        fontSize: 20, // smaller
                      ),
                    ),
                  ],
                ),
              ),

              // Full logo at the top
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Image.asset(
                  'assets/images/Full_logo.png',
                  height: 230,
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(height: 12),

              // Body copy
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: theme.textTheme.titleMedium?.copyWith(
                              height: 1.4,
                              color: onText,
                              fontSize: 18,
                            ),
                            children: const [
                              TextSpan(
                                text:
                                    'Deleting your account will permanently remove ',
                              ),
                              TextSpan(
                                text: 'all',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              TextSpan(
                                  text: ' your journal entries and data.'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: theme.textTheme.titleMedium?.copyWith(
                              height: 1.4,
                              color: onText,
                              fontSize: 18,
                            ),
                            children: const [
                              TextSpan(text: 'This action cannot be '),
                              TextSpan(
                                text: 'undone',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              TextSpan(
                                text:
                                    '. Please save any information you want to keep before proceeding.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Buttons row
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _working
                            ? null
                            : () {
                                Navigator.pushReplacement(
                                  context,
                                  NoTransitionPageRoute(
                                    builder: (_) => SettingsPage(
                                      userName: widget.userName,
                                    ),
                                  ),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brand,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontSize: 15),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _working ? null : _confirmAndDelete,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _danger,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _working
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Delete',
                                style: TextStyle(fontSize: 15),
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom navigation — matches other pages
              _BottomNav(index: 2, userName: widget.userName),
            ],
          ),
        ),
      ),
    );
  }
}

// Same bottom nav look/behavior as other pages
class _BottomNav extends StatelessWidget {
  final int index; // 0=home, 1=journal, 2=settings
  final String userName;
  const _BottomNav({required this.index, required this.userName});

  Color get _teal => const Color(0xFF0D7C66);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color _c(int i) =>
        i == index ? (isDark ? const Color(0xFF9B5DE5) : _teal) : Colors.white;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: Icon(Icons.home_filled, color: _c(0)),
              onPressed: () => Navigator.pushReplacement(
                context,
                NoTransitionPageRoute(
                  builder: (_) => HomePage(userName: userName),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.menu_book_rounded, color: _c(1)),
              onPressed: () => Navigator.pushReplacement(
                context,
                NoTransitionPageRoute(
                  builder: (_) => JournalPage(userName: userName),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.settings, color: _c(2)),
              onPressed: () => Navigator.pushReplacement(
                context,
                NoTransitionPageRoute(
                  builder: (_) => SettingsPage(userName: userName),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
