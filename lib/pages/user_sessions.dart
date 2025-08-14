//// lib/user_session.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserSession {
  UserSession._();
  static final UserSession instance = UserSession._();

  static const _kPrefsKey = 'user_session_v1';

  Map<String, dynamic>? _data;

  Map<String, dynamic>? get data => _data;

  String? get uid => _data?['uid'] as String?;
  String? get username => _data?['username'] as String?;
  String? get firstName => _data?['first_name'] as String?;
  String? get lastName => _data?['last_name'] as String?;
  String? get email => _data?['email'] as String?;
  String? get gender => _data?['gender'] as String?;
  String? get dob => _data?['dob'] as String?;

  /// Load any previously saved profile into memory on app start.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsKey);
    if (raw != null) {
      try {
        _data = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        _data = null;
      }
    }
  }

  /// Save to memory + disk (password field is removed if present).
  Future<void> set(Map<String, dynamic> profile) async {
    final sanitized = Map<String, dynamic>.from(profile)..remove('password');
    _data = sanitized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsKey, jsonEncode(sanitized));
  }

  /// Clear session (e.g., on logout).
  Future<void> clear() async {
    _data = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefsKey);
  }

  /// Re-fetch the latest doc and re-save it locally.
  Future<void> refreshFromFirestore(FirebaseFirestore db, String uid) async {
    final snap = await db.collection('users').doc(uid).get();
    final d = snap.data();
    if (d != null) {
      await set(d); // set() strips password before persisting
    }
  }
}