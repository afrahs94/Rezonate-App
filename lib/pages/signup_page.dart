/*signup_page.dart
signup_page.dart
import 'package:flutter/material.dart';
import 'home.dart';
import 'login_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final int _pageIndex = 0;
  String gender = 'female';

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFCCCCFF), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: PageView(
          physics: const NeverScrollableScrollPhysics(),
          controller: PageController(initialPage: _pageIndex),
          children: [_buildFirstPage(), _buildSecondPage()],
        ),
      ),
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller, {bool obscureText = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
      ),
    );
  }

  Widget _buildFirstPage() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(),
          const Text('sign up', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w400, color: Colors.grey)),
          const SizedBox(height: 20),
          _buildTextField('username *', usernameController),
          _buildTextField('email *', emailController),
          _buildTextField('password *', passwordController, obscureText: true),
          _buildTextField('confirm password *', confirmPasswordController, obscureText: true),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
  if (_formKey.currentState!.validate()) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomePage(userName: usernameController.text),
      ),
    );
  }
},
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              backgroundColor: Color(0xFF99BBFF),
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('continue', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 20),
          const Text('1 of 2'),
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
            },
            child: Text.rich(
              TextSpan(
                text: 'already have an account? ',
                children: [
                  TextSpan(
                    text: 'log in',
                    style: TextStyle(decoration: TextDecoration.underline, color: Colors.blue),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildSecondPage() {
    return Column(
      children: [
        const Spacer(),
        const Text('sign up', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w400, color: Colors.grey)),
        const SizedBox(height: 20),
        _buildTextField('first name *', firstNameController),
        _buildTextField('last name (optional)', lastNameController),
        const SizedBox(height: 20),
        const Text('gender', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['male', 'female', 'other'].map((g) => _genderTile(g)).toList(),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => HomePage(userName: firstNameController.text)),
            );
          },
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            backgroundColor: Color(0xFF99BBFF),
            minimumSize: const Size(double.infinity, 50),
          ),
          child: const Text('done', style: TextStyle(fontSize: 18)),
        ),
        const SizedBox(height: 20),
        const Text('2 of 2'),
        const Spacer(),
      ],
    );
  }

  Widget _genderTile(String g) {
    bool isSelected = gender == g;
    return GestureDetector(
      onTap: () => setState(() => gender = g),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Icon(
              g == 'male' ? Icons.male : g == 'female' ? Icons.female : Icons.transgender,
              color: isSelected ? Colors.black : Colors.grey,
            ),
            Text(g, style: TextStyle(color: isSelected ? Colors.black : Colors.grey)),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:new_rezonate/pages/services/database_service.dart';
import 'home.dart';
import 'login_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final PageController _controller = PageController();
  final DatabaseService _dbService = DatabaseService.instance;

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController dobController = TextEditingController();

  String gender = 'female';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF00BFFF), Color(0xFFB0E0E6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: PageView(
          physics: const NeverScrollableScrollPhysics(),
          controller: _controller,
          children: [_buildFirstPage(), _buildSecondPage()],
        ),
      ),
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller,
      {bool obscureText = false, bool readOnly = false, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        readOnly: readOnly,
        onTap: onTap,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
      ),
    );
  }

  Widget _buildFirstPage() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          const Spacer(),
          const Text('sign up', style: TextStyle(fontSize: 40, color: Colors.grey)),
          _buildTextField('username *', usernameController),
          _buildTextField('email *', emailController),
          _buildTextField('password *', passwordController, obscureText: true),
          _buildTextField('confirm password *', confirmPasswordController, obscureText: true),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                if (passwordController.text != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Passwords do not match")));
                  return;
                }
                _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
              }
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              backgroundColor: const Color(0xFF99BBFF),
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('continue', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 20),
          const Text('1 of 2'),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage())),
            child: const Text.rich(
              TextSpan(
                text: 'already have an account? ',
                children: [
                  TextSpan(
                    text: 'log in',
                    style: TextStyle(decoration: TextDecoration.underline, color: Colors.blue),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildSecondPage() {
    return Column(
      children: [
        const SizedBox(height: 40),
        const Text('sign up', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w600, color: Color(0xFFFFFF00))),
        const SizedBox(height: 40),
        _buildTextField('first name *', firstNameController),
        _buildTextField('last name (optional)', lastNameController),
        _buildTextField('date of birth *', dobController, readOnly: true, onTap: _selectDate),
        const SizedBox(height: 20),
        const Text('gender', style: TextStyle(fontSize: 16, color: Colors.white)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['male', 'female', 'other'].map((g) => _genderTile(g)).toList(),
        ),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: _handleSignUp,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFFF00),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            minimumSize: const Size(double.infinity, 60),
          ),
          child: const Text('done', style: TextStyle(fontSize: 20, color: Colors.black)),
        ),
        const SizedBox(height: 20),
        const Text('2 of 2', style: TextStyle(color: Colors.white)),
      ],
    );
  }

  Future<void> _handleSignUp() async {
    try {
      if (dobController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please select date of birth")));
        return;
      }

      final existingUser = await _dbService.getUserByUsernameOrEmail(
          usernameController.text, emailController.text);

      if (existingUser != null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Username or email already exists")));
        return;
      }

      final hashedPassword = sha256.convert(utf8.encode(passwordController.text)).toString();

      final user = {
        'username': usernameController.text,
        'email': emailController.text,
        'password': hashedPassword,
        'first_name': firstNameController.text,
        'last_name': lastNameController.text,
        'gender': gender,
        'dob': dobController.text,
        'created_at': DateTime.now().toIso8601String(),
      };

      final userId = await _dbService.insertUser(user);

      if (userId > 0) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage(userName: firstNameController.text)),
        );
      } else {
        throw Exception("Failed to create user");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
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
      setState(() {
        dobController.text = DateFormat('MM/dd/yyyy').format(picked);
      });
    }
  }

  Widget _genderTile(String g) {
    final isSelected = gender == g;
    final color = g == 'male'
        ? Colors.blue
        : g == 'female'
            ? Colors.pink
            : Colors.purple;

    return GestureDetector(
      onTap: () => setState(() => gender = g),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Icon(
              g == 'male' ? Icons.male : g == 'female' ? Icons.female : Icons.transgender,
              color: color,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(g, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'home.dart';
import 'login_page.dart';

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
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController dobController = TextEditingController();

  String gender = 'female';

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF00BFFF), Color(0xFFB0E0E6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: PageView(
          physics: const NeverScrollableScrollPhysics(),
          controller: _controller,
          children: [_buildFirstPage(), _buildSecondPage()],
        ),
      ),
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller,
      {bool obscureText = false, bool readOnly = false, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        readOnly: readOnly,
        onTap: onTap,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
      ),
    );
  }

  Widget _buildFirstPage() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          const Spacer(),
          const Text('sign up', style: TextStyle(fontSize: 40, color: Colors.grey)),
          _buildTextField('username *', usernameController),
          _buildTextField('email *', emailController),
          _buildTextField('password *', passwordController, obscureText: true),
          _buildTextField('confirm password *', confirmPasswordController, obscureText: true),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                if (passwordController.text != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Passwords do not match")),
                  );
                  return;
                }
                _controller.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeIn,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              backgroundColor: const Color(0xFF99BBFF),
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('continue', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 20),
          const Text('1 of 2'),
          GestureDetector(
            onTap: () => Navigator.push(
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
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildSecondPage() {
    return Column(
      children: [
        const SizedBox(height: 40),
        const Text(
          'sign up',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w600,
            color: Color(0xFFFFFF00),
          ),
        ),
        const SizedBox(height: 40),
        _buildTextField('first name *', firstNameController),
        _buildTextField('last name (optional)', lastNameController),
        _buildTextField(
          'date of birth *',
          dobController,
          readOnly: true,
          onTap: _selectDate,
        ),
        const SizedBox(height: 20),
        const Text('gender', style: TextStyle(fontSize: 16, color: Colors.white)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['male', 'female', 'other']
              .map((g) => _genderTile(g))
              .toList(),
        ),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: _handleSignUp,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFFF00),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            minimumSize: const Size(double.infinity, 60),
          ),
          child: const Text('done', style: TextStyle(fontSize: 20, color: Colors.black)),
        ),
        const SizedBox(height: 20),
        const Text('2 of 2', style: TextStyle(color: Colors.white)),
      ],
    );
  }

  Future<void> _handleSignUp() async {
    try {
      if (dobController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select date of birth")),
        );
        return;
      }

      final query = await _firestore
          .collection('users')
          .where('username', isEqualTo: usernameController.text)
          .get();

      if (query.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Username already exists")),
        );
        return;
      }

      // Firebase Auth account creation
      UserCredential userCred = await _auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final hashedPassword = sha256
          .convert(utf8.encode(passwordController.text))
          .toString();

      final user = {
        'uid': userCred.user!.uid,
        'username': usernameController.text.trim(),
        'email': emailController.text.trim(),
        'password': hashedPassword,
        'first_name': firstNameController.text.trim(),
        'last_name': lastNameController.text.trim(),
        'gender': gender,
        'dob': dobController.text,
        'created_at': DateTime.now().toIso8601String(),
      };

      await _firestore.collection('users').doc(userCred.user!.uid).set(user);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(userName: firstNameController.text),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
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
      setState(() {
        dobController.text = DateFormat('MM/dd/yyyy').format(picked);
      });
    }
  }

  Widget _genderTile(String g) {
    final isSelected = gender == g;
    final color = g == 'male'
        ? Colors.blue
        : g == 'female'
            ? Colors.pink
            : Colors.purple;

    return GestureDetector(
      onTap: () => setState(() => gender = g),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Icon(
              g == 'male'
                  ? Icons.male
                  : g == 'female'
                      ? Icons.female
                      : Icons.transgender,
              color: color,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              g,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}*/


// Full SignUpPage code updated to match the provided UI and preserve all logic
// Colors used: #0D7C66, #41B3A2, #BDE8CA, #D7C3F1

// Full SignUpPage code updated to match the provided UI and preserve all logic
// Colors used: #0D7C66, #41B3A2, #BDE8CA, #D7C3F1

// Full SignUpPage code updated to match the provided UI and preserve all logic
// Colors used: #0D7C66, #41B3A2, #BDE8CA, #D7C3F1

// Full SignUpPage code updated to match the provided UI and preserve all logic
// Colors used: #0D7C66, #41B3A2, #BDE8CA, #D7C3F1

// Full SignUpPage code updated to match the provided UI and preserve all logic
// Colors used: #0D7C66, #41B3A2, #BDE8CA, #D7C3F1

// Full SignUpPage code updated to match the provided UI and preserve all logic
// Colors used: #0D7C66, #41B3A2, #BDE8CA, #D7C3F1

// Full SignUpPage code updated to match the provided UI and preserve all logic
// Colors used: #0D7C66, #41B3A2, #BDE8CA, #D7C3F1

// lib/sign_up_page.dart
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
  final TextEditingController confirmPasswordController = TextEditingController();
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

  // --- NEW: page 2 DOB error holder (inline under the field) ---
  String? _dobError;

  // ---------- Password validators ----------
  bool _isStrongPassword(String p) {
    if (p.length < 6) return false;
    if (!RegExp(r'\d').hasMatch(p)) return false;           // at least one number
    if (!RegExp(r'[^\w\s]').hasMatch(p)) return false;      // at least one special char
    return true;
  }

  String? _passwordValidator(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Required';
    if (v.length < 6) return 'At least 6 characters';
    if (!RegExp(r'\d').hasMatch(v)) return 'Include at least one number';
    if (!RegExp(r'[^\w\s]').hasMatch(v)) return 'Include at least one special character';
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
              _buildSecondPage(), // Only this page changed for your request
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          errorText: errorText,
          helperText: helperText,
          helperStyle: const TextStyle(color: Color(0xFF0D7C66)),
          suffixIcon: suffix,
        ),
        validator: validator ?? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
      ),
    );
  }

  // -------------------- Page 1 (unchanged) --------------------
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
                    height: 190,
                    fit: BoxFit.contain,
                  ),
                ),

                const Align(
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

                _buildTextField(
                  'username *',
                  usernameController,
                  onChanged: _onUsernameChanged,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (_usernameAvailable == false) return 'Username already taken';
                    return null;
                  },
                  errorText: _usernameError,
                  helperText: (_usernameError == null && _usernameAvailable == true)
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
                    final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim());
                    if (!ok) return 'Enter a valid email';
                    if (_emailAvailable == false) return 'Email already in use';
                    return null;
                  },
                  errorText: _emailError,
                  helperText:
                      (_emailError == null && _emailAvailable == true) ? 'Email available' : null,
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
                    icon: Icon(_passwordObscured ? Icons.visibility_off : Icons.visibility),
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
                    icon: Icon(_confirmPasswordObscured ? Icons.visibility_off : Icons.visibility),
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
                  child: const Text('continue',
                      style: TextStyle(fontSize: 18, color: Colors.white)),
                ),

                const SizedBox(height: 10),
                const Align(
                  alignment: Alignment.center,
                  child: Text('1 of 2'),
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: () => Navigator.push(
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

  // -------------------- Page 2 (smaller + centered + 18+ check) --------------------
  Widget _buildSecondPage() {
    final up = -MediaQuery.of(context).size.height * 0.03;

    return Center(
      child: SingleChildScrollView(
        child: Transform.translate(
          offset: Offset(0, up),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center, // centered
            children: [
              // Slightly smaller logo on page 2
              Center(
                child: Image.asset(
                  'assets/images/Full_logo.png',
                  height: 140, // smaller
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(height: 8),
              const Text(
                'sign up',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30, // smaller
                  color: Color(0xFF0D7C66),
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 8),
              _buildTextField('first name *', firstNameController),
              _buildTextField('last name', lastNameController),

              // DOB: add inline error + keep readOnly date picker
              _buildTextField(
                'date of birth *',
                dobController,
                readOnly: true,
                onTap: _selectDate,
                errorText: _dobError, // <-- inline error right under the field
              ),

              const SizedBox(height: 6),
              const Text(
                'gender',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF0D7C66)), // smaller
              ),
              const SizedBox(height: 6),

              // Centered gender row with slightly tighter spacing
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _genderTile('female'),
                  const SizedBox(width: 12),
                  _genderTile('male'),
                  const SizedBox(width: 12),
                  _genderTile('other'),
                ],
              ),

              const SizedBox(height: 12),
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
                        minimumSize: const Size(double.infinity, 48), // smaller
                        elevation: 5,
                      ),
                      child:
                          const Text('back', style: TextStyle(fontSize: 16, color: Colors.white)), // smaller text
                    ),
                  ),
                  const SizedBox(width: 16), // slightly tighter gap
                Expanded(
                    child: ElevatedButton(
                      onPressed: _handleSignUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D7C66),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        minimumSize: const Size(double.infinity, 48), // smaller
                        elevation: 5,
                      ),
                      child:
                          const Text('done', style: TextStyle(fontSize: 16, color: Colors.white)), // smaller text
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              const Text('2 of 2', textAlign: TextAlign.center, style: TextStyle(fontSize: 14)),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => Navigator.push(
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
        setState(() => _dobError = 'Please select date of birth'); // inline error
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
      final pre = await _firestore.collection('usernames').doc(usernameLower).get();
      if (pre.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username already taken')),
        );
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
          final unameRef = _firestore.collection('usernames').doc(usernameLower);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
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

  // -------------------- Gender tile (slightly smaller) --------------------
  Widget _genderTile(String g) {
    final isSelected = gender == g;
    final color = g == 'male'
        ? Colors.blue
        : g == 'female'
            ? Colors.pink
            : Colors.purple;

    return GestureDetector(
      onTap: () => setState(() => gender = g),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), // smaller
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              g == 'male'
                  ? Icons.male
                  : g == 'female'
                      ? Icons.female
                      : Icons.transgender,
              color: color,
              size: 24, // smaller
            ),
            const SizedBox(height: 4),
            Text(
              g,
              style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13), // smaller
            ),
          ],
        ),
      ),
    );
  }
}
