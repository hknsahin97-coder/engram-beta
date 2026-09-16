import 'package:engram/data/repositories/settings_repository.dart';
import 'package:engram/domain/notifications/notification_plan.dart';
import 'package:flutter_test/flutter_test.dart';

const _texts = NotificationTexts(
  title: 'Engram',
  dailyWithCount: _withCount,
  dailyNoCount: 'A few cards are waiting for you',
  pileUp: 'Your cards have been stacking up',
  comeBack: 'Your cards are still here whenever you are',
);

String _withCount(int n) => '$n cards are waiting for you';

NotificationSettings _settings({
  bool enabled = true,
  NotificationMode mode = NotificationMode.dailyTime,
  DayTime time = const DayTime(20, 0),
  bool showCount = true,
  int threshold = 50,
  int dailyCap = 25,
  int inactivityDays = 3,
}) =>
    NotificationSettings(
      enabled: enabled,
      mode: mode,
      time: time,
      showCount: showCount,
      threshold: threshold,
      dailyCap: dailyCap,
      inactivityDays: inactivityDays,
    );

/// 09:00 in the morning -- that day's 20:00 has not arrived yet.
final _now = DateTime(2026, 8, 5, 9);

List<DateTime> _dueNow(int count) =>
    List.filled(count, _now.subtract(const Duration(hours: 1)));

void main() {
  group('while off', () {
    test('nothing is scheduled', () {
      final plans = NotificationPlanner.plan(
        now: _now,
        dueDates: _dueNow(10),
        settings: _settings(enabled: false),
        lastReviewedAt: null,
        lastOpenedAt: null,
        texts: _texts,
      );
      expect(plans, isEmpty);
    });
  });

  group('fixed-hour mode', () {
    test('it also schedules for today if the hour has not passed', () {
      final plans = NotificationPlanner.plan(
        now: _now,
        dueDates: _dueNow(3),
        settings: _settings(),
        lastReviewedAt: null,
        lastOpenedAt: null,
        texts: _texts,
      );

      final today = plans.firstWhere((p) => p.when.day == 5);
      expect(today.when.hour, 20);
      expect(today.body, '3 cards are waiting for you');
    });

    test('it does not schedule for today once the hour has passed', () {
      final plans = NotificationPlanner.plan(
        now: DateTime(2026, 8, 5, 21), // past 20:00
        dueDates: _dueNow(3),
        settings: _settings(),
        lastReviewedAt: null,
        lastOpenedAt: null,
        texts: _texts,
      );

      expect(plans.where((p) => p.when.day == 5), isEmpty);
    });

    test('no notification today if something was reviewed today', () {
      final plans = NotificationPlanner.plan(
        now: _now,
        dueDates: _dueNow(3),
        settings: _settings(),
        lastReviewedAt: DateTime(2026, 8, 5, 8),
        lastOpenedAt: DateTime(2026, 8, 5, 8),
        texts: _texts,
      );

      expect(plans.where((p) => p.when.day == 5), isEmpty);
      // Scheduling for tomorrow continues.
      expect(plans.where((p) => p.when.day == 6), isNotEmpty);
    });

    // Opening the app usually means *capturing* -- that is the primary use.
    // A rule of "no reminder if the app was opened today" would mean someone
    // taking notes during the day never gets the evening reminder; the more
    // they capture, the more they lose it.
    test('opening the app (capturing) does not silence the notification', () {
      final plans = NotificationPlanner.plan(
        now: _now,
        dueDates: _dueNow(3),
        settings: _settings(),
        lastReviewedAt: null, // nothing was reviewed today
        lastOpenedAt: DateTime(2026, 8, 5, 8), // but the app was opened
        texts: _texts,
      );

      expect(plans.where((p) => p.when.day == 5), isNotEmpty,
          reason: 'opening to capture must not cancel the review reminder');
    });

    test('a review yesterday does not silence today', () {
      final plans = NotificationPlanner.plan(
        now: _now,
        dueDates: _dueNow(3),
        settings: _settings(),
        lastReviewedAt: DateTime(2026, 8, 4, 20),
        lastOpenedAt: DateTime(2026, 8, 4, 20),
        texts: _texts,
      );

      expect(plans.where((p) => p.when.day == 5), isNotEmpty);
    });

    test('no notification when there are no cards to review', () {
      // An empty reminder costs trust.
      final plans = NotificationPlanner.plan(
        now: _now,
        dueDates: const [],
        settings: _settings(),
        lastReviewedAt: null,
        lastOpenedAt: null,
        texts: _texts,
      );

      expect(
        plans.where((p) => p.kind == NotificationKind.dailyTime),
        isEmpty,
      );
    });

    // Proof that the "never show the real total" rule holds for notifications too.
    test('the number shown is clamped by the daily cap', () {
      final plans = NotificationPlanner.plan(
        now: _now,
        dueDates: _dueNow(400),
        settings: _settings(dailyCap: 25),
        lastReviewedAt: null,
        lastOpenedAt: null,
        texts: _texts,
      );

      final today = plans.firstWhere((p) => p.when.day == 5);
      expect(today.body, '25 cards are waiting for you',
          reason: 'the raw accumulated total (400) must never be shown');
    });

    test('text without a number while the count is turned off', () {
      final plans = NotificationPlanner.plan(
        now: _now,
        dueDates: _dueNow(9),
        settings: _settings(showCount: false),
        lastReviewedAt: null,
        lastOpenedAt: null,
        texts: _texts,
      );

      final today = plans.firstWhere((p) => p.when.day == 5);
      expect(today.body, 'A few cards are waiting for you');
    });

    test('cards becoming due in the future count towards that day', () {
      final plans = NotificationPlanner.plan(
        now: _now,
        dueDates: [DateTime(2026, 8, 7, 12)], // two days later
        settings: _settings(),
        lastReviewedAt: null,
        lastOpenedAt: null,
        texts: _texts,
      );

      // Not counted on the 5th or 6th, counted on the 7th.
      expect(plans.where((p) => p.when.day == 5), isEmpty);
      expect(plans.where((p) => p.when.day == 6), isEmpty);
      expect(plans.where((p) => p.when.day == 7), isNotEmpty);
    });
  });

  group('threshold mode', () {
    test('no notification below the threshold', () {
      final plans = NotificationPlanner.plan(
        now: _now,
        dueDates: _dueNow(10),
        settings: _settings(mode: NotificationMode.threshold, threshold: 50),
        lastReviewedAt: null,
        lastOpenedAt: null,
        texts: _texts,
      );

      expect(
        plans.where((p) => p.kind == NotificationKind.threshold),
        isEmpty,
      );
    });

    test('it warns without giving a number once the threshold is passed', () {
      final plans = NotificationPlanner.plan(
        now: _now,
        dueDates: _dueNow(60),
        settings: _settings(mode: NotificationMode.threshold, threshold: 50),
        lastReviewedAt: null,
        lastOpenedAt: null,
        texts: _texts,
      );

      final today = plans.firstWhere((p) => p.when.day == 5);
      expect(today.kind, NotificationKind.threshold);
      expect(today.body, 'Your cards have been stacking up');
    });
  });

  group('inactivity reminder', () {
    test('a single gentle message N days after the last visit', () {
      final plans = NotificationPlanner.plan(
        now: _now,
        dueDates: _dueNow(5),
        settings: _settings(inactivityDays: 3),
        lastReviewedAt: null,
        lastOpenedAt: DateTime(2026, 8, 5, 8),
        texts: _texts,
      );

      final comebacks =
          plans.where((p) => p.kind == NotificationKind.comeback).toList();
      expect(comebacks.length, 1);
      expect(comebacks.single.when.day, 8);
      expect(comebacks.single.body, 'Your cards are still here whenever you are');
    });

    // "A second notification on the same day is never sent."
    test('it replaces the normal notification falling on the same day', () {
      final plans = NotificationPlanner.plan(
        now: _now,
        dueDates: _dueNow(5),
        settings: _settings(inactivityDays: 3),
        lastReviewedAt: null,
        lastOpenedAt: DateTime(2026, 8, 5, 8),
        texts: _texts,
      );

      final onThatDay = plans.where((p) => p.when.day == 8).toList();
      expect(onThatDay.length, 1);
      expect(onThatDay.single.kind, NotificationKind.comeback);
    });
  });

  group('general rules', () {
    test('at most one notification per day', () {
      final plans = NotificationPlanner.plan(
        now: _now,
        dueDates: _dueNow(100),
        settings: _settings(),
        lastReviewedAt: null,
        lastOpenedAt: DateTime(2026, 8, 5, 8),
        texts: _texts,
      );

      final days = plans.map((p) => p.when.day).toList();
      expect(days.toSet().length, days.length, reason: 'two notifications on the same day');
    });

    test('all in the future', () {
      final plans = NotificationPlanner.plan(
        now: _now,
        dueDates: _dueNow(5),
        settings: _settings(),
        lastReviewedAt: null,
        lastOpenedAt: null,
        texts: _texts,
      );

      for (final p in plans) {
        expect(p.when.isAfter(_now), isTrue, reason: '${p.when} is in the past');
      }
    });

    test('it schedules as far as the horizon', () {
      final plans = NotificationPlanner.plan(
        now: _now,
        dueDates: _dueNow(5),
        settings: _settings(),
        lastReviewedAt: null,
        lastOpenedAt: null,
        texts: _texts,
      );

      expect(plans.length, lessThanOrEqualTo(NotificationPlanner.horizonDays + 1));
    });
  });
}
