// // login_page.dart
// import 'package:flutter/material.dart';
// import 'signup_page.dart';

// class LoginPage extends StatefulWidget {
//   const LoginPage({super.key});

//   @override
//   State<LoginPage> createState() => _LoginPageState();
// }

// class _LoginPageState extends State<LoginPage> {
//   final TextEditingController emailController = TextEditingController();
//   final TextEditingController passwordController = TextEditingController();
//   bool isPasswordVisible = false;

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
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Spacer(),
//             const Text('welcome', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w400, color: Colors.grey)),
//             const Text('back', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w400, color: Colors.grey)),
//             const SizedBox(height: 30),
//             _buildTextField('email/username*', emailController, suffixIcon: const Icon(Icons.check)),
//             _buildTextField('password*', passwordController, obscureText: !isPasswordVisible, suffixIcon: IconButton(
//               icon: Icon(isPasswordVisible ? Icons.visibility_off : Icons.visibility),
//               onPressed: () => setState(() => isPasswordVisible = !isPasswordVisible),
//             )),
//             const SizedBox(height: 5),
//             Align(
//               alignment: Alignment.centerRight,
//               child: Text('forgot password?', style: TextStyle(color: Colors.grey[600])),
//             ),
//             const SizedBox(height: 30),
//             ElevatedButton(
//               onPressed: () {},
//               style: ElevatedButton.styleFrom(
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
//                 backgroundColor: Color(0xFF99BBFF),
//                 minimumSize: const Size(double.infinity, 50),
//               ),
//               child: const Text('log in', style: TextStyle(fontSize: 18)),
//             ),
//             const SizedBox(height: 20),
//             Row(
//               children: const [
//                 Expanded(child: Divider(thickness: 1)),
//                 Padding(
//                   padding: EdgeInsets.symmetric(horizontal: 10),
//                   child: Text('or', style: TextStyle(color: Colors.grey)),
//                 ),
//                 Expanded(child: Divider(thickness: 1)),
//               ],
//             ),
//             const SizedBox(height: 20),
//             OutlinedButton(
//               onPressed: () {
//                 Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpPage()));
//               },
//               style: OutlinedButton.styleFrom(
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
//                 side: const BorderSide(color: Colors.white),
//                 minimumSize: const Size(double.infinity, 50),
//                 backgroundColor: Colors.white,
//               ),
//               child: const Text('sign up', style: TextStyle(color: Color(0xFF99BBFF), fontSize: 18)),
//             ),
//             const Spacer(),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildTextField(String hint, TextEditingController controller, {bool obscureText = false, Widget? suffixIcon}) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8.0),
//       child: TextField(
//         controller: controller,
//         obscureText: obscureText,
//         decoration: InputDecoration(
//           hintText: hint,
//           filled: true,
//           fillColor: Colors.white,
//           suffixIcon: suffixIcon,
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(30),
//             borderSide: BorderSide.none,
//           ),
//         ),
//       ),
//     );
//   }
// }




// lib/pages/login_page.dart


// lib/pages/login_page.dart

// import 'package:flutter/material.dart';
// import 'package:new_rezonate/pages/services/database_service.dart';
// import 'home.dart';
// import 'signup_page.dart';

// class LoginPage extends StatefulWidget {
//   const LoginPage({super.key});

//   @override
//   State<LoginPage> createState() => _LoginPageState();
// }

// class _LoginPageState extends State<LoginPage> {
//   final TextEditingController _userOrEmailCtrl = TextEditingController();
//   final TextEditingController _passwordCtrl    = TextEditingController();
//   bool _showPassword = false;

//   Future<void> _handleLogin() async {
//     final input    = _userOrEmailCtrl.text.trim();
//     final password = _passwordCtrl.text;

//     if (input.isEmpty || password.isEmpty) {
//       _showSnackbar('Please enter both username/email and password');
//       return;
//     }

//     try {
//       // Attempts to authenticate by username OR email + plain password
//       final userRecord = await DatabaseService.instance
//         .authenticateUser(input, password);

//       if (userRecord == null) {
//         _showSnackbar('Invalid username/email or password');
//         return;
//       }

//       // On success, navigate to HomePage and pass first name
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(
//           builder: (_) => HomePage(userName: userRecord['first_name']),
//         ),
//       );
//     } catch (e) {
//       _showSnackbar('Login error: $e');
//     }
//   }

//   void _showSnackbar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(message)),
//     );
//   }

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
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Spacer(),

//             const Text(
//               'welcome',
//               style: TextStyle(
//                 fontSize: 36,
//                 fontWeight: FontWeight.w400,
//                 color: Colors.grey,
//               ),
//             ),
//             const Text(
//               'back',
//               style: TextStyle(
//                 fontSize: 36,
//                 fontWeight: FontWeight.w400,
//                 color: Colors.grey,
//               ),
//             ),

//             const SizedBox(height: 30),

//             _buildTextField(
//               hint: 'username or email',
//               controller: _userOrEmailCtrl,
//               suffixIcon: const Icon(Icons.person),
//             ),

//             _buildTextField(
//               hint: 'password',
//               controller: _passwordCtrl,
//               obscureText: !_showPassword,
//               suffixIcon: IconButton(
//                 icon: Icon(
//                   _showPassword ? Icons.visibility_off : Icons.visibility,
//                 ),
//                 onPressed: () =>
//                   setState(() => _showPassword = !_showPassword),
//               ),
//             ),

//             const SizedBox(height: 10),
//             Align(
//               alignment: Alignment.centerRight,
//               child: Text(
//                 'forgot password?',
//                 style: TextStyle(color: Colors.grey[600]),
//               ),
//             ),

//             const SizedBox(height: 30),
//             ElevatedButton(
//               onPressed: _handleLogin,
//               style: ElevatedButton.styleFrom(
//                 minimumSize: const Size(double.infinity, 50),
//                 backgroundColor: const Color(0xFF99BBFF),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(30),
//                 ),
//               ),
//               child: const Text('log in', style: TextStyle(fontSize: 18)),
//             ),

//             const SizedBox(height: 20),
//             Row(
//               children: const [
//                 Expanded(child: Divider(thickness: 1)),
//                 Padding(
//                   padding: EdgeInsets.symmetric(horizontal: 10),
//                   child: Text('or', style: TextStyle(color: Colors.grey)),
//                 ),
//                 Expanded(child: Divider(thickness: 1)),
//               ],
//             ),

//             const SizedBox(height: 20),
//             OutlinedButton(
//               onPressed: () => Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (_) => const SignUpPage()),
//               ),
//               style: OutlinedButton.styleFrom(
//                 minimumSize: const Size(double.infinity, 50),
//                 backgroundColor: Colors.white,
//                 side: const BorderSide(color: Colors.white),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(30),
//                 ),
//               ),
//               child: const Text(
//                 'sign up',
//                 style: TextStyle(color: Color(0xFF99BBFF), fontSize: 18),
//               ),
//             ),

//             const Spacer(),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildTextField({
//     required String hint,
//     required TextEditingController controller,
//     bool obscureText = false,
//     Widget? suffixIcon,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8.0),
//       child: TextField(
//         controller: controller,
//         obscureText: obscureText,
//         decoration: InputDecoration(
//           hintText: hint,
//           filled: true,
//           fillColor: Colors.white,
//           suffixIcon: suffixIcon,
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(30),
//             borderSide: BorderSide.none,
//           ),
//         ),
//       ),
//     );
//   }
// }



import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'home.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  bool _showPassword = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _handleLogin() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      _showSnackbar('Please enter both email and password');
      return;
    }

    try {
      UserCredential userCred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Fetch user's first name from Firestore
      final doc = await _firestore.collection('users').doc(userCred.user!.uid).get();
      final firstName = doc.data()?['first_name'] ?? '';

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomePage(userName: firstName)),
      );
    } on FirebaseAuthException catch (e) {
      _showSnackbar(e.message ?? 'Login failed');
    } catch (e) {
      _showSnackbar('Unexpected error: $e');
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            const Text('welcome', style: TextStyle(fontSize: 36, color: Colors.grey)),
            const Text('back', style: TextStyle(fontSize: 36, color: Colors.grey)),
            const SizedBox(height: 30),

            _buildTextField(
              hint: 'email',
              controller: _emailCtrl,
              suffixIcon: const Icon(Icons.email),
            ),

            _buildTextField(
              hint: 'password',
              controller: _passwordCtrl,
              obscureText: !_showPassword,
              suffixIcon: IconButton(
                icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),

            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Text('forgot password?', style: TextStyle(color: Colors.grey[600])),
            ),

            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _handleLogin,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: const Color(0xFF99BBFF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('log in', style: TextStyle(fontSize: 18)),
            ),

            const SizedBox(height: 20),
            Row(
              children: const [
                Expanded(child: Divider(thickness: 1)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('or', style: TextStyle(color: Colors.grey)),
                ),
                Expanded(child: Divider(thickness: 1)),
              ],
            ),

            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SignUpPage()),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text(
                'sign up',
                style: TextStyle(color: Color(0xFF99BBFF), fontSize: 18),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String hint,
    required TextEditingController controller,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
