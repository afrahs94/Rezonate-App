// lib/pages/signup_page.dart
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

import 'home.dart';
import 'login_page.dart';
import 'user_sessions.dart';

// Onboarding
import 'onboarding.dart';

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

  // Terms & Conditions acceptance
  bool _acceptedTerms = false;

  // Data & permissions consent
  bool _acceptedDataPermissions = false;

  // ---------- Password validators ----------
  bool _isStrongPassword(String p) {
    if (p.length < 6) return false;
    if (!RegExp(r'\d').hasMatch(p)) return false; // at least one number
    if (!RegExp(r'[^\w\s]').hasMatch(p)) return false; // at least one special char
    return true;
  }

  String? _passwordValidator(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Required';
    if (v.length < 6) return 'At least 6 characters';
    if (!RegExp(r'\d').hasMatch(v)) return 'Include at least one number';
    if (!RegExp(r'[^\w\s]').hasMatch(v)) {
      return 'Include at least one special character';
    }
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
        final q = await _firestore
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
      final q = await _firestore
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
              _buildSecondPage(),
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
    List<TextInputFormatter>? inputFormatters,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? const Color(0xFF123A36) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.white70 : Colors.black45;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        readOnly: readOnly,
        onTap: onTap,
        onChanged: onChanged,
        style: TextStyle(color: textColor),
        cursorColor: textColor,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: hintColor),
          filled: true,
          fillColor: fill,
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
            validator ?? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
      ),
    );
  }

  // -------------------- Page 1 --------------------
  Widget _buildFirstPage() {
    final up = -MediaQuery.of(context).size.height * 0.03;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final linkColor = isDark ? Colors.white : const Color.fromARGB(255, 0, 0, 0);

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
                    if (RegExp(r'\s').hasMatch(v)) return 'No spaces allowed';
                    if (_usernameAvailable == false) {
                      return 'Username already taken';
                    }
                    return null;
                  },
                  errorText: _usernameError,
                  helperText: (_usernameError == null && _usernameAvailable == true)
                      ? 'Username available'
                      : null,
                  suffix: _availabilitySuffix(_usernameAvailable),
                  // prevent spaces (typing & paste)
                  inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                ),
                _buildTextField(
                  'email *',
                  emailController,
                  onChanged: _onEmailChanged,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim());
                    if (!ok) return 'Enter a valid email';
                    if (_emailAvailable == false) return 'Email already in use';
                    return null;
                  },
                  errorText: _emailError,
                  helperText: (_emailError == null && _emailAvailable == true)
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
                      _passwordObscured ? Icons.visibility_off : Icons.visibility,
                      color: isDark ? Colors.white70 : null,
                    ),
                    onPressed: () => setState(() {
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
                      color: isDark ? Colors.white70 : null,
                    ),
                    onPressed: () => setState(() {
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
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  ),
                  child: Align(
                    alignment: Alignment.center,
                    child: Text.rich(
                      TextSpan(
                        text: 'already have an account? ',
                        children: [
                          TextSpan(
                            text: 'log in',
                            style: TextStyle(
                              decoration: TextDecoration.underline,
                              color: linkColor,
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

  // -------------------- Page 2 --------------------
  Widget _buildSecondPage() {
    final up = -MediaQuery.of(context).size.height * 0.03;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final linkColor = isDark ? Colors.white : const Color(0xFF0D7C66);

    return Center(
      child: SingleChildScrollView(
        child: Transform.translate(
          offset: Offset(0, up),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
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
                      const SizedBox(height: 40),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _controller.previousPage(
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
                                    fontSize: 18, color: Colors.white),
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
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                ),
                child: Text.rich(
                  const TextSpan(
                    text: 'already have an account? ',
                    children: [
                      TextSpan(
                        text: 'log in',
                        style: TextStyle(
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: linkColor),
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
  // Capture these up front so we don't touch context after awaits.
  final messenger = ScaffoldMessenger.of(context);

  try {
    final ok = await _ensureTermsAccepted();
    if (!ok) return;

    final permsOk = await _ensureDataPermissions();
    if (!permsOk) return;

    if (dobController.text.isEmpty) {
      setState(() => _dobError = 'Please select date of birth');
      return;
    }

    final parsedDob = DateFormat('MM/dd/yyyy').parse(dobController.text);
    if (!_isAtLeast18(parsedDob)) {
      setState(() => _dobError = 'You must be at least 18 years old.');
      return;
    } else {
      if (_dobError != null) setState(() => _dobError = null);
    }

    final username = usernameController.text.trim();
    final usernameLower = username.toLowerCase();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    // extra safety: ensure no spaces
    if (RegExp(r'\s').hasMatch(username)) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Username cannot contain spaces.'),
      ));
      return;
    }

    if (!_isStrongPassword(password)) {
      messenger.showSnackBar(const SnackBar(
        content: Text(
          'Password must be at least 6 characters, include a number and a special character.',
        ),
      ));
      return;
    }

    final pre =
        await _firestore.collection('usernames').doc(usernameLower).get();
    if (pre.exists) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Username already taken')),
      );
      return;
    }

    final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user!.uid;

    final hashedPassword = sha256.convert(utf8.encode(password)).toString();

    try {
      await _firestore.runTransaction((tx) async {
        final unameRef = _firestore.collection('usernames').doc(usernameLower);
        final unameSnap = await tx.get(unameRef);
        if (unameSnap.exists) {
          throw Exception('USERNAME_TAKEN');
        }

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
          // Onboarding flags
          'onboardingStage': OnboardingStage.homeIntro.name,
          'onboardingDone': false,
          'accepted_terms': true,
          'consented_data_processing': true,
        });

        tx.set(unameRef, {
          'uid': uid,
          'username': username,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      if (e.toString().contains('USERNAME_TAKEN')) {
        try { await FirebaseAuth.instance.currentUser?.delete(); } catch (_) {}
        messenger.showSnackBar(
          const SnackBar(content: Text('Username already taken')),
        );
        return;
      }
      rethrow;
    }

    await UserSession.instance.refreshFromFirestore(_firestore, uid);
    Onboarding.isFreshSignup = true;
    await Onboarding.setStage(OnboardingStage.homeIntro);


    if (!mounted) return; // guard before using Navigator
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomePage(userName: firstNameController.text),
      ),
    );
  } catch (e) {
    try { await FirebaseAuth.instance.currentUser?.delete(); } catch (_) {}
    messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
  }
}

  // -------------------- Terms & Privacy helpers --------------------
  Future<void> _openTerms() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TermsAndPrivacyPage()),
    );
  }

  Future<bool> _ensureTermsAccepted() async {
    if (_acceptedTerms) return true;

    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Terms & Conditions'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'By creating an account, you agree to our Terms & Conditions and Privacy Policy. '
                    'You confirm you are at least 18 years old and that the information you provide is accurate.',
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _openTerms,
                    child: const Text('View full Terms & Privacy'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Decline'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('I Agree'),
            ),
          ],
        );
      },
    );

    if (agreed == true) {
      setState(() => _acceptedTerms = true);
      return true;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('You must accept the Terms & Conditions to create an account.'),
        ),
      );
      return false;
    }
  }

  Future<bool> _ensureDataPermissions() async {
    if (_acceptedDataPermissions) return true;

    final consent = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Data & Permissions Consent'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'To provide and improve the service, we request your permission to collect and process certain data.',
                ),
                SizedBox(height: 10),
                Text(
                  '• collect app usage analytics to improve performance;\n'
                  '• process crash reports and diagnostic logs;\n'
                  '• store device info (model, OS), and push token to deliver notifications;\n'
                  '• use region for localization and compliance;\n'
                  '• associate this with your account to personalize the app;\n'
                  '• share with contracted providers only to operate the service.',
                ),
                SizedBox(height: 10),
                Text(
                  'You can withdraw consent at any time in Settings → Security & Privacy.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Decline'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('I Consent'),
          ),
        ],
      ),
    );

    if (consent == true) {
      setState(() => _acceptedDataPermissions = true);
      return true;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must consent to data processing to create an account.'),
        ),
      );
      return false;
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

  bool _isAtLeast18(DateTime dob) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eighteenth = DateTime(dob.year + 18, dob.month, dob.day);
    return !eighteenth.isAfter(today);
  }

  Widget _genderTile(String g) {
    final isSelected = gender == g;
    final color = g == 'male'
        ? Colors.blue
        : g == 'female'
            ? Colors.pink
            : Colors.purple;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => setState(() => gender = g),
      child: Container(
        width: 94,
        height: 90,
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF123A36) : Colors.white)
              : (isDark
                  ? const Color(0xFF123A36).withOpacity(0.35)
                  : Colors.white.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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

// ---------- In-app Terms & Privacy page (opened from the dialog link) ----------
class TermsAndPrivacyPage extends StatefulWidget {
  final bool scrollToPrivacy;
  const TermsAndPrivacyPage({Key? key, this.scrollToPrivacy = false})
      : super(key: key);

  @override
  State<TermsAndPrivacyPage> createState() => _TermsAndPrivacyPageState();
}

class _TermsAndPrivacyPageState extends State<TermsAndPrivacyPage> {
  final _privacyKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // After first frame, optionally scroll to the Privacy Policy section.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.scrollToPrivacy) {
        final ctx = _privacyKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 300),
            alignment: 0.0,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // ensure visible in dark mode
      appBar: AppBar(
        title: const Text('Terms & Privacy'),
        backgroundColor: const Color(0xFF0D7C66),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: DefaultTextStyle(
            style: const TextStyle(
                color: Colors.black87, fontSize: 16, height: 1.35),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TERMS
                const Text('Terms & Conditions',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.black)),
                const SizedBox(height: 10),
                const Text(
                  'These Terms & Conditions (“Terms”) govern your use of this application and related services. '
                  'By creating an account or using the app, you agree to be bound by these Terms. If you do not agree, do not use the app.',
                ),
                const SizedBox(height: 14),
                const Text('1. Eligibility',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
                const SizedBox(height: 6),
                const Text('You must be at least 18 years old to use the service.'),
                const SizedBox(height: 12),
                const Text('2. Account & Security',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
                const SizedBox(height: 6),
                const Text(
                  'You are responsible for the information associated with your account and for maintaining the confidentiality of your credentials. '
                  'You agree to notify us promptly of any suspected unauthorized use.',
                ),
                const SizedBox(height: 12),
                const Text('3. Acceptable Use',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
                const SizedBox(height: 6),
                const Text(
                  'You will not use the service to harass, threaten, defame, post illegal content, or interfere with the operation of the service. '
                  'We may remove content or restrict access for violations.',
                ),
                const SizedBox(height: 12),
                const Text('4. Content & License',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
                const SizedBox(height: 6),
                const Text(
                  'You retain ownership of content you post. By posting, you grant us a limited, worldwide, non-exclusive license to host, display, '
                  'and process your content solely to operate and improve the service.',
                ),
                const SizedBox(height: 12),
                const Text('5. Service Changes',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
                const SizedBox(height: 6),
                const Text(
                    'We may modify, suspend, or discontinue features at any time, with or without notice.'),
                const SizedBox(height: 12),
                const Text('6. Disclaimers & Limitation of Liability',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
                const SizedBox(height: 6),
                const Text(
                  'The service is provided “as is” and “as available.” To the fullest extent permitted by law, we disclaim all warranties and '
                  'shall not be liable for indirect, incidental, or consequential damages.',
                ),
                const SizedBox(height: 12),
                const Text('7. Termination',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
                const SizedBox(height: 6),
                const Text(
                    'We may suspend or terminate your access for violations of these Terms or for risk to the service or users.'),
                const SizedBox(height: 12),
                const Text('8. Governing Law',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
                const SizedBox(height: 20),

                // PRIVACY
                Text('Privacy Policy',
                    key: _privacyKey,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.black)),
                const SizedBox(height: 10),
                const Text(
                  'This Privacy Policy describes how we collect, use, and protect your information when you use the service.',
                ),
                const SizedBox(height: 14),
                const Text('1. Information We Collect',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
                const SizedBox(height: 6),
                const Text(
                  '• Account information such as name, email, username, and date of birth.\n'
                  '• Usage data including actions taken in the app and diagnostic logs.\n'
                  '• Device information such as device model and operating system version.',
                ),
                const SizedBox(height: 12),
                const Text('2. How We Use Information',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
                const SizedBox(height: 6),
                const Text(
                  'We use your information to provide, secure, personalize, and improve the service; to communicate important updates; '
                  'and to comply with legal obligations.',
                ),
                const SizedBox(height: 12),
                const Text('3. Sharing of Information',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
                const SizedBox(height: 6),
                const Text(
                  'We do not sell your personal information. We may share data with service providers bound by confidentiality, or when required by law.',
                ),
                const SizedBox(height: 12),
                const Text('4. Security',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
                const SizedBox(height: 6),
                const Text(
                  'We implement reasonable safeguards appropriate to the sensitivity of the data. However, no method of transmission or storage is completely secure.',
                ),
                const SizedBox(height: 12),
                const Text('5. Your Choices & Rights',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
                const SizedBox(height: 6),
                const Text(
                  'You may access, correct, or delete certain information via your account settings, subject to legal and operational limitations.',
                ),
                const SizedBox(height: 12),
                const Text('6. Data Retention',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
                const SizedBox(height: 6),
                const Text(
                  'We retain information as long as necessary to provide the service and as required by law. We may anonymize data for analytics.',
                ),
                const SizedBox(height: 12),
                const Text('7. Children',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
                const SizedBox(height: 6),
                const Text(
                    'The service is not directed to persons under 18. We do not knowingly collect data from children.'),
                const SizedBox(height: 12),
                const Text('8. Contact',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
                const SizedBox(height: 6),
                const Text(
                    'For privacy questions, contact support using the email listed in the app settings.'),
                const SizedBox(height: 24),
                const Text('Last updated: 2025-01-01',
                    style: TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
