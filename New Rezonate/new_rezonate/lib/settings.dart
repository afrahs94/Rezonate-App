import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'homepage.dart';

class SettingsPage extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final String password;
  final String? phone;
  final String? birthday;

  const SettingsPage({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.password,
    this.phone,
    this.birthday,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  File? _profileImage;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _profileImage = File(picked.path);
      });
    }
  }

  void _removeImage() {
    setState(() => _profileImage = null);
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue[200]),
      title: Text(label, style: TextStyle(color: Colors.blue[200], fontWeight: FontWeight.bold)),
      subtitle: Text(value, style: const TextStyle(color: Colors.black)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fullName = "${widget.firstName} ${widget.lastName}";

    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD7EAFE),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomePage()),
            );
          },
        ),
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _pickImage,
              onLongPress: _removeImage,
              child: CircleAvatar(
                radius: 50,
                backgroundImage:
                    _profileImage != null ? FileImage(_profileImage!) : null,
                backgroundColor: Colors.white,
                child: _profileImage == null
                    ? Icon(Icons.person, size: 50, color: Colors.grey[400])
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            Text(fullName,
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w500, color: Colors.grey)),
            const SizedBox(height: 20),
            _buildInfoTile(Icons.person, 'Full Name', fullName),
            _buildInfoTile(Icons.cake, 'Birthday', widget.birthday ?? 'Not set'),
            _buildInfoTile(Icons.phone, 'Phone Number', widget.phone ?? 'Not set'),
            _buildInfoTile(Icons.alternate_email, 'Username', widget.username),
            _buildInfoTile(Icons.email, 'Email', widget.email),
            _buildInfoTile(Icons.visibility, 'Password', widget.password.replaceAll(RegExp(r'.'), '*')),
            const SizedBox(height: 30),
            Text('account settings',
                style: TextStyle(
                    fontSize: 18,
                    color: Colors.blue[300],
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 60),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        onTap: (index) {
          if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomePage()),
            );
          }
        },
        selectedItemColor: Colors.blue,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'home'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'settings'),
        ],
      ),
    );
  }
}
