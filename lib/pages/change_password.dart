// lib/pages/change_password_page.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';               // for sha256
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'settings.dart';

class ChangePasswordPage extends StatefulWidget {
  final String userName; // kept for your existing navigation pattern
  const ChangePasswordPage({Key? key, required this.userName}) : super(key: key);

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  bool _saving = false;

  // Inline errors (red) shown under fields
  String? _currentError;
  String? _newError;
  String? _confirmError;

  Color get _brand => const Color(0xFF0D7C66);

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ---------- Password rules: same as sign-up ----------
  bool _isStrongPassword(String p) {
    if (p.length < 6) return false;
    if (!RegExp(r'\d').hasMatch(p)) return false;           // at least one number
    if (!RegExp(r'[^\w\s]').hasMatch(p)) return false;      // at least one special char
    return true;
  }

  String _hash(String v) => sha256.convert(utf8.encode(v)).toString();

  InputDecoration _dec(String hint, {Widget? suffix, String? errorText}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      suffixIcon: suffix,
      errorText: errorText,
      errorStyle: const TextStyle(color: Colors.red, fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _save() async {
    // Clear old inline errors
    setState(() {
      _currentError = null;
      _newError = null;
      _confirmError = null;
    });

    final currentPw = _currentCtrl.text;
    final newPw = _newCtrl.text;
    final confirmPw = _confirmCtrl.text;

    if (currentPw.isEmpty) {
      setState(() => _currentError = 'Enter your current password.');
      return;
    }
    if (newPw.isEmpty) {
      setState(() => _newError = 'Enter a new password.');
      return;
    }
    if (!_isStrongPassword(newPw)) {
      setState(() => _newError =
          'At least 6 chars, include a number and a special character.');
      return;
    }
    if (confirmPw.isEmpty || confirmPw != newPw) {
      setState(() => _confirmError = 'Passwords do not match.');
      return;
    }

    final auth = FirebaseAuth.instance;
    final db = FirebaseFirestore.instance;
    final user = auth.currentUser;

    if (user == null) {
      // No session — bail silently (keeping behavior minimal)
      setState(() => _currentError = 'You are not logged in.');
      return;
    }

    setState(() => _saving = true);
    try {
      // Ensure we have an email to reauthenticate (username flow fallback)
      String? email = user.email;
      if (email == null || email.isEmpty) {
        final doc = await db.collection('users').doc(user.uid).get();
        email = (doc.data()?['email'] as String?)?.trim();
      }
      if (email == null || email.isEmpty) {
        setState(() => _currentError = 'No email is linked to this account.');
        return;
      }

      // 1) Reauthenticate with CURRENT password
      try {
        final cred = EmailAuthProvider.credential(email: email, password: currentPw);
        await user.reauthenticateWithCredential(cred);
      } on FirebaseAuthException catch (e) {
        // Wrong current password → inline red error under current field
        if (e.code == 'wrong-password' || e.code == 'invalid-credential' || e.code == 'user-mismatch') {
          setState(() => _currentError = 'Current password is incorrect.');
          return;
        } else {
          setState(() => _currentError = 'Could not verify current password.');
          return;
        }
      }

      // 2) Check password history in Firestore (prevent reuse)
      final userRef = db.collection('users').doc(user.uid);
      final snap = await userRef.get();
      final data = snap.data() ?? {};

      final oldHash = (data['password'] as String?) ?? '';
      final List<dynamic> hist = (data['password_history'] as List<dynamic>?) ?? const [];
      final newHash = _hash(newPw);

      final hasUsedBefore = (newHash == oldHash) ||
          hist.map((e) => e?.toString() ?? '').contains(newHash);

      if (hasUsedBefore) {
        setState(() => _newError = 'You’ve used this password before. Choose a new one.');
        return;
      }

      // 3) Update Auth password (may require recent login; we just reauthed)
      await user.updatePassword(newPw);

      // 4) Update Firestore: set new hash; append previous to history
      await db.runTransaction((tx) async {
        final doc = await tx.get(userRef);
        final before = doc.data() ?? {};

        final prevHash = (before['password'] as String?) ?? '';
        final List<dynamic> prevHist = (before['password_history'] as List<dynamic>?) ?? [];

        final List<String> updatedHist = prevHist.map((e) => e.toString()).toList();
        if (prevHash.isNotEmpty && !updatedHist.contains(prevHash)) {
          updatedHist.add(prevHash);
        }
        // (Optional) keep only last N entries; not required:
        // while (updatedHist.length > 10) updatedHist.removeAt(0);

        tx.update(userRef, {
          'password': newHash,
          'password_history': updatedHist,
        });
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated.')),
      );
      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
      setState(() {
        _currentError = null;
        _newError = null;
        _confirmError = null;
      });
      Navigator.pop(context); // return to previous (usually Settings)
    } on FirebaseAuthException catch (e) {
      // If session got stale between reauth and update
      if (e.code == 'requires-recent-login') {
        setState(() => _currentError = 'Please log in again, then retry.');
      } else {
        setState(() => _newError = 'Could not update password. Try again.');
      }
    } catch (_) {
      setState(() => _newError = 'Unexpected error updating password.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFD7C3F1), Color(0xFF41B3A2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar: back + title (kept simple; sizes untouched otherwise)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: onSurface),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Change Password',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: onSurface.withOpacity(0.9),
                          ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Current password
                          TextField(
                            controller: _currentCtrl,
                            obscureText: !_showCurrent,
                            decoration: _dec(
                              'current password',
                              errorText: _currentError,
                              suffix: IconButton(
                                icon: Icon(
                                  _showCurrent ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.grey[700],
                                ),
                                onPressed: () => setState(() => _showCurrent = !_showCurrent),
                              ),
                            ),
                            onChanged: (_) {
                              if (_currentError != null) {
                                setState(() => _currentError = null);
                              }
                            },
                          ),
                          const SizedBox(height: 10),

                          // New password
                          TextField(
                            controller: _newCtrl,
                            obscureText: !_showNew,
                            decoration: _dec(
                              'new password',
                              errorText: _newError,
                              suffix: IconButton(
                                icon: Icon(
                                  _showNew ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.grey[700],
                                ),
                                onPressed: () => setState(() => _showNew = !_showNew),
                              ),
                            ),
                            onChanged: (v) {
                              // live hinting (optional): only set inline error if clearly failing
                              if (_newError != null) setState(() => _newError = null);
                            },
                          ),
                          const SizedBox(height: 10),

                          // Confirm password
                          TextField(
                            controller: _confirmCtrl,
                            obscureText: !_showConfirm,
                            decoration: _dec(
                              'confirm new password',
                              errorText: _confirmError,
                              suffix: IconButton(
                                icon: Icon(
                                  _showConfirm ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.grey[700],
                                ),
                                onPressed: () => setState(() => _showConfirm = !_showConfirm),
                              ),
                            ),
                            onChanged: (_) {
                              if (_confirmError != null) {
                                setState(() => _confirmError = null);
                              }
                            },
                          ),

                          const SizedBox(height: 20),

                          // Save
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _saving ? null : _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _brand,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                elevation: 3,
                              ),
                              child: _saving
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text('save', style: TextStyle(fontSize: 18)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Password must be at least 6 characters and include a number and a special character.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
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
