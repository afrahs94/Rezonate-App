import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;
  static const _collection = 'users';

  // Check if user already exists (by username or email)
  Future<bool> userExists(String username, String email) async {
    final result = await _db.collection(_collection)
      .where('username', isEqualTo: username)
      .get();

    if (result.docs.isNotEmpty) return true;

    final emailResult = await _db.collection(_collection)
      .where('email', isEqualTo: email)
      .get();

    return emailResult.docs.isNotEmpty;
  }

  // Add user
  Future<void> addUser(Map<String, dynamic> user) async {
    await _db.collection(_collection).add(user);
  }

  // Authenticate user by username/email + password
  Future<Map<String, dynamic>?> authenticateUser(String input, String plainPassword) async {
    final hashed = sha256.convert(utf8.encode(plainPassword)).toString();

    final result = await _db.collection(_collection)
      .where('password', isEqualTo: hashed)
      .where('username', isEqualTo: input)
      .get();

    if (result.docs.isEmpty) {
      final emailResult = await _db.collection(_collection)
        .where('password', isEqualTo: hashed)
        .where('email', isEqualTo: input)
        .get();

      if (emailResult.docs.isEmpty) return null;
      return emailResult.docs.first.data();
    }

    return result.docs.first.data();
  }
}
