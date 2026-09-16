/// Notification mode.
enum NotificationMode {
  /// One notification at the hour the user chose, if cards are due that day and
  /// the app has not been opened yet. **The default.**
  dailyTime,

  /// A warning once the pending-card count passes a threshold. A deliberately
  /// more insistent mode that the user turns on themselves.
  threshold,
}

/// Time of day -- so `TimeOfDay` does not leak into the data layer (a plain
/// carrier with no Flutter dependency).
class DayTime {
  const DayTime(this.hour, this.minute);

  final int hour;
  final int minute;

  int get asMinutes => hour * 60 + minute;

  static DayTime fromMinutes(int m) => DayTime(m ~/ 60, m % 60);

  @override
  bool operator ==(Object other) =>
      other is DayTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// Defaults in one place.
abstract final class SettingsDefaults {
  /// Changeable from Settings.
  static const int dailyCap = 25;

  static const NotificationMode notificationMode = NotificationMode.dailyTime;

  /// 20:00 by default.
  static const DayTime notificationTime = DayTime(20, 0);

  /// Show the count, on by default. The number shown is always
  /// `min(dueCount, dailyCap)`, never the raw overdue total.
  static const bool showCountInNotification = true;

  static const int threshold = 50;

  /// One gentle reminder whose tone shifts after a few days away.
  static const int inactivityReminderDays = 3;
}

/// The **interface** for settings. The storage detail (currently
/// `SharedPreferences`) does not leak into the layers above.
abstract interface class SettingsRepository {
  int get dailyCap;
  Future<void> setDailyCap(int value);

  /// The master switch for notifications.
  ///
  /// **Off by default.** Notification permission is requested contextually --
  /// not at launch, but the first time the user turns this on.
  bool get notificationsEnabled;
  Future<void> setNotificationsEnabled(bool value);

  NotificationMode get notificationMode;
  Future<void> setNotificationMode(NotificationMode value);

  DayTime get notificationTime;
  Future<void> setNotificationTime(DayTime value);

  bool get showCountInNotification;
  Future<void> setShowCountInNotification(bool value);

  int get threshold;
  Future<void> setThreshold(int value);

  /// The one-time reminder shown when the user hits the daily cap for the
  /// **first** time. It never appears again afterwards.
  bool get dailyCapHintShown;
  Future<void> markDailyCapHintShown();

  /// The day the app was last opened -- for the "no second notification on the
  /// same day" and "inactivity reminder" rules.
  DateTime? get lastOpenedAt;
  Future<void> setLastOpenedAt(DateTime value);

  /// Whether camera permission **has been granted before**.
  ///
  /// Not a user preference but a remembered fact -- it lives here because this
  /// is the only persistent store, and opening a second wrapper just for it
  /// would be needless.
  ///
  /// Why it is needed: the `camera` plugin cannot ask "is permission granted?"
  /// **without** asking; the only way to find out is to try opening the camera,
  /// which triggers the permission dialog. For the flow to stay contextual (on
  /// the first shutter tap, not when the user swipes to Camera mode) this fact
  /// has to be remembered. `permission_handler` would solve it, at the cost of
  /// another native dependency.
  ///
  /// If permission is revoked later the flag goes stale; the camera then fails
  /// to open and the screen falls back to the permission state -- so the flag
  /// is a shortcut, not the source of truth.
  bool get cameraGranted;
  Future<void> setCameraGranted(bool value);

  /// The "delete all data" flow in Settings resets settings too.
  Future<void> resetAll();
}
