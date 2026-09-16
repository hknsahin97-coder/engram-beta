import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/notifications/notification_plan.dart';

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

/// A wrapper around `flutter_local_notifications`.
///
/// ## The iOS/Android difference
/// Android records the schedule even without permission; iOS **silently
/// ignores** `zonedSchedule` when permission is missing and
/// `pendingNotificationRequests()` comes back empty. So [ensurePermission] must
/// be called before scheduling and its result respected -- otherwise we think
/// something was "scheduled" on iOS when nothing happened.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'engram_reminders';
  static const _channelName = 'Reminders';

  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    // Use the device's local timezone: when the user says 20:00 they mean
    // their own clock.
    tz.setLocalLocation(tz.local);

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permissions are requested contextually, NOT at launch.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  /// Requests notification permission. Called when the user first turns
  /// reminders on in Settings -- never at launch.
  ///
  /// Returns `false` if permission was refused; the caller uses that to roll
  /// the setting back, otherwise the user thinks it is on and gets nothing.
  Future<bool> ensurePermission() async {
    await init();

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
  }

  /// Applies the plan: **cancels everything first**, then schedules the new set.
  ///
  /// The full cancel is deliberate: the plan is recomputed from scratch on every
  /// launch, and the rule "no notification on a day the app was already used"
  /// only works if the older schedules are cleared.
  Future<void> apply(List<PlannedNotification> plans) async {
    await init();
    await _plugin.cancelAll();

    for (final plan in plans) {
      try {
        await _plugin.zonedSchedule(
          id: plan.id,
          title: _titleFor(plan),
          body: plan.body,
          scheduledDate: tz.TZDateTime.from(plan.when, tz.local),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          // **Exact alarm.** With inexactAllowWhileIdle the OS may defer the
          // alarm by many minutes, and on some devices it is never delivered
          // at all. The reminder is the one thing that brings a user back, so
          // late means never.
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } catch (e) {
        // One notification failing to schedule must not stop the others.
        debugPrint('Could not schedule notification (${plan.id}): $e');
      }
    }
  }

  String _titleFor(PlannedNotification plan) => plan.title;

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  /// For diagnosis: how many notifications are actually scheduled?
  Future<int> pendingCount() async {
    await init();
    return (await _plugin.pendingNotificationRequests()).length;
  }
}

extension on PlannedNotification {
  /// The title is the app name; the body already carries the message. A
  /// separate title produced needless repetition in the notification drawer.
  String get title => 'Engram';
}
