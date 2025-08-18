import 'package:shared_preferences/shared_preferences.dart';

/// Centralized, persistent app settings used across Settings sub-pages.
/// Call `await UserSettings.init()` once early (e.g., in main.dart) before use.
class UserSettings {
  static late SharedPreferences _prefs;

  // Keys
  static const _kAppLockEnabled = 'appLockEnabled';
  static const _kShareWithUsername = 'shareWithUsername';
  static const _kAnonymous = 'anonymous';
  static const _kPushEnabled = 'pushEnabled';
  static const _kEmailNotifications = 'emailNotifications';
  static const _kDailyReminderEnabled = 'dailyReminderEnabled';
  static const _kReplyNotificationsEnabled = 'replyNotificationsEnabled';

  /// Initialize SharedPreferences instance and seed defaults if missing.
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    _setIfNull(_kAppLockEnabled, false);
    _setIfNull(_kShareWithUsername, true);
    _setIfNull(_kAnonymous, false);
    _setIfNull(_kPushEnabled, true);
    _setIfNull(_kEmailNotifications, false);
    _setIfNull(_kDailyReminderEnabled, false);
    _setIfNull(_kReplyNotificationsEnabled, false);
  }

  static void _setIfNull(String key, bool defaultValue) {
    if (!_prefs.containsKey(key)) {
      _prefs.setBool(key, defaultValue);
    }
  }

  // ------------ App Lock ------------
  static bool get appLockEnabled => _prefs.getBool(_kAppLockEnabled) ?? false;
  static set appLockEnabled(bool v) => _prefs.setBool(_kAppLockEnabled, v);

  // ------------ Sharing Preferences ------------
  static bool get shareWithUsername => _prefs.getBool(_kShareWithUsername) ?? true;
  static set shareWithUsername(bool v) => _prefs.setBool(_kShareWithUsername, v);

  static bool get anonymous => _prefs.getBool(_kAnonymous) ?? false;
  static set anonymous(bool v) => _prefs.setBool(_kAnonymous, v);

  // ------------ Notifications ------------
  static bool get pushEnabled => _prefs.getBool(_kPushEnabled) ?? true;
  static set pushEnabled(bool v) => _prefs.setBool(_kPushEnabled, v);

  static bool get emailNotifications => _prefs.getBool(_kEmailNotifications) ?? false;
  static set emailNotifications(bool v) => _prefs.setBool(_kEmailNotifications, v);

  static bool get dailyReminderEnabled => _prefs.getBool(_kDailyReminderEnabled) ?? false;
  static set dailyReminderEnabled(bool v) => _prefs.setBool(_kDailyReminderEnabled, v);

  static bool get replyNotificationsEnabled => _prefs.getBool(_kReplyNotificationsEnabled) ?? false;
  static set replyNotificationsEnabled(bool v) => _prefs.setBool(_kReplyNotificationsEnabled, v);
}

