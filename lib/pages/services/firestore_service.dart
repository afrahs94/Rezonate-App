import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;
  static const _collection = 'users';

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection(_collection).doc(uid);

  // Check if a user already exists by username or email
  Future<bool> userExists(String username, String email) async {
    final usernameResult = await _db
        .collection(_collection)
        .where('username', isEqualTo: username)
        .get();

    if (usernameResult.docs.isNotEmpty) return true;

    final emailResult = await _db
        .collection(_collection)
        .where('email', isEqualTo: email)
        .get();

    return emailResult.docs.isNotEmpty;
  }

  // Add user with default notification settings
  Future<void> addUser(Map<String, dynamic> user) async {
    user['push_notifications_enabled'] = false;
    user['daily_reminder_enabled'] = false;
    user['reply_notifications_enabled'] = false;

    await _db.collection(_collection).add(user);
  }

  // Authenticate by username/email + hashed password
  Future<Map<String, dynamic>?> authenticateUser(
      String input, String plainPassword) async {
    final hashed = sha256.convert(utf8.encode(plainPassword)).toString();

    final usernameMatch = await _db
        .collection(_collection)
        .where('username', isEqualTo: input)
        .where('password', isEqualTo: hashed)
        .get();

    if (usernameMatch.docs.isNotEmpty) {
      return usernameMatch.docs.first.data();
    }

    final emailMatch = await _db
        .collection(_collection)
        .where('email', isEqualTo: input)
        .where('password', isEqualTo: hashed)
        .get();

    if (emailMatch.docs.isNotEmpty) {
      return emailMatch.docs.first.data();
    }

    return null;
  }

  // 🛠 Update user's push notification settings
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

  // Get (and ensure) notification settings are set
  Future<Map<String, dynamic>> getNotificationSettings(String uid) async {
    final docRef = _userDoc(uid);
    final doc = await docRef.get();
    final data = doc.data();

    if (data == null) {
      // User doc not found — fallback defaults
      return {
        'push_notifications_enabled': false,
        'daily_reminder_enabled': false,
        'reply_notifications_enabled': false,
      };
    }

    final defaults = {
      'push_notifications_enabled': false,
      'daily_reminder_enabled': false,
      'reply_notifications_enabled': false,
    };

    final settings = {
      'push_notifications_enabled':
          data['push_notifications_enabled'] ?? defaults['push_notifications_enabled'],
      'daily_reminder_enabled':
          data['daily_reminder_enabled'] ?? defaults['daily_reminder_enabled'],
      'reply_notifications_enabled':
          data['reply_notifications_enabled'] ?? defaults['reply_notifications_enabled'],
    };

    // Auto-fix missing fields in Firestore for older users
    await docRef.set(settings, SetOptions(merge: true));

    return settings;
  }

  // 📲 Save device FCM token for push notifications
  Future<void> updateFcmToken(String uid, String token) async {
    await _userDoc(uid).set({'fcm_token': token}, SetOptions(merge: true));
  }
}
