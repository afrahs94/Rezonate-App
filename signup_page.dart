import 'package:flutter/material.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  int _pageIndex = 0;
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
                setState(() => _pageIndex = 1);
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
          const Text.rich(
            TextSpan(
              text: 'already have an account? ',
              children: [TextSpan(text: 'log in', style: TextStyle(decoration: TextDecoration.underline))],
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
            // Save or navigate to home
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
