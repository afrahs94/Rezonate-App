// lib/pages/security_and_privacy_page.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:new_rezonate/main.dart' as app;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'home.dart';
import 'journal.dart';
import 'settings.dart';

class SecurityAndPrivacyPage extends StatefulWidget {
  final String userName;
  const SecurityAndPrivacyPage({Key? key, required this.userName})
      : super(key: key);

  @override
  State<SecurityAndPrivacyPage> createState() => _SecurityAndPrivacyPageState();
}

class _SecurityAndPrivacyPageState extends State<SecurityAndPrivacyPage> {
  bool _appLock = false;
  bool _shareWithUsername = true;
  bool _anonymous = false;

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
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final snap = await _db.collection('users').doc(uid).get();
    final d = snap.data();
    if (d == null) return;

    final mode = (d['share_mode'] as String?) ?? 'username';
    setState(() {
      _appLock = (d['journal_lock_enabled'] as bool?) ?? false;
      _shareWithUsername = mode == 'username';
      _anonymous = mode == 'anonymous';
    });
  }

  String _hash(String v) => sha256.convert(utf8.encode(v)).toString();

  Future<void> _saveShareMode(String mode) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db
        .collection('users')
        .doc(uid)
        .set({'share_mode': mode}, SetOptions(merge: true));
  }

  Future<void> _saveAppLock(bool enabled) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db
        .collection('users')
        .doc(uid)
        .set({'journal_lock_enabled': enabled}, SetOptions(merge: true));
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
              await _db
                  .collection('users')
                  .doc(uid)
                  .set({'journal_lock_pin': _hash(pin)}, SetOptions(merge: true));
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
                    decoration:
                        const InputDecoration(labelText: 'PIN (4–8 digits)'),
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
                      child: Text(err!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 13)),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel')),
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
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('User unblocked.')));
  }

  // ---------- NEW: blocked list pop-up sheet ----------
  Future<void> _showBlockedSheet() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in to manage blocked users.')));
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.6,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text('Blocked Users',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: StreamBuilder<
                        DocumentSnapshot<Map<String, dynamic>>>(
                      stream: _db.collection('users').doc(uid).snapshots(),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final data = snap.data?.data() ?? {};
                        final blockedUids =
                            (data['blocked_uids'] as List?)?.cast<String>() ??
                                [];

                        if (blockedUids.isEmpty) {
                          return const Center(
                              child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('No blocked users.'),
                          ));
                        }

                        // Resolve usernames for each UID
                        return FutureBuilder<List<String>>(
                          future: Future.wait(blockedUids.map((id) async {
                            final name = await _resolveUsername(id);
                            return (name == null || name.isEmpty)
                                ? id
                                : '@$name';
                          })),
                          builder: (context, namesSnap) {
                            if (!namesSnap.hasData) {
                              return const Center(
                                  child: CircularProgressIndicator());
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
                                  leading: const Icon(Icons.block,
                                      color: Colors.red),
                                  title: Text(label,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
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
  // ----------------------------------------------------

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
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                SettingsPage(userName: widget.userName)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Security & Privacy',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w700)),
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
                      // My Journal Lock pill (unchanged)
                      Container(
                        decoration: BoxDecoration(
                          color: green.withOpacity(.75),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 6)
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('My Journal Lock',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16)),
                                  SizedBox(height: 2),
                                  Text('Enable PIN / Biometrics',
                                      style: TextStyle(color: Colors.white)),
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
                                          content: Text(
                                              'My Journal Lock enabled.')),
                                    );
                                  } else {
                                    setState(() => _appLock = false);
                                  }
                                } else {
                                  setState(() => _appLock = false);
                                  await _saveAppLock(false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'My Journal Lock disabled.')),
                                  );
                                }
                              },
                              activeColor: Colors.white,
                              activeTrackColor: Colors.white54,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),
                      const _Header('Encryption'),
                      const Text('All journal entries are encrypted',
                          style: TextStyle(fontSize: 14)),
                      const SizedBox(height: 18),

                      const _Header('Default Entry Visibility'),
                      const Text('Always sharing (you can go anonymous)',
                          style: TextStyle(fontSize: 14)),
                      const SizedBox(height: 18),

                      const _Header('Public Sharing Options'),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Share with Username'),
                        value: _shareWithUsername,
                        onChanged: (v) async {
                          final val = v ?? false;
                          setState(() {
                            _shareWithUsername = val;
                            if (val) _anonymous = false;
                          });
                          if (val) await _saveShareMode('username');
                        },
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Share Anonymously'),
                        value: _anonymous,
                        onChanged: (v) async {
                          final val = v ?? false;
                          setState(() {
                            _anonymous = val;
                            if (val) _shareWithUsername = false;
                          });
                          if (val) await _saveShareMode('anonymous');
                        },
                      ),
                      const SizedBox(height: 18),

                      // --------- REPLACED: show a button that opens the pop-up sheet ---------
                      const _Header('Blocked Users'),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 6)
                          ],
                        ),
                        child: ListTile(
                          leading:
                              const Icon(Icons.block, color: Colors.redAccent),
                          title: const Text('View blocked users'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _showBlockedSheet,
                        ),
                      ),
                      const SizedBox(height: 18),
                      // ---------------------------------------------------------------------

                      const _Header('Privacy Policy'),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                          children: [
                            const TextSpan(
                                text:
                                    'When entry is shared publicly, it will appear in the community feed. '
                                    'If "Share Anonymously" is selected, your identity won\'t be shown. '
                                    'If you want to learn more please click '),
                            TextSpan(
                              text: 'here.',
                              style: const TextStyle(
                                  decoration: TextDecoration.underline,
                                  color: Colors.white),
                              recognizer: TapGestureRecognizer()..onTap = () {},
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
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
    Color c(int i) => i == index ? green : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
              icon: Icon(Icons.home, color: c(0)),
              onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => HomePage(userName: '')))),
          IconButton(
              icon: Icon(Icons.menu_book, color: c(1)),
              onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => JournalPage(userName: '')))),
          IconButton(
              icon: Icon(Icons.settings, color: c(2)),
              onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SettingsPage(userName: '')))),
        ],
      ),
    );
  }
}
