// lib/pages/edit_profile.dart
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:image_cropper/image_cropper.dart';

class EditProfilePage extends StatefulWidget {
  final String userName;
  const EditProfilePage({super.key, required this.userName});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  // ---- Cloudinary (unsigned) ----
  static const String _cloudinaryCloudName = 'dg66js0z6'; // <= YOUR cloud name
  static const String _cloudinaryUnsignedPreset = 'a3ws0a1s'; // <= unsigned preset

  final _form = GlobalKey<FormState>();

  final _nameCtl = TextEditingController();
  final _birthdayCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _usernameCtl = TextEditingController();
  final _emailCtl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  String? _userDocId;
  String? _photoUrl; // existing remote photo URL (if any)

  // --- NEW: staged photo state (no auto-save) ---
  File? _pendingPhotoFile;      // cropped local file user picked
  bool _photoRemovedPending = false; // user chose "remove", awaiting Save

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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Not signed in')));
      }
      return;
    }

    try {
      DocumentSnapshot<Map<String, dynamic>>? snap;
      final uidDoc = await _fs.collection('users').doc(user.uid).get();
      if (uidDoc.exists) {
        snap = uidDoc;
        _userDocId = uidDoc.id;
      } else {
        final byEmail = await _fs
            .collection('users')
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();
        if (byEmail.docs.isNotEmpty) {
          snap = byEmail.docs.first;
          _userDocId = snap.id;
        } else if ((user.displayName ?? '').isNotEmpty) {
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

      final first = (data['first_name'] ?? '').toString().trim();
      final last = (data['last_name'] ?? '').toString().trim();
      final combinedName = (first.isEmpty && last.isEmpty)
          ? (user.displayName ?? '')
          : [first, last].where((s) => s.isNotEmpty).join(' ');

      _nameCtl.text = combinedName;
      _birthdayCtl.text = (data['dob'] ?? '').toString();
      _phoneCtl.text = (data['phone'] ?? '').toString();
      _usernameCtl.text = (data['username'] ?? user.displayName ?? '').toString();
      _emailCtl.text = (data['email'] ?? user.email ?? '').toString();
      _photoUrl = (data['photoUrl'] ?? user.photoURL)?.toString();

      // Clear any pending local state when loading
      _pendingPhotoFile = null;
      _photoRemovedPending = false;

      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
      }
    }
  }

  // ---------- Cloudinary upload ----------
  Future<String> _uploadToCloudinary(File localFile) async {
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload');

    final req = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _cloudinaryUnsignedPreset
      ..files.add(await http.MultipartFile.fromPath('file', localFile.path));

    final resp = await req.send();
    final body = await resp.stream.bytesToString();

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception('Cloudinary upload failed (${resp.statusCode}): $body');
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    final url = (json['secure_url'] ?? json['url'])?.toString();
    if (url == null || url.isEmpty) {
      throw Exception('Cloudinary did not return a URL.');
    }
    return url;
  }

  // Pick from camera or gallery, crop, and STAGE the result (do not upload).
  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (picked == null) return;

      final CroppedFile? cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop photo',
            toolbarColor: const Color(0xFF0D7C66),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Crop photo',
            aspectRatioLockEnabled: false,
          ),
        ],
      );
      if (cropped == null) return;

      // Stage locally for preview; commit on Save.
      setState(() {
        _pendingPhotoFile = File(cropped.path);
        _photoRemovedPending = false; // picking a photo cancels a pending removal
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo ready. Tap Save to apply.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick/crop photo: $e')),
        );
      }
    }
  }

  // Stage photo removal (do not update backend until Save).
  Future<void> _removePhoto() async {
    setState(() {
      _pendingPhotoFile = null;
      _photoRemovedPending = true;
      _photoUrl = null; // reflect in UI immediately
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo will be removed after you Save.')),
      );
    }
  }

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
              if (_photoUrl != null || _pendingPhotoFile != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title:
                      const Text('Remove photo', style: TextStyle(color: Colors.red)),
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
      // Resolve a final photoUrl to save (if changed).
      String? finalPhotoUrl = _photoUrl;

      if (_pendingPhotoFile != null) {
        // Upload newly staged photo now
        finalPhotoUrl = await _uploadToCloudinary(_pendingPhotoFile!);
        try {
          await user.updatePhotoURL(finalPhotoUrl);
        } catch (_) {}
      } else if (_photoRemovedPending) {
        finalPhotoUrl = null;
        try {
          await user.updatePhotoURL(null);
        } catch (_) {}
      }

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
        'photoUrl': finalPhotoUrl, // write null to clear, url to set, unchanged if same
        'updated_at': DateTime.now().toIso8601String(),
        'uid': user.uid,
      };

      await _fs.collection('users').doc(user.uid).set(payload, SetOptions(merge: true));
      _userDocId = user.uid;

      if (name.isNotEmpty && user.displayName != name) {
        await user.updateDisplayName(name);
      }

      final newEmail = _emailCtl.text.trim();
      if (newEmail.isNotEmpty && newEmail != (user.email ?? '')) {
        try {
          await user.verifyBeforeUpdateEmail(newEmail);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('We sent a verification link to update your email.'),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Email not updated: $e')));
          }
        }
      }

      // Commit local state after successful save
      _photoUrl = finalPhotoUrl;
      _pendingPhotoFile = null;
      _photoRemovedPending = false;

      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profile saved')));
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

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
    // gradient
    const gradientTop = Color(0xFFFFFFFF);
    const gradientMiddle = Color(0xFFD7C3F1);
    const gradientBottom = Color(0xFF41B3A2);

    // Decide which image to preview
    ImageProvider? _previewImage() {
      if (_pendingPhotoFile != null) return FileImage(_pendingPhotoFile!);
      if (_photoUrl != null && _photoUrl!.isNotEmpty) return NetworkImage(_photoUrl!);
      return null;
    }

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
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
                            'Edit Profile',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 46,
                              backgroundColor: Colors.white.withOpacity(.6),
                              backgroundImage: _previewImage(),
                              child: _previewImage() == null
                                  ? const Icon(Icons.person, size: 44, color: Color(0xFF0D7C66))
                                  : null,
                            ),
                            IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.all(8),
                              ),
                              onPressed: _saving ? null : _showPhotoOptions,
                              icon: const Icon(Icons.edit, size: 18),
                              tooltip: 'Change photo',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _nameCtl,
                        decoration: _dec(Icons.person_outline, 'name'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailCtl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _dec(Icons.email_outlined, 'email'),
                        validator: (v) => (v == null || !v.contains('@'))
                            ? 'Enter a valid email'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 48,
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
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
