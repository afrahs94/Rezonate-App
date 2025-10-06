import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool _rememberMe = false;

  // Inline error shown under password when credentials are wrong
  String? _authInlineError;

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();

    // check auto-login
    _checkAutoLogin();

    // Clear inline error listeners
    _idCtrl.addListener(() {
      if (_authInlineError != null) {
        setState(() => _authInlineError = null);
      }
    });
    _pwCtrl.addListener(() {
      if (_authInlineError != null) {
        setState(() => _authInlineError = null);
      }
    });
  }

  Future<void> _checkAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('remember_me') ?? false;
    final user = FirebaseAuth.instance.currentUser;

    if (remember && user != null) {
      final helloName = prefs.getString('user_name') ?? user.email ?? "User";

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        NoTransitionPageRoute(builder: (_) => HomePage(userName: helloName)),
      );
    }
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  // Adaptive decoration for dark/light
  InputDecoration _dec(BuildContext context, String hint, {Widget? suffix}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? const Color(0xFF123A36) : Colors.white;
    final hintColor = isDark ? Colors.white70 : Colors.black45;

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: hintColor),
      filled: true,
      fillColor: fill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      suffixIcon: suffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _handleLogin() async {
    final rawId = _idCtrl.text.trim();
    final pw = _pwCtrl.text;

    if (rawId.isEmpty || pw.isEmpty) {
      _snack('Please enter both username/email and password.');
      return;
    }

    setState(() {
      _loading = true;
      _authInlineError = null;
    });

    try {
      String email = rawId;
      String helloName = '';

      // If it doesn't look like an email, treat input as username
      if (!rawId.contains('@')) {
        final q =
            await _db
                .collection('users')
                .where('username', isEqualTo: rawId)
                .limit(1)
                .get();
        if (q.docs.isEmpty) {
          // Show inline error under password instead of snackbar
          setState(
            () => _authInlineError = 'Invalid credentials. Please try again.',
          );
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
        final q =
            await _db
                .collection('users')
                .where('email', isEqualTo: email)
                .limit(1)
                .get();
        if (q.docs.isNotEmpty) {
          helloName =
              (q.docs.first.data()['first_name'] as String?)?.trim() ?? '';
        }
      }
      helloName =
          helloName.isEmpty
              ? (cred.user?.displayName ??
                  email.split('@').first.replaceAll('.', ' '))
              : helloName;

      if (!mounted) return;
      // save preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', _rememberMe);
      await prefs.setString('user_name', helloName);

      Navigator.pushReplacement(
        context,
        NoTransitionPageRoute(builder: (_) => HomePage(userName: helloName)),
      );
    } on FirebaseAuthException catch (e) {
      // Map the mismatch cases to inline error under password
      const mismatchCodes = {
        'user-not-found',
        'invalid-credential',
        'wrong-password',
      };
      if (mismatchCodes.contains(e.code)) {
        setState(
          () => _authInlineError = 'Invalid credentials. Please try again.',
        );
      } else if (e.code == 'invalid-email') {
        _snack('Please enter a valid email.');
      } else if (e.code == 'too-many-requests') {
        _snack('Too many attempts. Try again later.');
      } else {
        _snack('Login failed. Please try again.');
      }
    } catch (e) {
      _snack('Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF0D7C66);

    // Match sign-up title style: size 45, w500, same color
    const titleStyle = TextStyle(
      fontSize: 45,
      fontWeight: FontWeight.w500,
      color: primary,
      height: 1.0,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    // CHANGE: Make these texts black in dark mode as requested
    final textOnBg = isDark ? Colors.black : const Color.fromARGB(255, 0, 0, 0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
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
              // More centralized: less top padding + centered narrow column
              final topPad = c.maxHeight * 0.06;
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(28, topPad, 28, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Full logo like sign-up — bigger now
                        Image.asset(
                          'assets/images/Full_logo.png',
                          height: 245, // ⬅️ increased from 170
                          fit: BoxFit.contain,
                        ),

                        // "welcome back" in the same font style as sign-up
                        const Text(
                          'welcome',
                          textAlign: TextAlign.center,
                          style: titleStyle,
                        ),
                        const Text(
                          'back',
                          textAlign: TextAlign.center,
                          style: titleStyle,
                        ),
                        const SizedBox(height: 20),

                        // Username/email
                        TextField(
                          controller: _idCtrl,
                          textInputAction: TextInputAction.next,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          cursorColor: isDark ? Colors.white : Colors.black87,
                          decoration: _dec(context, 'username/email'),
                        ),
                        const SizedBox(height: 10),

                        // Password + visibility toggle
                        TextField(
                          controller: _pwCtrl,
                          obscureText: !_showPw,
                          onSubmitted: (_) => _handleLogin(),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          cursorColor: isDark ? Colors.white : Colors.black87,
                          decoration: _dec(
                            context,
                            'password',
                            suffix: IconButton(
                              icon: Icon(
                                _showPw
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color:
                                    isDark ? Colors.white70 : Colors.grey[700],
                              ),
                              onPressed:
                                  () => setState(() => _showPw = !_showPw),
                            ),
                          ),
                        ),

                        // Inline credentials error under password
                        if (_authInlineError != null) ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _authInlineError!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 1),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Left: Remember me
                            Row(
                              children: [
                                Transform.scale(
                                  scale: 0.8, // make checkbox smaller
                                  child: Checkbox(
                                    value: _rememberMe,
                                    onChanged:
                                        (v) => setState(
                                          () => _rememberMe = v ?? false,
                                        ),
                                    activeColor: const Color(
                                      0xFF0D7C66,
                                    ), // fill when checked
                                    checkColor: Colors.white, // checkmark color
                                    side: BorderSide(
                                      color:
                                          Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors
                                                  .black // border color in dark mode
                                              : const Color.fromARGB(255, 98, 98, 98), // border color in light mode
                                      width: 2,
                                    ),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                                const SizedBox(width: 0),
                                Text(
                                  "Remember me",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textOnBg,
                                  ),
                                ),
                              ],
                            ),

                            // Right: Forgot password
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  NoTransitionPageRoute(
                                    builder: (_) => const ResetPasswordPage(),
                                  ),
                                );
                              },
                              child: Text(
                                'forgot password?',
                                style: TextStyle(
                                  color:
                                      textOnBg, // black in dark mode per request
                                  fontSize: 12.5,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 17),

                        // Log in
                        SizedBox(
                          width: double.infinity,
                          height: 52,
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
                            child:
                                _loading
                                    ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                    : const Text(
                                      'log in',
                                      style: TextStyle(fontSize: 18),
                                    ),
                          ),
                        ),

                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Expanded(child: Divider(thickness: 1)),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Text(
                                'or',
                                style: TextStyle(
                                  color:
                                      isDark
                                          ? Colors.black
                                          : Colors
                                              .grey, // black in dark mode per request
                                ),
                              ),
                            ),
                            const Expanded(child: Divider(thickness: 1)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Sign up
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                NoTransitionPageRoute(
                                  builder: (_) => const SignUpPage(),
                                ),
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
                              style: TextStyle(color: primary, fontSize: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
