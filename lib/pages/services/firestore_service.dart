import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;
  static const _collection = 'users';

  // Shortcut for user doc ref
  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection(_collection).doc(uid);

  // Check if user already exists
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
  Future<Map<String, dynamic>?> authenticateUser(
      String input, String plainPassword) async {
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

  // Update user push notification settings
  Future<void> updateNotificationSettings(
    String uid, {
    required bool pushEnabled,
    required bool dailyReminderEnabled,
    required bool replyNotificationsEnabled,
  }) async {
    await _userDoc(uid).update({
      'push_notifications_enabled': pushEnabled,
      'daily_reminder_enabled': dailyReminderEnabled,
      'reply_notifications_enabled': replyNotificationsEnabled,
    });
  }

  // Get current user's push notification settings
  Future<Map<String, bool>> getNotificationSettings(String uid) async {
    final doc = await _userDoc(uid).get();
    final data = doc.data();

    if (data == null) {
      return {
        'push_notifications_enabled': false,
        'daily_reminder_enabled': false,
        'reply_notifications_enabled': false,
      };
    }

    final map = data;

    return {
      'push_notifications_enabled': map['push_notifications_enabled'] ?? false,
      'daily_reminder_enabled': map['daily_reminder_enabled'] ?? false,
      'reply_notifications_enabled': map['reply_notifications_enabled'] ?? false,
    };
  }

  // Save the FCM token to the user's document
  Future<void> updateFcmToken(String uid, String token) async {
    await _userDoc(uid).set({
      'fcm_token': token,
    }, SetOptions(merge: true));
  }
}
