import 'package:flutter/material.dart';

class EditProfilePage extends StatefulWidget {
  final String userName;
  const EditProfilePage({super.key, required this.userName});

  @override
  // ignore: library_private_types_in_public_api
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _fullNameCtl = TextEditingController();
  final _birthdayCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _usernameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _passwordCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // seed full name
    _fullNameCtl.text = widget.userName;
  }

  Widget _buildField(IconData icon, String hint, TextEditingController ctl,
          {bool obscure = false, int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 24.0),
        child: TextField(
          controller: ctl,
          obscureText: obscure,
          maxLines: maxLines,
          decoration: InputDecoration(
            prefixIcon: Icon(icon),
            hintText: hint,
            border: const UnderlineInputBorder(),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // Back arrow
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back),
                ),
              ),
            ),

            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              color: Colors.teal,
              child: Column(
                children: [
                  Icon(Icons.person, size: 64, color: Colors.white),
                  const SizedBox(height: 12),
                  Text(widget.userName,
                      style: const TextStyle(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            // Form fields
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildField(Icons.person_outline, 'Full Name', _fullNameCtl),
                    _buildField(Icons.calendar_today, 'Birthday', _birthdayCtl),
                    _buildField(Icons.phone, 'Phone Number', _phoneCtl),
                    _buildField(Icons.alternate_email, 'Username', _usernameCtl),
                    _buildField(Icons.email, 'Email', _emailCtl),
                    _buildField(Icons.visibility, 'Password', _passwordCtl,
                        obscure: true),

                    const SizedBox(height: 24),
                    // Link back to settings
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Account Settings',
                        style: TextStyle(
                            decoration: TextDecoration.underline,
                            fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
