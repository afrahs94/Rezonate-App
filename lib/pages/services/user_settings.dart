import 'package:shared_preferences/shared_preferences.dart';

class UserSettings {
  static late SharedPreferences _prefs;

  static const _kAppLockEnabled = 'appLockEnabled';
  static const _kShareWithUsername = 'shareWithUsername';
  static const _kAnonymous = 'anonymous';
  static const _kPushEnabled = 'pushEnabled';
  static const _kEmailNotifications = 'emailNotifications';
  static const _kDailyReminderEnabled = 'dailyReminderEnabled';
  static const _kReplyNotificationsEnabled = 'replyNotificationsEnabled';

  static bool get hasPushPreference => _prefs.containsKey(_kPushEnabled);

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    _setIfNull(_kAppLockEnabled, false);
    _setIfNull(_kShareWithUsername, true);
    _setIfNull(_kAnonymous, false);
    _setIfNull(_kPushEnabled, false);
    _setIfNull(_kEmailNotifications, false);
    _setIfNull(_kDailyReminderEnabled, false);
    _setIfNull(_kReplyNotificationsEnabled, false);
  }

  static void _setIfNull(String key, bool defaultValue) {
    if (!_prefs.containsKey(key)) {
      _prefs.setBool(key, defaultValue);
    }
  }

  static Future<void> setAppLockEnabled(bool v) async =>
      await _prefs.setBool(_kAppLockEnabled, v);
  static bool get appLockEnabled => _prefs.getBool(_kAppLockEnabled) ?? false;

  static Future<void> setShareWithUsername(bool v) async =>
      await _prefs.setBool(_kShareWithUsername, v);
  static bool get shareWithUsername =>
      _prefs.getBool(_kShareWithUsername) ?? true;

  static Future<void> setAnonymous(bool v) async =>
      await _prefs.setBool(_kAnonymous, v);
  static bool get anonymous => _prefs.getBool(_kAnonymous) ?? false;

  static Future<void> setPushEnabled(bool v) async =>
      await _prefs.setBool(_kPushEnabled, v);
  static bool get pushEnabled => _prefs.getBool(_kPushEnabled) ?? false;

  static Future<void> setEmailNotifications(bool v) async =>
      await _prefs.setBool(_kEmailNotifications, v);
  static bool get emailNotifications =>
      _prefs.getBool(_kEmailNotifications) ?? false;

  static Future<void> setDailyReminderEnabled(bool v) async =>
      await _prefs.setBool(_kDailyReminderEnabled, v);
  static bool get dailyReminderEnabled =>
      _prefs.getBool(_kDailyReminderEnabled) ?? false;

  static Future<void> setReplyNotificationsEnabled(bool v) async =>
      await _prefs.setBool(_kReplyNotificationsEnabled, v);
  static bool get replyNotificationsEnabled =>
      _prefs.getBool(_kReplyNotificationsEnabled) ?? false;

  static Future<void> clearAll() async => await _prefs.clear();

  static Map<String, bool> getAllFlags() {
    return {
      'appLockEnabled': appLockEnabled,
      'shareWithUsername': shareWithUsername,
      'anonymous': anonymous,
      'pushEnabled': pushEnabled,
      'emailNotifications': emailNotifications,
      'dailyReminderEnabled': dailyReminderEnabled,
      'replyNotificationsEnabled': replyNotificationsEnabled,
    };
  }
}
