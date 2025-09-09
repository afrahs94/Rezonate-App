// lib/pages/security_and_privacy_page.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:new_rezonate/main.dart' as app;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import 'home.dart';
import 'journal.dart';
import 'settings.dart';
import 'signup_page.dart'; // <-- added to reuse Terms & Privacy page

class SecurityAndPrivacyPage extends StatefulWidget {
  final String userName;
  const SecurityAndPrivacyPage({Key? key, required this.userName})
      : super(key: key);

  @override
  State<SecurityAndPrivacyPage> createState() => _SecurityAndPrivacyPageState();
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

class _SecurityAndPrivacyPageState extends State<SecurityAndPrivacyPage> {
  bool _appLock = false;

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  LinearGradient _bg(BuildContext context) {
    final dark = app.ThemeControllerScope.of(context).isDark;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: dark
          ? const [Color(0xFFBDA9DB), Color(0xFF3E8F84)]
          : const [Color(0xFFFFFFFF), Color(0xFFD7C3F1), Color(0xFF41B3A2)],
    );
  }

  @override
  void initState() {
    super.initState();
    _policyTap = TapGestureRecognizer()..onTap = _openPrivacyPolicy;
    _loadSettings();
  }

  Future<void> _openPrivacyPolicy() async {
    // Open the in-app Terms & Privacy page and scroll to the Privacy section.
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TermsAndPrivacyPage(scrollToPrivacy: true),
      ),
    );
  }

  @override
  void dispose() {
    _policyTap.dispose();
    super.dispose();
  }

  // --------- Anonymity helpers ---------
  bool _deriveAnon(Map<String, dynamic>? data) {
    if (data == null) return false;
    bool anon = false;

    if (data['share_anonymously'] == true) anon = true;
    if (data['share_publicly'] == true) anon = false;
    if (data['anonymous'] == true) anon = true;

    final modeCamel = (data['shareMode'] as String?)?.toLowerCase().trim();
    if (modeCamel == 'anonymous') anon = true;
    if (modeCamel == 'public') anon = false;

    final modeSnake = (data['share_mode'] as String?)?.toLowerCase().trim();
    if (modeSnake == 'anonymous') anon = true;
    if (modeSnake == 'username' || modeSnake == 'public') anon = false;

    for (final e in data.entries) {
      final k = e.key.toLowerCase();
      final v = e.value;
      if (k.contains('anon')) {
        if (v is bool) anon = v;
        if (v is String) {
          final sv = v.toLowerCase().trim();
          if (sv == 'true' || sv == '1' || sv == 'yes' || sv == 'anonymous') {
            anon = true;
          }
          if (sv == 'false' || sv == '0' || sv == 'no' || sv == 'public') {
            anon = false;
          }
        }
      }
    }
    return anon;
  }

  Future<void> _setAnon(bool value) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to change anonymity')),
      );
      return;
    }
    await _db.collection('users').doc(uid).set({
      'share_anonymously': value,
      'share_publicly': !value,
      'anonymous': value,
      'shareMode': value ? 'anonymous' : 'public',
      'share_mode': value ? 'anonymous' : 'username',
    }, SetOptions(merge: true));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value ? 'Sharing anonymously enabled' : 'Sharing publicly enabled',
        ),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }
  // -------------------------------------

  Future<void> _forgotPin() async {
    final passCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? err;

    final user = _auth.currentUser;
    if (user == null) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            Future<void> onReset() async {
              final password = passCtrl.text.trim();
              final newPin = newCtrl.text.trim();
              final confirm = confirmCtrl.text.trim();

              if (password.isEmpty || newPin.isEmpty || confirm.isEmpty) {
                setLocal(() => err = "All fields required.");
                return;
              }
              if (newPin != confirm) {
                setLocal(() => err = "New PINs do not match.");
                return;
              }
              if (newPin.length < 4 || newPin.length > 8) {
                setLocal(() => err = "PIN must be 4–8 digits.");
                return;
              }

              try {
                final cred = EmailAuthProvider.credential(
                  email: user.email!,
                  password: password,
                );
                await user.reauthenticateWithCredential(cred);

                await _db.collection("users").doc(user.uid).set({
                  "journal_lock_pin": _hash(newPin),
                }, SetOptions(merge: true));

                if (mounted) Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("PIN reset successfully.")),
                );
              } on FirebaseAuthException catch (e) {
                setLocal(() => err = e.message ?? "Re-authentication failed.");
              }
            }

            return AlertDialog(
              title: const Text("Reset Journal PIN"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Account Password",
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: newCtrl,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: "New PIN"),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmCtrl,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: "Confirm New PIN",
                    ),
                  ),
                  if (err != null) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        err!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(onPressed: onReset, child: const Text("Reset")),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _changePin() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? err;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final doc = await _db.collection('users').doc(uid).get();
    final storedHash = doc.data()?['journal_lock_pin'] as String?;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            Future<void> onSave() async {
              final curr = currentCtrl.text.trim();
              final newPin = newCtrl.text.trim();
              final confirm = confirmCtrl.text.trim();

              if (curr.isEmpty || newPin.isEmpty || confirm.isEmpty) {
                setLocal(() => err = 'All fields required.');
                return;
              }
              if (_hash(curr) != storedHash) {
                setLocal(() => err = 'Current PIN incorrect.');
                return;
              }
              if (newPin != confirm) {
                setLocal(() => err = 'New PINs do not match.');
                return;
              }
              if (newPin.length < 4 || newPin.length > 8) {
                setLocal(() => err = 'New PIN must be 4–8 digits.');
                return;
              }

              await _db.collection('users').doc(uid).set({
                'journal_lock_pin': _hash(newPin),
              }, SetOptions(merge: true));
              if (mounted) Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PIN changed successfully.')),
              );
            }

            return AlertDialog(
              title: const Text('Change Journal PIN'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentCtrl,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Current PIN'),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        _forgotPin();
                      },
                      child: const Text(
                        "Forgot PIN?",
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF0D7C66),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: newCtrl,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'New PIN'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmCtrl,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Confirm New PIN',
                    ),
                  ),
                  if (err != null) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        err!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(onPressed: onSave, child: const Text('Save')),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _loadSettings() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final snap = await _db.collection('users').doc(uid).get();
    final d = snap.data();
    if (d == null) return;

    setState(() {
      _appLock = (d['journal_lock_enabled'] as bool?) ?? false;
    });
  }

  String _hash(String v) => sha256.convert(utf8.encode(v)).toString();

  Future<void> _saveAppLock(bool enabled) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({
      'journal_lock_enabled': enabled,
    }, SetOptions(merge: true));
  }

  Future<String?> _resolveUsername(String uid) async {
    if (uid.isEmpty) return null;
    try {
      final snap = await _db.collection('users').doc(uid).get();
      final name = (snap.data()?['username'] as String?)?.trim();
      if (name != null && name.isNotEmpty) return name;
    } catch (_) {}
    return null;
  }

  Future<bool> _ensurePin() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    final doc = await _db.collection('users').doc(uid).get();
    final hasPin =
        (doc.data()?['journal_lock_pin'] as String?)?.isNotEmpty == true;
    if (hasPin) return true;
    return await _promptCreatePin();
  }

  Future<bool> _promptCreatePin() async {
    final pinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? err;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            Future<void> onSave() async {
              final pin = pinCtrl.text.trim();
              final confirm = confirmCtrl.text.trim();

              if (pin.isEmpty || confirm.isEmpty) {
                setLocal(() => err = 'Enter and confirm your PIN.');
                return;
              }
              if (pin != confirm) {
                setLocal(() => err = 'PINs do not match.');
                return;
              }
              if (pin.length < 4 || pin.length > 8) {
                setLocal(() => err = 'PIN must be 4–8 digits.');
                return;
              }
              final uid = _auth.currentUser?.uid;
              if (uid == null) {
                setLocal(() => err = 'Not signed in.');
                return;
              }
              await _db.collection('users').doc(uid).set({
                'journal_lock_pin': _hash(pin),
              }, SetOptions(merge: true));
              if (mounted) Navigator.of(context).pop(true);
            }

            return AlertDialog(
              title: const Text('Create PIN for My Journal'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: pinCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'PIN (4–8 digits)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Confirm PIN'),
                  ),
                  if (err != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        err!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(onPressed: onSave, child: const Text('Save')),
              ],
            );
          },
        );
      },
    );

    return ok == true;
  }

  Future<void> _unblockUser(String uid) async {
    final me = _auth.currentUser;
    if (me == null) return;

    final uname = (await _resolveUsername(uid)) ?? '';
    await _db.collection('users').doc(me.uid).set({
      'blocked_uids': FieldValue.arrayRemove([uid]),
      if (uname.isNotEmpty)
        'blocked_usernames': FieldValue.arrayRemove([uname]),
    }, SetOptions(merge: true));

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('User unblocked.')));
  }

  Future<void> _showBlockedSheet() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to manage blocked users.')),
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onText = isDark ? Colors.white : Colors.black;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: isDark ? const Color(0xFF123A36) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.6,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'Blocked Users',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: onText,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: StreamBuilder<
                        DocumentSnapshot<Map<String, dynamic>>>(
                      stream: _db.collection('users').doc(uid).snapshots(),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final data = snap.data?.data() ?? {};
                        final blockedUids =
                            (data['blocked_uids'] as List?)?.cast<String>() ??
                                [];

                        if (blockedUids.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'No blocked users.',
                                style: TextStyle(color: onText),
                              ),
                            ),
                          );
                        }

                        return FutureBuilder<List<String>>(
                          future: Future.wait(
                            blockedUids.map((id) async {
                              final name = await _resolveUsername(id);
                              return (name == null || name.isEmpty)
                                  ? id
                                  : '@$name';
                            }),
                          ),
                          builder: (context, namesSnap) {
                            if (!namesSnap.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            final names = namesSnap.data!;
                            return ListView.separated(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              itemCount: blockedUids.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final uidItem = blockedUids[i];
                                final label = names[i];
                                return ListTile(
                                  leading: const Icon(
                                    Icons.block,
                                    color: Colors.red,
                                  ),
                                  title: Text(
                                    label,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: onText,
                                    ),
                                  ),
                                  trailing: TextButton(
                                    onPressed: () => _unblockUser(uidItem),
                                    child: const Text('Unblock'),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final green = const Color(0xFF0D7C66);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onText = isDark ? Colors.white : Colors.black;

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
                      icon: Icon(Icons.arrow_back, color: onText),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Security & Privacy',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: onText,
                        ),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // My Journal Lock pill
                      Container(
                        decoration: BoxDecoration(
                          color: green.withOpacity(.75),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 6),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'My Journal Lock',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Enable PIN / Biometrics',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _appLock,
                              onChanged: (v) async {
                                if (v) {
                                  final ok = await _ensurePin();
                                  if (!mounted) return;
                                  if (ok) {
                                    setState(() => _appLock = true);
                                    await _saveAppLock(true);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('My Journal Lock enabled.'),
                                      ),
                                    );
                                  } else {
                                    setState(() => _appLock = false);
                                  }
                                } else {
                                  setState(() => _appLock = false);
                                  await _saveAppLock(false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('My Journal Lock disabled.'),
                                    ),
                                  );
                                }
                              },
                              activeColor: Colors.white,
                              activeTrackColor: Colors.white54,
                            ),
                          ],
                        ),
                      ),
                      if (_appLock) ...[
                        const SizedBox(height: 7),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: _changePin,
                            child: Text(
                              'Change PIN',
                              style: TextStyle(
                                color: green,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 9),
                      const _Header('Encryption'),
                      Text(
                        'All journal entries are encrypted',
                        style: TextStyle(fontSize: 14, color: onText),
                      ),
                      const SizedBox(height: 18),

                      const _Header('Public Sharing'),
                      Builder(
                        builder: (ctx) {
                          final u = _auth.currentUser;
                          if (u == null) {
                            return const _AnonRow(
                              on: false,
                              enabled: false,
                              onChanged: null,
                            );
                          }
                          return StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>>(
                            stream:
                                _db.collection('users').doc(u.uid).snapshots(),
                            builder: (context, snap) {
                              final data = snap.data?.data();
                              final on = _deriveAnon(data);
                              return _AnonRow(
                                on: on,
                                enabled: true,
                                onChanged: (v) => _setAnon(v),
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 18),

                      const _Header('Blocked Users'),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0x1AFFFFFF)
                              : Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 6),
                          ],
                        ),
                        child: ListTile(
                          leading: const Icon(
                            Icons.block,
                            color: Colors.redAccent,
                          ),
                          title: Text(
                            'View blocked users',
                            style: TextStyle(color: onText),
                          ),
                          trailing: Icon(Icons.chevron_right, color: onText),
                          onTap: _showBlockedSheet,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _Header('Privacy Policy'),
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 14,
                            color: onText,
                          ),
                          children: [
                            const TextSpan(
                              text:
                                  'When entry is shared publicly, it will appear in the community feed. '
                                  'If "Share anonymously" is enabled, your identity is hidden on past and future posts & replies. '
                                  'For more details, tap ',
                            ),
                            TextSpan(
                              text: 'here.',
                              style: TextStyle(
                                decoration: TextDecoration.underline,
                                color: onText,
                                fontWeight: FontWeight.w600,
                              ),
                              recognizer: _policyTap,
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

  late final TapGestureRecognizer _policyTap;
}

class _AnonRow extends StatelessWidget {
  final bool on;
  final bool enabled;
  final ValueChanged<bool>? onChanged;
  const _AnonRow({required this.on, required this.enabled, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final green = const Color(0xFF0D7C66);
    return Container(
      decoration: BoxDecoration(
        color: green.withOpacity(.75),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.visibility_off_outlined, color: Colors.white),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Share anonymously',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          Switch(
            value: on,
            onChanged: enabled ? onChanged : null,
            activeColor: Colors.white,
            activeTrackColor: Colors.white54,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) {
    final onText =
        Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: onText,
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color c(int i) => i == index
        ? (isDark ? const Color(0xFF9B5DE5) : green) // purple when dark
        : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(Icons.home, color: c(0)),
            onPressed: () => Navigator.pushReplacement(
              context,
              NoTransitionPageRoute(builder: (_) => HomePage(userName: '')),
            ),
          ),
          IconButton(
            icon: Icon(Icons.menu_book, color: c(1)),
            onPressed: () => Navigator.pushReplacement(
              context,
              NoTransitionPageRoute(builder: (_) => JournalPage(userName: '')),
            ),
          ),
          IconButton(
            icon: Icon(Icons.settings, color: c(2)),
            onPressed: () => Navigator.pushReplacement(
              context,
              NoTransitionPageRoute(builder: (_) => SettingsPage(userName: '')),
            ),
          ),
        ],
      ),
    );
  }
}