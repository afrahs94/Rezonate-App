import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  Future<Map<String, dynamic>> getNotificationSettings(String uid) async {
    final s = (await _userDoc(uid).get()).data() ?? {};
    final n = (s['notifications'] as Map<String, dynamic>?) ?? {};
    final merged = {
      'push_enabled'     : n['push_enabled'] ?? false,
      'reminders_enabled': n['reminders_enabled'] ?? false,
      'replies_enabled'  : n['replies_enabled'] ?? false,
      'mentions_enabled' : n['mentions_enabled'] ?? false,
      'reactions_enabled': n['reactions_enabled'] ?? false,
    };
    // seed if missing
    await updateNotificationSettings(uid,
      pushEnabled: merged['push_enabled']!,
      remindersEnabled: merged['reminders_enabled']!,
      repliesEnabled: merged['replies_enabled']!,
      mentionsEnabled: merged['mentions_enabled']!,
      reactionsEnabled: merged['reactions_enabled']!,
    );
    return merged;
  }

  Future<void> updateNotificationSettings(
    String uid, {
    required bool pushEnabled,
    required bool remindersEnabled,
    required bool repliesEnabled,
    required bool mentionsEnabled,
    required bool reactionsEnabled,
  }) async {
    await _userDoc(uid).set({
      'notifications': {
        'push_enabled': pushEnabled,
        'reminders_enabled': remindersEnabled,
        'replies_enabled': repliesEnabled,
        'mentions_enabled': mentionsEnabled,
        'reactions_enabled': reactionsEnabled,
      }
    }, SetOptions(merge: true));
  }

  Future<void> updateFcmToken(String uid, String token) async {
    await _userDoc(uid).set({
      'fcmTokens': { token: true },
      'fcmLastUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> removeFcmToken(String uid, String token) async {
    await _userDoc(uid).set({
      'fcmTokens': { token: FieldValue.delete() },
    }, SetOptions(merge: true));
  }
}
