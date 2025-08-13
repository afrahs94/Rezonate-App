// lib/pages/login_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'home.dart';
import 'signup_page.dart';
import 'reset_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _idCtrl = TextEditingController(); // username OR email
  final _pwCtrl = TextEditingController();
  bool _showPw = false;
  bool _loading = false;

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  InputDecoration _dec(String hint, {Widget? suffix}) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      );

  Future<void> _handleLogin() async {
    final rawId = _idCtrl.text.trim();
    final pw = _pwCtrl.text;

    if (rawId.isEmpty || pw.isEmpty) {
      _snack('Please enter both username/email and password.');
      return;
    }

    setState(() => _loading = true);
    try {
      String email = rawId;
      String helloName = '';

      // If it doesn't look like an email, treat input as username
      if (!rawId.contains('@')) {
        final q = await _db
            .collection('users')
            .where('username', isEqualTo: rawId)
            .limit(1)
            .get();
        if (q.docs.isEmpty) {
          _snack('Account not found for that username.');
          return;
        }
        final data = q.docs.first.data();
        email = (data['email'] as String?)?.trim() ?? '';
        helloName = (data['first_name'] as String?)?.trim() ?? '';
        if (email.isEmpty) {
          _snack('No email is linked to this username.');
          return;
        }
      }

      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: pw,
      );

      // Fill greeting name if needed
      if (helloName.isEmpty) {
        final q = await _db
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) {
          helloName =
              (q.docs.first.data()['first_name'] as String?)?.trim() ?? '';
        }
      }
      helloName = helloName.isEmpty
          ? (cred.user?.displayName ??
              email.split('@').first.replaceAll('.', ' '))
          : helloName;

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomePage(userName: helloName)),
      );
    } on FirebaseAuthException catch (e) {
      _snack(_friendlyAuth(e.code));
    } catch (e) {
      _snack('Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyAuth(String code) {
    switch (code) {
      case 'user-not-found':
      case 'invalid-credential':
      case 'wrong-password':
        return 'Invalid credentials. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return 'Login failed. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF0D7C66);

    return Scaffold(
      // Keep auth pages independent from app-wide dark mode
      backgroundColor: Colors.transparent,
      body: Container(
        // Ensures the gradient fills the entire screen (fixes black bottom)
        constraints: const BoxConstraints.expand(),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFD7C3F1), Color(0xFF41B3A2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (_, c) {
              // Keep previous spacing/feel
              final topPad = c.maxHeight * 0.12;
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(28, topPad, 28, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // === Title (same typographic feel as before) ===
                    const Text(
                      'welcome',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w700,
                        color: primary,
                        height: 1.0,
                      ),
                    ),
                    const Text(
                      'back',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w700,
                        color: primary,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Username/email
                    TextField(
                      controller: _idCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: _dec('username/email'),
                    ),
                    const SizedBox(height: 14),

                    // Password
                    TextField(
                      controller: _pwCtrl,
                      obscureText: !_showPw,
                      onSubmitted: (_) => _handleLogin(),
                      decoration: _dec(
                        'password',
                        suffix: IconButton(
                          icon: Icon(
                            _showPw ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey[700],
                          ),
                          onPressed: () =>
                              setState(() => _showPw = !_showPw),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Forgot password link (new)
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ResetPasswordPage()),
                          );
                        },
                        child: Text(
                          'forgot password?',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Log in
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                          elevation: 3,
                          shadowColor: Colors.black26,
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('log in', style: TextStyle(fontSize: 20)),
                      ),
                    ),

                    const SizedBox(height: 18),
                    Row(
                      children: const [
                        Expanded(child: Divider(thickness: 1)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child:
                              Text('or', style: TextStyle(color: Colors.grey)),
                        ),
                        Expanded(child: Divider(thickness: 1)),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Sign up
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SignUpPage()),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                        ),
                        child: const Text(
                          'sign up',
                          style: TextStyle(color: primary, fontSize: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
