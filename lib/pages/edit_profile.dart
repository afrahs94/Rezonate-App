// lib/pages/edit_profile.dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class EditProfilePage extends StatefulWidget {
  final String userName; // shown in title/subtitle if you like
  const EditProfilePage({super.key, required this.userName});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _form = GlobalKey<FormState>();

  final _nameCtl = TextEditingController();
  final _birthdayCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _usernameCtl = TextEditingController();
  final _emailCtl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  String? _userDocId; // Firestore doc id for updates
  String? _photoUrl;

  final _fs = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _birthdayCtl.dispose();
    _phoneCtl.dispose();
    _usernameCtl.dispose();
    _emailCtl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not signed in')),
      );
      return;
    }

    try {
      // 1) Prefer a doc whose id == uid
      DocumentSnapshot<Map<String, dynamic>>? snap;
      final uidDoc = await _fs.collection('users').doc(user.uid).get();
      if (uidDoc.exists) {
        snap = uidDoc;
        _userDocId = uidDoc.id;
      } else {
        // 2) Fallback: the app may have used .add() on signup.
        // Try by email, then by username == displayName
        final byEmail = await _fs
            .collection('users')
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();
        if (byEmail.docs.isNotEmpty) {
          snap = byEmail.docs.first;
          _userDocId = snap.id;
        } else if (user.displayName != null && user.displayName!.isNotEmpty) {
          final byUname = await _fs
              .collection('users')
              .where('username', isEqualTo: user.displayName)
              .limit(1)
              .get();
          if (byUname.docs.isNotEmpty) {
            snap = byUname.docs.first;
            _userDocId = snap.id;
          }
        }
      }

      final data = snap?.data() ?? <String, dynamic>{};

      // Pre-fill all fields (fall back to Auth values where sensible)
      final first = (data['first_name'] ?? '').toString().trim();
      final last = (data['last_name'] ?? '').toString().trim();
      final combinedName = (first.isEmpty && last.isEmpty)
          ? (user.displayName ?? '')
          : [first, last].where((s) => s.isNotEmpty).join(' ');

      _nameCtl.text = combinedName;
      _birthdayCtl.text = (data['dob'] ?? '').toString();
      _phoneCtl.text = (data['phone'] ?? '').toString();
      _usernameCtl.text =
          (data['username'] ?? user.displayName ?? '').toString();
      _emailCtl.text = (data['email'] ?? user.email ?? '').toString();
      _photoUrl = (data['photoUrl'] ?? user.photoURL)?.toString();

      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: $e')),
      );
    }
  }

  // NEW: allow picking from camera or gallery
  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        maxWidth: 900,
        imageQuality: 85,
      );
      if (file == null) return;

      setState(() => _saving = true);

      final ref =
          FirebaseStorage.instance.ref().child('users/${user.uid}/profile.jpg');
      await ref.putFile(File(file.path));
      final url = await ref.getDownloadURL();

      await user.updatePhotoURL(url);
      if (_userDocId != null) {
        await _fs.collection('users').doc(_userDocId).set(
          {'photoUrl': url},
          SetOptions(merge: true),
        );
      } else {
        await _fs.collection('users').doc(user.uid).set(
          {'photoUrl': url, 'uid': user.uid},
          SetOptions(merge: true),
        );
        _userDocId = user.uid;
      }

      setState(() {
        _photoUrl = url;
        _saving = false;
      });
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo upload failed: $e')),
      );
    }
  }

  // NEW: delete profile photo (auth + firestore + storage)
  Future<void> _removePhoto() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      setState(() => _saving = true);

      // Try to delete from storage (best effort)
      final ref =
          FirebaseStorage.instance.ref().child('users/${user.uid}/profile.jpg');
      try {
        await ref.delete();
      } catch (_) {
        // ignore if not found/no permission
      }

      // Clear auth photo and Firestore field
      try {
        await user.updatePhotoURL(null);
      } catch (_) {}
      await _fs.collection('users').doc(user.uid).set(
        {'photoUrl': null},
        SetOptions(merge: true),
      );

      setState(() {
        _photoUrl = null;
        _saving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo removed')),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove photo: $e')),
      );
    }
  }

  // NEW: bottom sheet to choose Camera / Gallery / Remove
  Future<void> _showPhotoOptions() async {
    if (_saving) return;
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadPhoto(ImageSource.gallery);
                },
              ),
              if (_photoUrl != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Remove photo',
                      style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _removePhoto();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;

    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _saving = true);

    try {
      // Split name into first/last (best-effort)
      final name = _nameCtl.text.trim();
      final parts = name.split(RegExp(r'\s+'));
      final firstName = parts.isNotEmpty ? parts.first : '';
      final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      final payload = <String, dynamic>{
        'first_name': firstName,
        'last_name': lastName,
        'username': _usernameCtl.text.trim(),
        'dob': _birthdayCtl.text.trim(),
        'phone': _phoneCtl.text.trim(),
        'email': _emailCtl.text.trim(),
        if (_photoUrl != null) 'photoUrl': _photoUrl,
        'updated_at': DateTime.now().toIso8601String(),
        'uid': user.uid, // make future lookups easy
      };

      // Ensure the user has a deterministic doc keyed by uid
      await _fs.collection('users').doc(user.uid).set(payload, SetOptions(merge: true));
      _userDocId = user.uid;

      // Keep FirebaseAuth displayName/email in sync (email may require re-auth)
      if (user.displayName != name && name.isNotEmpty) {
        await user.updateDisplayName(name);
      }
      final newEmail = _emailCtl.text.trim();
      if (newEmail.isNotEmpty && newEmail != (user.email ?? '')) {
        try {
          await user.verifyBeforeUpdateEmail(newEmail);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('We sent a verification link to update your email.'),
            ),
          );
        } catch (_) {
          try {
            // ignore: deprecated_member_use
            await user.updateEmail(newEmail);
          } catch (_) {}
        }
      }

      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved')),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    }
  }

  // Smaller input styling
  InputDecoration _dec(IconData icon, String hint) => InputDecoration(
        prefixIcon: Icon(icon, size: 18),
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      );

  @override
  Widget build(BuildContext context) {
    final gradientTop = const Color(0xFFFFFFFF);
    final gradientMiddle = const Color(0xFFD7C3F1);
    final gradientBottom = const Color(0xFF41B3A2);
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [gradientTop, gradientMiddle, gradientBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _form,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'edit profile', // CHANGED text
                            style: TextStyle(
                              fontSize: 22, // smaller
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 46, // smaller
                              backgroundColor: Colors.white.withOpacity(.6),
                              backgroundImage:
                                  _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                              child: _photoUrl == null
                                  ? const Icon(Icons.person, size: 44, color: Color(0xFF0D7C66))
                                  : null,
                            ),
                            IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.all(8),
                              ),
                              onPressed: _saving ? null : _showPhotoOptions, // opens camera/gallery/remove
                              icon: const Icon(Icons.edit, size: 18),
                              tooltip: 'Change photo',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Fields (all pre-filled now) — smaller paddings/gaps
                      TextFormField(
                        controller: _nameCtl,
                        decoration: _dec(Icons.person_outline, 'name'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _birthdayCtl,
                        readOnly: true,
                        onTap: () async {
                          final now = DateTime.now();
                          final initial = now.subtract(const Duration(days: 365 * 20));
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: DateTime(1900),
                            lastDate: now,
                            initialDate: initial,
                          );
                          if (picked != null) {
                            _birthdayCtl.text =
                                '${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}';
                          }
                        },
                        decoration: _dec(Icons.cake_outlined, 'birthday'),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneCtl,
                        keyboardType: TextInputType.phone,
                        decoration: _dec(Icons.phone_outlined, 'phone number'),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _usernameCtl,
                        decoration: _dec(Icons.alternate_email, 'username'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailCtl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _dec(Icons.email_outlined, 'email'),
                        validator: (v) =>
                            (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 48, // smaller
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D7C66),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('Save', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

extension on User {
  updateEmail(String newEmail) {}
}
