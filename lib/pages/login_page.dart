// login_page.dart
import 'package:flutter/material.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isPasswordVisible = false;

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
            const Text('welcome', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w400, color: Colors.grey)),
            const Text('back', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w400, color: Colors.grey)),
            const SizedBox(height: 30),
            _buildTextField('email/username*', emailController, suffixIcon: const Icon(Icons.check)),
            _buildTextField('password*', passwordController, obscureText: !isPasswordVisible, suffixIcon: IconButton(
              icon: Icon(isPasswordVisible ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => isPasswordVisible = !isPasswordVisible),
            )),
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerRight,
              child: Text('forgot password?', style: TextStyle(color: Colors.grey[600])),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                backgroundColor: Color(0xFF99BBFF),
                minimumSize: const Size(double.infinity, 50),
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
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpPage()));
              },
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                side: const BorderSide(color: Colors.white),
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.white,
              ),
              child: const Text('sign up', style: TextStyle(color: Color(0xFF99BBFF), fontSize: 18)),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller, {bool obscureText = false, Widget? suffixIcon}) {
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
