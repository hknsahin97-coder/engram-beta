import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/notification_service.dart';
import '../../data/local/prefs_settings_repository.dart';
import '../../data/repositories/isar_card_repository.dart';
import 'notification_plan.dart';

final notificationControllerProvider = Provider<NotificationController>(
  (ref) => NotificationController(ref),
);

/// Joins scheduling to the data layer.
///
/// [reschedule] is the single entry point: called when the app opens, when
/// settings change, and when a card is added or rated. The plan is recomputed
/// from scratch every time -- there is no incremental update, because rules
/// like "no notification on a day already used" need to see the whole picture.
class NotificationController {
  NotificationController(this._ref);

  final Ref _ref;

  /// [texts] comes from the interface layer; the planner does not depend on `L10n`.
  ///
  /// **It never throws.** Notifications are a secondary feature: if the
  /// platform channel fails for any reason (an old device, a restricted
  /// profile, a test environment) it must not break launch. Errors are logged, not swallowed.
  Future<void> reschedule(NotificationTexts texts, {DateTime? now}) async {
    try {
      final settings = _ref.read(settingsRepositoryProvider);
      final service = _ref.read(notificationServiceProvider);

      if (!settings.notificationsEnabled) {
        await service.cancelAll();
        return;
      }

      final repo = _ref.read(cardRepositoryProvider);
      final cards = await repo.list();
      final plans = NotificationPlanner.plan(
        now: now ?? DateTime.now(),
        dueDates: cards.map((c) => c.dueAt).toList(),
        settings: NotificationSettings.from(settings),
        // Was anything REVIEWED today (not: was the app opened).
        lastReviewedAt: await repo.lastReviewedAt(),
        lastOpenedAt: settings.lastOpenedAt,
        texts: texts,
      );

      await service.apply(plans);
    } catch (e, st) {
      debugPrint('Notification scheduling failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  /// When the user first turns reminders on: permission first, setting second.
  ///
  /// If permission is refused the setting **does not turn on** -- a switch that
  /// looks enabled and sends nothing costs the user's trust.
  Future<bool> enable(NotificationTexts texts) async {
    final granted =
        await _ref.read(notificationServiceProvider).ensurePermission();
    if (!granted) return false;

    await _ref.read(settingsRepositoryProvider).setNotificationsEnabled(true);
    await reschedule(texts);
    return true;
  }

  Future<void> disable() async {
    await _ref.read(settingsRepositoryProvider).setNotificationsEnabled(false);
    await _ref.read(notificationServiceProvider).cancelAll();
  }

  /// Called when the app opens: records "used today" and refreshes the plan.
  /// Together, those two cancel that day's notification.
  Future<void> onAppOpened(NotificationTexts texts) async {
    try {
      await _ref
          .read(settingsRepositoryProvider)
          .setLastOpenedAt(DateTime.now());
    } catch (e) {
      debugPrint("Could not record the last launch time: $e");
    }
    await reschedule(texts);
  }
}
