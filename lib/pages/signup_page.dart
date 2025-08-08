// signup_page.dart
// signup_page.dart
// import 'package:flutter/material.dart';
// import 'home.dart';
// import 'login_page.dart';

// class SignUpPage extends StatefulWidget {
//   const SignUpPage({super.key});

//   @override
//   State<SignUpPage> createState() => _SignUpPageState();
// }

// class _SignUpPageState extends State<SignUpPage> {
//   final _formKey = GlobalKey<FormState>();
//   final int _pageIndex = 0;
//   String gender = 'female';

//   final TextEditingController usernameController = TextEditingController();
//   final TextEditingController emailController = TextEditingController();
//   final TextEditingController passwordController = TextEditingController();
//   final TextEditingController confirmPasswordController = TextEditingController();
//   final TextEditingController firstNameController = TextEditingController();
//   final TextEditingController lastNameController = TextEditingController();

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//         width: double.infinity,
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             colors: [Color(0xFFCCCCFF), Colors.white],
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//           ),
//         ),
//         padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
//         child: PageView(
//           physics: const NeverScrollableScrollPhysics(),
//           controller: PageController(initialPage: _pageIndex),
//           children: [_buildFirstPage(), _buildSecondPage()],
//         ),
//       ),
//     );
//   }

//   Widget _buildTextField(String hint, TextEditingController controller, {bool obscureText = false}) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8.0),
//       child: TextFormField(
//         controller: controller,
//         obscureText: obscureText,
//         decoration: InputDecoration(
//           hintText: hint,
//           filled: true,
//           fillColor: Colors.white,
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(30),
//             borderSide: BorderSide.none,
//           ),
//         ),
//         validator: (value) => value == null || value.isEmpty ? 'Required' : null,
//       ),
//     );
//   }

//   Widget _buildFirstPage() {
//     return Form(
//       key: _formKey,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.center,
//         children: [
//           const Spacer(),
//           const Text('sign up', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w400, color: Colors.grey)),
//           const SizedBox(height: 20),
//           _buildTextField('username *', usernameController),
//           _buildTextField('email *', emailController),
//           _buildTextField('password *', passwordController, obscureText: true),
//           _buildTextField('confirm password *', confirmPasswordController, obscureText: true),
//           const SizedBox(height: 20),
//           ElevatedButton(
//             onPressed: () {
//   if (_formKey.currentState!.validate()) {
//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(
//         builder: (_) => HomePage(userName: usernameController.text),
//       ),
//     );
//   }
// },
//             style: ElevatedButton.styleFrom(
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
//               backgroundColor: Color(0xFF99BBFF),
//               minimumSize: const Size(double.infinity, 50),
//             ),
//             child: const Text('continue', style: TextStyle(fontSize: 18)),
//           ),
//           const SizedBox(height: 20),
//           const Text('1 of 2'),
//           GestureDetector(
//             onTap: () {
//               Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
//             },
//             child: Text.rich(
//               TextSpan(
//                 text: 'already have an account? ',
//                 children: [
//                   TextSpan(
//                     text: 'log in',
//                     style: TextStyle(decoration: TextDecoration.underline, color: Colors.blue),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           const Spacer(),
//         ],
//       ),
//     );
//   }

//   Widget _buildSecondPage() {
//     return Column(
//       children: [
//         const Spacer(),
//         const Text('sign up', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w400, color: Colors.grey)),
//         const SizedBox(height: 20),
//         _buildTextField('first name *', firstNameController),
//         _buildTextField('last name (optional)', lastNameController),
//         const SizedBox(height: 20),
//         const Text('gender', style: TextStyle(color: Colors.grey)),
//         const SizedBox(height: 10),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//           children: ['male', 'female', 'other'].map((g) => _genderTile(g)).toList(),
//         ),
//         const SizedBox(height: 20),
//         ElevatedButton(
//           onPressed: () {
//             Navigator.pushReplacement(
//               context,
//               MaterialPageRoute(builder: (_) => HomePage(userName: firstNameController.text)),
//             );
//           },
//           style: ElevatedButton.styleFrom(
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
//             backgroundColor: Color(0xFF99BBFF),
//             minimumSize: const Size(double.infinity, 50),
//           ),
//           child: const Text('done', style: TextStyle(fontSize: 18)),
//         ),
//         const SizedBox(height: 20),
//         const Text('2 of 2'),
//         const Spacer(),
//       ],
//     );
//   }

//   Widget _genderTile(String g) {
//     bool isSelected = gender == g;
//     return GestureDetector(
//       onTap: () => setState(() => gender = g),
//       child: Container(
//         padding: const EdgeInsets.all(10),
//         decoration: BoxDecoration(
//           color: isSelected ? Colors.white : Colors.transparent,
//           borderRadius: BorderRadius.circular(10),
//           border: Border.all(color: Colors.grey.shade300),
//         ),
//         child: Column(
//           children: [
//             Icon(
//               g == 'male' ? Icons.male : g == 'female' ? Icons.female : Icons.transgender,
//               color: isSelected ? Colors.black : Colors.grey,
//             ),
//             Text(g, style: TextStyle(color: isSelected ? Colors.black : Colors.grey)),
//           ],
//         ),
//       ),
//     );
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:crypto/crypto.dart';
// import 'dart:convert';
// import 'package:intl/intl.dart';
// import 'package:new_rezonate/pages/services/database_service.dart';
// import 'home.dart';
// import 'login_page.dart';

// class SignUpPage extends StatefulWidget {
//   const SignUpPage({super.key});

//   @override
//   State<SignUpPage> createState() => _SignUpPageState();
// }

// class _SignUpPageState extends State<SignUpPage> {
//   final _formKey = GlobalKey<FormState>();
//   final PageController _controller = PageController();
//   final DatabaseService _dbService = DatabaseService.instance;

//   final TextEditingController usernameController = TextEditingController();
//   final TextEditingController emailController = TextEditingController();
//   final TextEditingController passwordController = TextEditingController();
//   final TextEditingController confirmPasswordController = TextEditingController();
//   final TextEditingController firstNameController = TextEditingController();
//   final TextEditingController lastNameController = TextEditingController();
//   final TextEditingController dobController = TextEditingController();

//   String gender = 'female';

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             colors: [Color(0xFF00BFFF), Color(0xFFB0E0E6)],
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//           ),
//         ),
//         child: PageView(
//           physics: const NeverScrollableScrollPhysics(),
//           controller: _controller,
//           children: [_buildFirstPage(), _buildSecondPage()],
//         ),
//       ),
//     );
//   }

//   Widget _buildTextField(String hint, TextEditingController controller,
//       {bool obscureText = false, bool readOnly = false, VoidCallback? onTap}) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8.0),
//       child: TextFormField(
//         controller: controller,
//         obscureText: obscureText,
//         readOnly: readOnly,
//         onTap: onTap,
//         decoration: InputDecoration(
//           hintText: hint,
//           filled: true,
//           fillColor: Colors.white,
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(30),
//             borderSide: BorderSide.none,
//           ),
//         ),
//         validator: (value) => value == null || value.isEmpty ? 'Required' : null,
//       ),
//     );
//   }

//   Widget _buildFirstPage() {
//     return Form(
//       key: _formKey,
//       child: Column(
//         children: [
//           const Spacer(),
//           const Text('sign up', style: TextStyle(fontSize: 40, color: Colors.grey)),
//           _buildTextField('username *', usernameController),
//           _buildTextField('email *', emailController),
//           _buildTextField('password *', passwordController, obscureText: true),
//           _buildTextField('confirm password *', confirmPasswordController, obscureText: true),
//           const SizedBox(height: 20),
//           ElevatedButton(
//             onPressed: () {
//               if (_formKey.currentState!.validate()) {
//                 if (passwordController.text != confirmPasswordController.text) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                       const SnackBar(content: Text("Passwords do not match")));
//                   return;
//                 }
//                 _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
//               }
//             },
//             style: ElevatedButton.styleFrom(
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
//               backgroundColor: const Color(0xFF99BBFF),
//               minimumSize: const Size(double.infinity, 50),
//             ),
//             child: const Text('continue', style: TextStyle(fontSize: 18)),
//           ),
//           const SizedBox(height: 20),
//           const Text('1 of 2'),
//           GestureDetector(
//             onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage())),
//             child: const Text.rich(
//               TextSpan(
//                 text: 'already have an account? ',
//                 children: [
//                   TextSpan(
//                     text: 'log in',
//                     style: TextStyle(decoration: TextDecoration.underline, color: Colors.blue),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           const Spacer(),
//         ],
//       ),
//     );
//   }

//   Widget _buildSecondPage() {
//     return Column(
//       children: [
//         const SizedBox(height: 40),
//         const Text('sign up', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w600, color: Color(0xFFFFFF00))),
//         const SizedBox(height: 40),
//         _buildTextField('first name *', firstNameController),
//         _buildTextField('last name (optional)', lastNameController),
//         _buildTextField('date of birth *', dobController, readOnly: true, onTap: _selectDate),
//         const SizedBox(height: 20),
//         const Text('gender', style: TextStyle(fontSize: 16, color: Colors.white)),
//         const SizedBox(height: 10),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//           children: ['male', 'female', 'other'].map((g) => _genderTile(g)).toList(),
//         ),
//         const SizedBox(height: 30),
//         ElevatedButton(
//           onPressed: _handleSignUp,
//           style: ElevatedButton.styleFrom(
//             backgroundColor: const Color(0xFFFFFF00),
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
//             minimumSize: const Size(double.infinity, 60),
//           ),
//           child: const Text('done', style: TextStyle(fontSize: 20, color: Colors.black)),
//         ),
//         const SizedBox(height: 20),
//         const Text('2 of 2', style: TextStyle(color: Colors.white)),
//       ],
//     );
//   }

//   Future<void> _handleSignUp() async {
//     try {
//       if (dobController.text.isEmpty) {
//         ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text("Please select date of birth")));
//         return;
//       }

//       final existingUser = await _dbService.getUserByUsernameOrEmail(
//           usernameController.text, emailController.text);

//       if (existingUser != null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text("Username or email already exists")));
//         return;
//       }

//       final hashedPassword = sha256.convert(utf8.encode(passwordController.text)).toString();

//       final user = {
//         'username': usernameController.text,
//         'email': emailController.text,
//         'password': hashedPassword,
//         'first_name': firstNameController.text,
//         'last_name': lastNameController.text,
//         'gender': gender,
//         'dob': dobController.text,
//         'created_at': DateTime.now().toIso8601String(),
//       };

//       final userId = await _dbService.insertUser(user);

//       if (userId > 0) {
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (_) => HomePage(userName: firstNameController.text)),
//         );
//       } else {
//         throw Exception("Failed to create user");
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
//     }
//   }

//   void _selectDate() async {
//     DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: DateTime(2000),
//       firstDate: DateTime(1900),
//       lastDate: DateTime.now(),
//     );
//     if (picked != null) {
//       setState(() {
//         dobController.text = DateFormat('MM/dd/yyyy').format(picked);
//       });
//     }
//   }

//   Widget _genderTile(String g) {
//     final isSelected = gender == g;
//     final color = g == 'male'
//         ? Colors.blue
//         : g == 'female'
//             ? Colors.pink
//             : Colors.purple;

//     return GestureDetector(
//       onTap: () => setState(() => gender = g),
//       child: Container(
//         padding: const EdgeInsets.all(12),
//         decoration: BoxDecoration(
//           color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
//           borderRadius: BorderRadius.circular(18),
//         ),
//         child: Column(
//           children: [
//             Icon(
//               g == 'male' ? Icons.male : g == 'female' ? Icons.female : Icons.transgender,
//               color: color,
//               size: 28,
//             ),
//             const SizedBox(height: 6),
//             Text(g, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
//           ],
//         ),
//       ),
//     );
//   }
// }
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:crypto/crypto.dart';
// import 'dart:convert';
// import 'package:intl/intl.dart';
// import 'home.dart';
// import 'login_page.dart';

// class SignUpPage extends StatefulWidget {
//   const SignUpPage({super.key});

//   @override
//   State<SignUpPage> createState() => _SignUpPageState();
// }

// class _SignUpPageState extends State<SignUpPage> {
//   final _formKey = GlobalKey<FormState>();
//   final PageController _controller = PageController();

//   final TextEditingController usernameController = TextEditingController();
//   final TextEditingController emailController = TextEditingController();
//   final TextEditingController passwordController = TextEditingController();
//   final TextEditingController confirmPasswordController = TextEditingController();
//   final TextEditingController firstNameController = TextEditingController();
//   final TextEditingController lastNameController = TextEditingController();
//   final TextEditingController dobController = TextEditingController();

//   String gender = 'female';

//   final _firestore = FirebaseFirestore.instance;
//   final _auth = FirebaseAuth.instance;

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             colors: [Color(0xFF00BFFF), Color(0xFFB0E0E6)],
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//           ),
//         ),
//         child: PageView(
//           physics: const NeverScrollableScrollPhysics(),
//           controller: _controller,
//           children: [_buildFirstPage(), _buildSecondPage()],
//         ),
//       ),
//     );
//   }

//   Widget _buildTextField(String hint, TextEditingController controller,
//       {bool obscureText = false, bool readOnly = false, VoidCallback? onTap}) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8.0),
//       child: TextFormField(
//         controller: controller,
//         obscureText: obscureText,
//         readOnly: readOnly,
//         onTap: onTap,
//         decoration: InputDecoration(
//           hintText: hint,
//           filled: true,
//           fillColor: Colors.white,
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(30),
//             borderSide: BorderSide.none,
//           ),
//         ),
//         validator: (value) => value == null || value.isEmpty ? 'Required' : null,
//       ),
//     );
//   }

//   Widget _buildFirstPage() {
//     return Form(
//       key: _formKey,
//       child: Column(
//         children: [
//           const Spacer(),
//           const Text('sign up', style: TextStyle(fontSize: 40, color: Colors.grey)),
//           _buildTextField('username *', usernameController),
//           _buildTextField('email *', emailController),
//           _buildTextField('password *', passwordController, obscureText: true),
//           _buildTextField('confirm password *', confirmPasswordController, obscureText: true),
//           const SizedBox(height: 20),
//           ElevatedButton(
//             onPressed: () {
//               if (_formKey.currentState!.validate()) {
//                 if (passwordController.text != confirmPasswordController.text) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(content: Text("Passwords do not match")),
//                   );
//                   return;
//                 }
//                 _controller.nextPage(
//                   duration: const Duration(milliseconds: 300),
//                   curve: Curves.easeIn,
//                 );
//               }
//             },
//             style: ElevatedButton.styleFrom(
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
//               backgroundColor: const Color(0xFF99BBFF),
//               minimumSize: const Size(double.infinity, 50),
//             ),
//             child: const Text('continue', style: TextStyle(fontSize: 18)),
//           ),
//           const SizedBox(height: 20),
//           const Text('1 of 2'),
//           GestureDetector(
//             onTap: () => Navigator.push(
//               context,
//               MaterialPageRoute(builder: (_) => const LoginPage()),
//             ),
//             child: const Text.rich(
//               TextSpan(
//                 text: 'already have an account? ',
//                 children: [
//                   TextSpan(
//                     text: 'log in',
//                     style: TextStyle(
//                       decoration: TextDecoration.underline,
//                       color: Colors.blue,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           const Spacer(),
//         ],
//       ),
//     );
//   }

//   Widget _buildSecondPage() {
//     return Column(
//       children: [
//         const SizedBox(height: 40),
//         const Text(
//           'sign up',
//           style: TextStyle(
//             fontSize: 48,
//             fontWeight: FontWeight.w600,
//             color: Color(0xFFFFFF00),
//           ),
//         ),
//         const SizedBox(height: 40),
//         _buildTextField('first name *', firstNameController),
//         _buildTextField('last name (optional)', lastNameController),
//         _buildTextField(
//           'date of birth *',
//           dobController,
//           readOnly: true,
//           onTap: _selectDate,
//         ),
//         const SizedBox(height: 20),
//         const Text('gender', style: TextStyle(fontSize: 16, color: Colors.white)),
//         const SizedBox(height: 10),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//           children: ['male', 'female', 'other']
//               .map((g) => _genderTile(g))
//               .toList(),
//         ),
//         const SizedBox(height: 30),
//         ElevatedButton(
//           onPressed: _handleSignUp,
//           style: ElevatedButton.styleFrom(
//             backgroundColor: const Color(0xFFFFFF00),
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
//             minimumSize: const Size(double.infinity, 60),
//           ),
//           child: const Text('done', style: TextStyle(fontSize: 20, color: Colors.black)),
//         ),
//         const SizedBox(height: 20),
//         const Text('2 of 2', style: TextStyle(color: Colors.white)),
//       ],
//     );
//   }

//   Future<void> _handleSignUp() async {
//     try {
//       if (dobController.text.isEmpty) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text("Please select date of birth")),
//         );
//         return;
//       }

//       final query = await _firestore
//           .collection('users')
//           .where('username', isEqualTo: usernameController.text)
//           .get();

//       if (query.docs.isNotEmpty) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text("Username already exists")),
//         );
//         return;
//       }

//       // Firebase Auth account creation
//       UserCredential userCred = await _auth.createUserWithEmailAndPassword(
//         email: emailController.text.trim(),
//         password: passwordController.text.trim(),
//       );

//       final hashedPassword = sha256
//           .convert(utf8.encode(passwordController.text))
//           .toString();

//       final user = {
//         'uid': userCred.user!.uid,
//         'username': usernameController.text.trim(),
//         'email': emailController.text.trim(),
//         'password': hashedPassword,
//         'first_name': firstNameController.text.trim(),
//         'last_name': lastNameController.text.trim(),
//         'gender': gender,
//         'dob': dobController.text,
//         'created_at': DateTime.now().toIso8601String(),
//       };

//       await _firestore.collection('users').doc(userCred.user!.uid).set(user);

//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(
//           builder: (_) => HomePage(userName: firstNameController.text),
//         ),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Error: ${e.toString()}")),
//       );
//     }
//   }

//   void _selectDate() async {
//     DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: DateTime(2000),
//       firstDate: DateTime(1900),
//       lastDate: DateTime.now(),
//     );
//     if (picked != null) {
//       setState(() {
//         dobController.text = DateFormat('MM/dd/yyyy').format(picked);
//       });
//     }
//   }

//   Widget _genderTile(String g) {
//     final isSelected = gender == g;
//     final color = g == 'male'
//         ? Colors.blue
//         : g == 'female'
//             ? Colors.pink
//             : Colors.purple;

//     return GestureDetector(
//       onTap: () => setState(() => gender = g),
//       child: Container(
//         padding: const EdgeInsets.all(12),
//         decoration: BoxDecoration(
//           color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
//           borderRadius: BorderRadius.circular(18),
//         ),
//         child: Column(
//           children: [
//             Icon(
//               g == 'male'
//                   ? Icons.male
//                   : g == 'female'
//                       ? Icons.female
//                       : Icons.transgender,
//               color: color,
//               size: 28,
//             ),
//             const SizedBox(height: 6),
//             Text(
//               g,
//               style: TextStyle(color: color, fontWeight: FontWeight.w600),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }


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

      // ✅ Firebase Authentication - Register User
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      // ✅ Check Firestore for duplicates
      final query = await _firestore
          .collection('users')
          .where('username', isEqualTo: usernameController.text)
          .get();

      final emailQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: emailController.text)
          .get();

      if (query.docs.isNotEmpty || emailQuery.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Username or email already exists")),
        );
        return;
      }

      final hashedPassword = sha256
          .convert(utf8.encode(passwordController.text))
          .toString();

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

      await _firestore.collection('users').add(user);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(userName: firstNameController.text),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
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
              g == 'male' ? Icons.male : g == 'female'
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
}
