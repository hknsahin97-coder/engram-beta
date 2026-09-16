import '../../data/repositories/settings_repository.dart';

/// A single scheduled notification.
class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.when,
    required this.body,
    required this.kind,
  });

  final int id;

  /// **Local** time -- when the user says 20:00 they mean their own clock.
  final DateTime when;

  final String body;
  final NotificationKind kind;

  @override
  String toString() => '$kind @ $when: $body';
}

enum NotificationKind { dailyTime, threshold, comeback }

/// Notification texts. Passed in so the planner does not depend on `L10n` --
/// that keeps it pure Dart and testable.
class NotificationTexts {
  const NotificationTexts({
    required this.title,
    required this.dailyWithCount,
    required this.dailyNoCount,
    required this.pileUp,
    required this.comeBack,
  });

  final String title;
  final String Function(int count) dailyWithCount;
  final String dailyNoCount;
  final String pileUp;
  final String comeBack;
}

/// The notification planner -- a **pure function** with no side effects.
///
/// ## Why we schedule in advance
/// The app is offline-first: there is no server, and iOS/Android will not run
/// our code in the background on demand. So at the moment a notification is
/// delivered we cannot work out "how many cards are due right now". Instead,
/// every time the app opens, the next [horizonDays] days of notifications are
/// scheduled with their counts **computed in advance**, and the old ones cancelled.
///
/// The consequence: the number shown is based on what was known the last time
/// the app was opened. If cards are added in between it can run a little low --
/// but that beats showing the user **more** cards than there are.
abstract final class NotificationPlanner {
  /// How many days ahead we schedule. Because the app replans on every launch,
  /// this is really the answer to "how many days does a user who never opens
  /// the app keep receiving notifications".
  static const int horizonDays = 7;

  static const int _dailyIdBase = 1000;
  static const int _comebackId = 2000;

  /// Two separate signals, two separate purposes:
  /// - [lastReviewedAt] -> should *today's* notification be skipped? If the
  ///   user has done their work, no reminder is needed.
  /// - [lastOpenedAt] -> have they been away a long time? The welcome-back
  ///   message looks at this.
  static List<PlannedNotification> plan({
    required DateTime now,
    required List<DateTime> dueDates,
    required NotificationSettings settings,
    required DateTime? lastReviewedAt,
    required DateTime? lastOpenedAt,
    required NotificationTexts texts,
  }) {
    if (!settings.enabled) return const [];

    final plans = <PlannedNotification>[];

    // **"Reviewed", not "opened".** In this app, opening usually means
    // *capturing* -- that is the primary use. Had we said "no reminder if you
    // opened the app today", someone taking notes during the day (that is,
    // using the app exactly as designed) would never get the evening reminder.
    // The more you captured, the more reliably you lost it.
    final reviewedToday = lastReviewedAt != null &&
        _isSameLocalDay(lastReviewedAt.toLocal(), now);

    for (var day = 0; day <= horizonDays; day++) {
      final slot = DateTime(
        now.year,
        now.month,
        now.day + day,
        settings.time.hour,
        settings.time.minute,
      );

      // An hour already past is not scheduled.
      if (!slot.isAfter(now)) continue;

      // If something was already reviewed today, today's notification is skipped.
      if (day == 0 && reviewedToday) continue;

      // How many cards are due by that moment.
      final due = dueDates
          .where((d) => !d.toLocal().isAfter(slot))
          .length;

      final plan = switch (settings.mode) {
        NotificationMode.dailyTime => _daily(day, slot, due, settings, texts),
        NotificationMode.threshold => _threshold(day, slot, due, settings, texts),
      };
      if (plan != null) plans.add(plan);
    }

    _addComeback(plans, now, settings, lastOpenedAt, texts);
    return plans;
  }

  static PlannedNotification? _daily(
    int day,
    DateTime slot,
    int due,
    NotificationSettings settings,
    NotificationTexts texts,
  ) {
    // No cards to review means no notification -- an empty reminder costs
    // trust.
    if (due == 0) return null;

    // **The number shown is never the raw accumulated total**: it is clamped
    // by the daily cap.
    final shown = due < settings.dailyCap ? due : settings.dailyCap;

    return PlannedNotification(
      id: _dailyIdBase + day,
      when: slot,
      body: settings.showCount
          ? texts.dailyWithCount(shown)
          : texts.dailyNoCount,
      kind: NotificationKind.dailyTime,
    );
  }

  static PlannedNotification? _threshold(
    int day,
    DateTime slot,
    int due,
    NotificationSettings settings,
    NotificationTexts texts,
  ) {
    // Threshold mode is the deliberately more insistent mode the user turns on
    // themselves. Even so no number is given -- only a "there is a pile" signal.
    if (due < settings.threshold) return null;

    return PlannedNotification(
      id: _dailyIdBase + day,
      when: slot,
      body: texts.pileUp,
      kind: NotificationKind.threshold,
    );
  }

  /// The **single** gentle reminder whose tone shifts after a few days away.
  ///
  /// It replaces that day's normal notification -- two notifications never go
  /// out on the same day.
  static void _addComeback(
    List<PlannedNotification> plans,
    DateTime now,
    NotificationSettings settings,
    DateTime? lastOpenedAt,
    NotificationTexts texts,
  ) {
    final since = (lastOpenedAt ?? now).toLocal();
    final slot = DateTime(
      since.year,
      since.month,
      since.day + settings.inactivityDays,
      settings.time.hour,
      settings.time.minute,
    );
    if (!slot.isAfter(now)) return;

    plans.removeWhere((p) => _isSameLocalDay(p.when, slot));
    plans.add(PlannedNotification(
      id: _comebackId,
      when: slot,
      body: texts.comeBack,
      kind: NotificationKind.comeback,
    ));
  }

  static bool _isSameLocalDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// A snapshot of the settings the planner needs -- a plain carrier, so it does
/// not depend on the interface layer.
class NotificationSettings {
  const NotificationSettings({
    required this.enabled,
    required this.mode,
    required this.time,
    required this.showCount,
    required this.threshold,
    required this.dailyCap,
    this.inactivityDays = SettingsDefaults.inactivityReminderDays,
  });

  final bool enabled;
  final NotificationMode mode;
  final DayTime time;
  final bool showCount;
  final int threshold;
  final int dailyCap;
  final int inactivityDays;

  factory NotificationSettings.from(SettingsRepository s) =>
      NotificationSettings(
        enabled: s.notificationsEnabled,
        mode: s.notificationMode,
        time: s.notificationTime,
        showCount: s.showCountInNotification,
        threshold: s.threshold,
        dailyCap: s.dailyCap,
      );
}
