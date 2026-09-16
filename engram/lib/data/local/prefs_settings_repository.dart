import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/theme_controller.dart' show sharedPreferencesProvider;
import '../repositories/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => PrefsSettingsRepository(ref.watch(sharedPreferencesProvider)),
);

/// The `SharedPreferences` implementation of [SettingsRepository].
///
/// Reads are synchronous: `SharedPreferences` keeps values in memory and
/// settings are read on every screen. Async would mean a `FutureBuilder` everywhere.
class PrefsSettingsRepository implements SettingsRepository {
  PrefsSettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _kDailyCap = 'daily_cap';
  static const _kNotificationsEnabled = 'notifications_enabled';
  static const _kNotificationMode = 'notification_mode';
  static const _kNotificationTime = 'notification_time_minutes';
  static const _kShowCount = 'notification_show_count';
  static const _kThreshold = 'notification_threshold';
  static const _kDailyCapHint = 'daily_cap_hint_shown';
  static const _kLastOpened = 'last_opened_at';
  static const _kCameraGranted = 'camera_permission_granted';

  @override
  int get dailyCap => _prefs.getInt(_kDailyCap) ?? SettingsDefaults.dailyCap;

  @override
  Future<void> setDailyCap(int value) async {
    // Below 1 the queue closes entirely; the upper bound exists so the cap does
    // not turn into "finish everything today" pressure.
    final clamped = value.clamp(1, 200);
    await _prefs.setInt(_kDailyCap, clamped);
  }

  @override
  bool get notificationsEnabled =>
      _prefs.getBool(_kNotificationsEnabled) ?? false;

  @override
  Future<void> setNotificationsEnabled(bool value) =>
      _prefs.setBool(_kNotificationsEnabled, value);

  @override
  NotificationMode get notificationMode {
    final raw = _prefs.getString(_kNotificationMode);
    return NotificationMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => SettingsDefaults.notificationMode,
    );
  }

  @override
  Future<void> setNotificationMode(NotificationMode value) =>
      _prefs.setString(_kNotificationMode, value.name);

  @override
  DayTime get notificationTime {
    final minutes = _prefs.getInt(_kNotificationTime);
    return minutes == null
        ? SettingsDefaults.notificationTime
        : DayTime.fromMinutes(minutes);
  }

  @override
  Future<void> setNotificationTime(DayTime value) =>
      _prefs.setInt(_kNotificationTime, value.asMinutes);

  @override
  bool get showCountInNotification =>
      _prefs.getBool(_kShowCount) ?? SettingsDefaults.showCountInNotification;

  @override
  Future<void> setShowCountInNotification(bool value) =>
      _prefs.setBool(_kShowCount, value);

  @override
  int get threshold => _prefs.getInt(_kThreshold) ?? SettingsDefaults.threshold;

  @override
  Future<void> setThreshold(int value) =>
      _prefs.setInt(_kThreshold, value.clamp(1, 999));

  @override
  bool get dailyCapHintShown => _prefs.getBool(_kDailyCapHint) ?? false;

  @override
  Future<void> markDailyCapHintShown() =>
      _prefs.setBool(_kDailyCapHint, true);

  @override
  DateTime? get lastOpenedAt {
    final raw = _prefs.getInt(_kLastOpened);
    return raw == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
  }

  @override
  Future<void> setLastOpenedAt(DateTime value) =>
      _prefs.setInt(_kLastOpened, value.toUtc().millisecondsSinceEpoch);

  @override
  bool get cameraGranted => _prefs.getBool(_kCameraGranted) ?? false;

  @override
  Future<void> setCameraGranted(bool value) =>
      _prefs.setBool(_kCameraGranted, value);

  @override
  Future<void> resetAll() async {
    for (final key in [
      _kDailyCap,
      _kNotificationsEnabled,
      _kNotificationMode,
      _kNotificationTime,
      _kShowCount,
      _kThreshold,
      _kDailyCapHint,
      _kLastOpened,
      // "Delete all data" really does reset everything. The system permission
      // stays in place, so the user meets no new dialog; the viewfinder simply
      // opens on the first tap of the shutter.
      _kCameraGranted,
    ]) {
      await _prefs.remove(key);
    }
  }
}
