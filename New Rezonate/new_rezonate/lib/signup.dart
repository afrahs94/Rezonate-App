import 'package:flutter/material.dart';
import 'homepage.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  int page = 1;
  String gender = '';

  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();

  // Controllers
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFD7EAFE),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                SizedBox(height: 20),
                Image.asset('assets/logo.png', height: 50),
                SizedBox(height: 10),
                Text(
                  'sign up',
                  style: TextStyle(fontSize: 40, color: Colors.grey[600]),
                ),
                SizedBox(height: 20),
                page == 1 ? _buildFirstForm() : _buildSecondForm(),
                SizedBox(height: 30),
                _buildBottomButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool obscureText = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          hintText: label,
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(40),
            borderSide: BorderSide.none,
          ),
        ),
        validator: (value) => value == null || value.isEmpty ? 'Required field' : null,
      ),
    );
  }

  Widget _buildFirstForm() {
    return Form(
      key: _formKey1,
      child: Column(
        children: [
          _buildTextField('username *', usernameController),
          _buildTextField('email *', emailController),
          _buildTextField('password *', passwordController, obscureText: true),
          _buildTextField('confirm password *', confirmPasswordController, obscureText: true),
        ],
      ),
    );
  }

  Widget _buildSecondForm() {
    return Form(
      key: _formKey2,
      child: Column(
        children: [
          _buildTextField('first name *', firstNameController),
          _buildTextField('last name (optional)', lastNameController),
          SizedBox(height: 20),
          Text('gender', style: TextStyle(color: Colors.grey[600])),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _genderButton('male', Icons.male),
              _genderButton('female', Icons.female),
              _genderButton('other', Icons.transgender),
            ],
          ),
        ],
      ),
    );
  }

  Widget _genderButton(String label, IconData icon) {
    bool selected = gender == label;
    return GestureDetector(
      onTap: () {
        setState(() => gender = label);
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.blue[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? Colors.blue : Colors.grey),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.blue : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () {
            if (page == 1 && _formKey1.currentState!.validate()) {
              setState(() => page = 2);
            } else if (page == 2 && _formKey2.currentState!.validate()) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => HomePage()),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.lightBlue[200],
            foregroundColor: Colors.white,
            minimumSize: Size(double.infinity, 55),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(40),
            ),
          ),
          child: Text(
            page == 1 ? 'continue' : 'done',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        SizedBox(height: 10),
        Text(
          '$page of 2',
          style: TextStyle(color: Colors.white, fontSize: 12),
        ),
        if (page == 1)
          TextButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => HomePage()),
              );
            },
            child: Text(
              'already have an account? log in',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
      ],
    );
  }
}