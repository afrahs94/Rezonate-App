import 'dart:async'; // for debounce
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'home.dart';
import 'login_page.dart';
import 'user_sessions.dart';

// keeps your cached profile after signup

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final PageController _controller = PageController();

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController dobController = TextEditingController();

  String gender = 'female';
  final _firestore = FirebaseFirestore.instance;

  // Live validation state
  Timer? _userDebounce;
  Timer? _emailDebounce;

  String? _usernameError;
  bool? _usernameAvailable;

  String? _emailError;
  bool? _emailAvailable;

  String? _passwordLiveError;

  // Password visibility toggles
  bool _passwordObscured = true;
  bool _confirmPasswordObscured = true;

  // Page 2 DOB error holder (inline under the field)
  String? _dobError;

  // ---------- Password validators ----------
  bool _isStrongPassword(String p) {
    if (p.length < 6) return false;
    if (!RegExp(r'\d').hasMatch(p)) return false; // at least one number
    if (!RegExp(r'[^\w\s]').hasMatch(p))
      return false; // at least one special char
    return true;
  }

  String? _passwordValidator(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Required';
    if (v.length < 6) return 'At least 6 characters';
    if (!RegExp(r'\d').hasMatch(v)) return 'Include at least one number';
    if (!RegExp(r'[^\w\s]').hasMatch(v))
      return 'Include at least one special character';
    return null;
  }

  String? _confirmPasswordValidator(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Required';
    if (v != passwordController.text.trim()) return 'Passwords do not match';
    return null;
  }

  // ---------- Debounced checks (live UI feedback) ----------
  void _onUsernameChanged(String v) {
    _userDebounce?.cancel();
    _usernameError = null;
    _usernameAvailable = null;

    final trimmed = v.trim();
    if (trimmed.isEmpty) {
      setState(() {});
      return;
    }
    _userDebounce = Timer(const Duration(milliseconds: 450), () {
      _checkUsernameAvailability(trimmed);
    });
    setState(() {});
  }

  Future<void> _checkUsernameAvailability(String username) async {
    final lower = username.trim().toLowerCase();
    try {
      // Primary source of truth: usernames/{username_lower}
      final unameSnap =
          await _firestore.collection('usernames').doc(lower).get();

      bool taken = unameSnap.exists;

      // Legacy fallback: some old user docs may not have a reservation doc
      if (!taken) {
        final q =
            await _firestore
                .collection('users')
                .where('username_lower', isEqualTo: lower)
                .limit(1)
                .get();
        taken = q.docs.isNotEmpty;
      }

      if (!mounted) return;
      setState(() {
        _usernameAvailable = !taken;
        _usernameError = taken ? 'Username already taken' : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _usernameAvailable = null; // unknown
        _usernameError = null;
      });
    }
  }

  void _onEmailChanged(String v) {
    _emailDebounce?.cancel();
    _emailError = null;
    _emailAvailable = null;

    final trimmed = v.trim();
    if (trimmed.isEmpty) {
      setState(() {});
      return;
    }
    _emailDebounce = Timer(const Duration(milliseconds: 450), () {
      _checkEmailAvailability(trimmed);
    });
    setState(() {});
  }

  Future<void> _checkEmailAvailability(String email) async {
    try {
      final q =
          await _firestore
              .collection('users')
              .where('email', isEqualTo: email.trim())
              .limit(1)
              .get();

      if (!mounted) return;
      setState(() {
        final used = q.docs.isNotEmpty;
        _emailAvailable = !used;
        _emailError = used ? 'Email already in use' : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _emailAvailable = null;
        _emailError = null;
      });
    }
  }

  void _onPasswordChanged(String v) {
    String? msg;
    if (v.isEmpty) {
      msg = null;
    } else if (v.length < 6) {
      msg = 'At least 6 characters';
    } else if (!RegExp(r'\d').hasMatch(v)) {
      msg = 'Include at least one number';
    } else if (!RegExp(r'[^\w\s]').hasMatch(v)) {
      msg = 'Include at least one special character';
    } else {
      msg = null;
    }
    setState(() => _passwordLiveError = msg);
  }

  @override
  void dispose() {
    _userDebounce?.cancel();
    _emailDebounce?.cancel();
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    dobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFD7C3F1), Color(0xFF41B3A2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
        child: SafeArea(
          child: PageView(
            physics: const NeverScrollableScrollPhysics(),
            controller: _controller,
            padEnds: false,
            children: [
              _buildFirstPage(),
              _buildSecondPage(), // layout-only edits
            ],
          ),
        ),
      ),
    );
  }

  // -------------------- Reusable field --------------------
  Widget _buildTextField(
    String hint,
    TextEditingController controller, {
    bool obscureText = false,
    bool readOnly = false,
    VoidCallback? onTap,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    String? errorText,
    String? helperText,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        readOnly: readOnly,
        onTap: onTap,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          errorText: errorText,
          helperText: helperText,
          helperStyle: const TextStyle(color: Color(0xFF0D7C66)),
          suffixIcon: suffix,
        ),
        validator:
            validator ??
            (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
      ),
    );
  }

  // -------------------- Page 1 --------------------
  Widget _buildFirstPage() {
    final up = -MediaQuery.of(context).size.height * 0.03;

    return Center(
      child: SingleChildScrollView(
        child: Transform.translate(
          offset: Offset(0, up),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Image.asset(
                    'assets/images/Full_logo.png',
                    height: 200,
                    fit: BoxFit.contain,
                  ),
                ),

                Transform.translate(
                    offset: const Offset(0, -14), 
                    child: const Align(
                    alignment: Alignment.center,
                      child: Text(
                        'sign up',
                         style: TextStyle(
                          fontSize: 45,
                          color: Color(0xFF0D7C66),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),


                _buildTextField(
                  'username *',
                  usernameController,
                  onChanged: _onUsernameChanged,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (_usernameAvailable == false)
                      return 'Username already taken';
                    return null;
                  },
                  errorText: _usernameError,
                  helperText:
                      (_usernameError == null && _usernameAvailable == true)
                          ? 'Username available'
                          : null,
                  suffix: _availabilitySuffix(_usernameAvailable),
                ),

                _buildTextField(
                  'email *',
                  emailController,
                  onChanged: _onEmailChanged,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final ok = RegExp(
                      r'^[^@]+@[^@]+\.[^@]+',
                    ).hasMatch(v.trim());
                    if (!ok) return 'Enter a valid email';
                    if (_emailAvailable == false) return 'Email already in use';
                    return null;
                  },
                  errorText: _emailError,
                  helperText:
                      (_emailError == null && _emailAvailable == true)
                          ? 'Email available'
                          : null,
                  suffix: _availabilitySuffix(_emailAvailable),
                ),

                _buildTextField(
                  'password *',
                  passwordController,
                  obscureText: _passwordObscured,
                  onChanged: _onPasswordChanged,
                  validator: _passwordValidator,
                  errorText: _passwordLiveError,
                  suffix: IconButton(
                    icon: Icon(
                      _passwordObscured
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed:
                        () => setState(() {
                          _passwordObscured = !_passwordObscured;
                        }),
                  ),
                ),

                _buildTextField(
                  'confirm password *',
                  confirmPasswordController,
                  obscureText: _confirmPasswordObscured,
                  validator: _confirmPasswordValidator,
                  suffix: IconButton(
                    icon: Icon(
                      _confirmPasswordObscured
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed:
                        () => setState(() {
                          _confirmPasswordObscured = !_confirmPasswordObscured;
                        }),
                  ),
                ),

                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D7C66),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    minimumSize: const Size(double.infinity, 55),
                    elevation: 5,
                  ),
                  child: const Text(
                    'continue',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),

                const SizedBox(height: 10),
                const Align(alignment: Alignment.center, child: Text('1 of 2')),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      ),
                  child: const Align(
                    alignment: Alignment.center,
                    child: Text.rich(
                      TextSpan(
                        text: 'already have an account? ',
                        children: [
                          TextSpan(
                            text: 'log in',
                            style: TextStyle(
                              decoration: TextDecoration.underline,
                              color: Color.fromARGB(255, 0, 0, 0),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget? _availabilitySuffix(bool? available) {
    if (available == null) return null;
    if (available) {
      return const Icon(Icons.check_circle, color: Color(0xFF0D7C66));
    }
    return const Icon(Icons.error_outline, color: Colors.red);
  }

  // -------------------- Page 2 (more spacing + centered/clean layout) --------------------
  Widget _buildSecondPage() {
    final up = -MediaQuery.of(context).size.height * 0.03;

    return Center(
      child: SingleChildScrollView(
        child: Transform.translate(
          offset: Offset(0, up),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Match page 1 logo size
              Center(
                child: Image.asset(
                  'assets/images/Full_logo.png',
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),

              const Text(
                'sign up',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 45,
                  color: Color(0xFF0D7C66),
                  fontWeight: FontWeight.w500,
                ),
              ),

              // Constrain width a bit so it feels centered/clean on larger screens
              Align(
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    children: [
                      _buildTextField('first name *', firstNameController),
                      _buildTextField('last name', lastNameController),

                      _buildTextField(
                        'date of birth *',
                        dobController,
                        readOnly: true,
                        onTap: _selectDate,
                        errorText: _dobError,
                      ),

                      const SizedBox(height: 10),
                      const Text(
                        'gender',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          color: Color(0xFF0D7C66),
                        ),
                      ),
                      const SizedBox(height: 10),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _genderTile('female'),
                          const SizedBox(width: 14),
                          _genderTile('male'),
                          const SizedBox(width: 14),
                          _genderTile('other'),
                        ],
                      ),

                      // >>> Even more spacing before action buttons <<<
                      const SizedBox(height: 40),

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  () => _controller.previousPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D7C66),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                minimumSize: const Size(double.infinity, 55),
                                elevation: 5,
                              ),
                              child: const Text(
                                'back',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _handleSignUp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D7C66),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                minimumSize: const Size(double.infinity, 55),
                                elevation: 5,
                              ),
                              child: const Text(
                                'done',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),
              const Text('2 of 2', textAlign: TextAlign.center),
              const SizedBox(height: 4),
              GestureDetector(
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    ),
                child: const Text.rich(
                  TextSpan(
                    text: 'already have an account? ',
                    children: [
                      TextSpan(
                        text: 'log in',
                        style: TextStyle(
                          decoration: TextDecoration.underline,
                          color: Color(0xFF0D7C66),
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------- Actions --------------------
  Future<void> _handleSignUp() async {
    try {
      if (dobController.text.isEmpty) {
        setState(
          () => _dobError = 'Please select date of birth',
        ); // inline error
        return;
      }

      // Enforce 18+ before allowing signup
      final parsedDob = DateFormat('MM/dd/yyyy').parse(dobController.text);
      if (!_isAtLeast18(parsedDob)) {
        setState(() => _dobError = 'You must be at least 18 years old.');
        return; // block sign up
      } else {
        if (_dobError != null) setState(() => _dobError = null);
      }

      final username = usernameController.text.trim();
      final usernameLower = username.toLowerCase();
      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      // Enforce password rules
      if (!_isStrongPassword(password)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Password must be at least 6 characters, include a number and a special character.',
            ),
          ),
        );
        return;
      }

      // Pre-check against usernames/{username_lower}
      final pre =
          await _firestore.collection('usernames').doc(usernameLower).get();
      if (pre.exists) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Username already taken')));
        return;
      }

      // Create Auth user FIRST (so we have UID)
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user!.uid;

      final hashedPassword = sha256.convert(utf8.encode(password)).toString();

      // Atomically claim username + create profile
      try {
        await _firestore.runTransaction((tx) async {
          final unameRef = _firestore
              .collection('usernames')
              .doc(usernameLower);
          final unameSnap = await tx.get(unameRef);
          if (unameSnap.exists) {
            throw Exception('USERNAME_TAKEN');
          }

          // /users/{uid}
          final userRef = _firestore.collection('users').doc(uid);
          tx.set(userRef, {
            'uid': uid,
            'username': username,
            'username_lower': usernameLower,
            'email': email,
            'password': hashedPassword, // consider removing
            'first_name': firstNameController.text,
            'last_name': lastNameController.text,
            'gender': gender,
            'dob': dobController.text,
            'created_at': DateTime.now().toIso8601String(),
          });

          // /usernames/{username_lower}
          tx.set(unameRef, {
            'uid': uid,
            'username': username,
            'createdAt': FieldValue.serverTimestamp(),
          });
        });
      } catch (e) {
        // If taken between pre-check and transaction, roll back auth user
        if (e.toString().contains('USERNAME_TAKEN')) {
          try {
            await FirebaseAuth.instance.currentUser?.delete();
          } catch (_) {}
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Username already taken')),
          );
          return;
        }
        rethrow;
      }

      // Cache profile locally for other pages & restarts
      await UserSession.instance.refreshFromFirestore(_firestore, uid);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(userName: firstNameController.text),
        ),
      );
    } catch (e) {
      // Best-effort cleanup for unexpected failures
      try {
        await FirebaseAuth.instance.currentUser?.delete();
      } catch (_) {}
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      final isAdult = _isAtLeast18(picked);
      setState(() {
        dobController.text = DateFormat('MM/dd/yyyy').format(picked);
        _dobError = isAdult ? null : 'You must be at least 18 years old.';
      });
    }
  }

  // Helper: true if user is at least 18 today
  bool _isAtLeast18(DateTime dob) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eighteenth = DateTime(dob.year + 18, dob.month, dob.day);
    return !eighteenth.isAfter(today);
  }

  // -------------------- Gender tile --------------------
  Widget _genderTile(String g) {
    final isSelected = gender == g;
    final color =
        g == 'male'
            ? Colors.blue
            : g == 'female'
            ? Colors.pink
            : Colors.purple;

    return GestureDetector(
      onTap: () => setState(() => gender = g),
      child: Container(
        width: 94, // 🔹 fixed width
        height: 90, // 🔹 fixed height
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(18),
          
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // 🔹 center everything
          children: [
            Icon(
              g == 'male'
                  ? Icons.male
                  : g == 'female'
                  ? Icons.female
                  : Icons.transgender,
              color: color,
              size: 34,
            ),
            const SizedBox(height: 6),
            Text(
              g,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
