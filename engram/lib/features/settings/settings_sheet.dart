import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/media/media_store.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/sheet_scaffold.dart';
import '../../data/local/prefs_settings_repository.dart';
import '../../data/repositories/isar_card_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/export/export_service.dart';
import '../../domain/srs/review_queue_provider.dart';
import '../../l10n/app_localizations.dart';
import '../library/library_controller.dart';
import '../notifications/notification_texts.dart';
import '../../domain/notifications/notification_controller.dart';

/// Settings -- one sheet, grouped by headings, scrollable.
///
/// There are no "Account" or "Sign out" rows: there is no account system behind them.
class SettingsSheet extends ConsumerStatefulWidget {
  const SettingsSheet({super.key});

  static Future<void> show(BuildContext context) =>
      SheetScaffold.show(context: context, child: const SettingsSheet());

  @override
  ConsumerState<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<SettingsSheet> {
  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final settings = ref.watch(settingsRepositoryProvider);
    final themeMode = ref.watch(themeControllerProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _GroupHeader(l10n.settingsReview),
          _ValueRow(
            label: l10n.settingsDailyLimit,
            value: '${settings.dailyCap}',
            onTap: () => _pickDailyCap(settings),
          ),

          _GroupHeader(l10n.settingsNotifications),
          _ToggleRow(
            label: l10n.settingsReminders,
            value: settings.notificationsEnabled,
            onChanged: (v) => _toggleReminders(v),
          ),
          if (settings.notificationsEnabled) ...[
            _ValueRow(
              label: l10n.settingsMode,
              value: settings.notificationMode == NotificationMode.dailyTime
                  ? l10n.settingsModeDailyTime
                  : l10n.settingsModeThreshold,
              onTap: () => _pickMode(settings),
            ),
            if (settings.notificationMode == NotificationMode.dailyTime)
              _ValueRow(
                label: l10n.settingsTime,
                value: settings.notificationTime.toString(),
                onTap: () => _pickTime(settings),
              )
            else
              _ValueRow(
                label: l10n.settingsThreshold,
                value: '${settings.threshold}',
                onTap: () => _pickThreshold(settings),
              ),
            _ToggleRow(
              label: l10n.settingsShowCount,
              value: settings.showCountInNotification,
              onChanged: (v) async {
                await settings.setShowCountInNotification(v);
                await _rescheduleNotifications();
                if (mounted) setState(() {});
              },
            ),
          ],

          _GroupHeader(l10n.settingsAppearance),
          // A three-option row rather than an on/off switch: two states cannot
          // express "follow the device", which is the default and the better
          // one.
          _ValueRow(
            label: l10n.settingsDarkMode,
            value: switch (themeMode) {
              ThemeMode.system => l10n.themeSystem,
              ThemeMode.light => l10n.themeLight,
              ThemeMode.dark => l10n.themeDark,
            },
            onTap: _pickTheme,
          ),

          _GroupHeader(l10n.settingsOther),
          // Export is the trust layer itself: in an app whose data stays
          // on the device, being able to take that data away is the one
          // concrete way of saying "you are not locked in".
          _ValueRow(
            label: l10n.settingsExport,
            onTap: _exportData,
          ),
          _ValueRow(
            label: l10n.settingsPrivacy,
            onTap: () => _showInfo(l10n.settingsPrivacy, l10n.privacyBody),
          ),
          _ValueRow(
            label: l10n.settingsAbout,
            onTap: () => _showInfo(l10n.settingsAbout, l10n.aboutBody),
          ),
          _ValueRow(
            label: l10n.settingsDeleteAll,
            danger: true,
            showDivider: false,
            onTap: _confirmDeleteAll,
          ),
        ],
      ),
    );
  }

  /// Notification permission is asked for **here**, not at launch
  /// (contextual permission). The user knows exactly what it is for.
  Future<void> _toggleReminders(bool value) async {
    final texts = notificationTextsOf(L10n.of(context));
    final controller = ref.read(notificationControllerProvider);

    if (!value) {
      await controller.disable();
      if (mounted) setState(() {});
      return;
    }

    final granted = await controller.enable(texts);
    if (!mounted) return;
    setState(() {});

    // If permission was refused the switch did not turn on. Leaving it quietly
    // off would strand the user in "I turned it on but nothing arrives".
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context).notifyPermissionDenied)),
      );
    }
  }

  Future<void> _exportData() async {
    final l10n = L10n.of(context);
    final result = await ref.read(exportServiceProvider).run();
    if (!mounted) return;

    // Cancelling passes silently: if the user changed their mind there is
    // nothing worth telling them.
    final message = switch (result.outcome) {
      ExportOutcome.written => l10n.exportDone(result.cardCount),
      ExportOutcome.failed => l10n.exportFailed,
      ExportOutcome.cancelled => null,
    };
    if (message == null) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Replan whenever a setting that affects notifications changes -- otherwise
  /// the user changes the hour but the notification still arrives at the old one.
  Future<void> _rescheduleNotifications() async {
    if (!ref.read(settingsRepositoryProvider).notificationsEnabled) return;
    await ref
        .read(notificationControllerProvider)
        .reschedule(notificationTextsOf(L10n.of(context)));
  }

  // --- Pickers --------------------------------------------------------

  Future<void> _pickDailyCap(SettingsRepository settings) async {
    // This is the first setting a user coming from Anki will look for.
    // Preset options instead of free numeric input: the decision gets easier
    // and absurd values (0, 5000) are impossible from the start.
    const options = [10, 15, 25, 40, 60, 100];
    final picked = await _pickFrom<int>(
      title: L10n.of(context).settingsDailyLimit,
      options: options,
      current: settings.dailyCap,
      labelOf: (v) => '$v',
    );
    if (picked != null) {
      await settings.setDailyCap(picked);
      // The queue cap changed; the badge, the session and the notification
      // count all have to be recomputed (that count is clamped by the cap too).
      ref.invalidate(reviewQueueProvider);
      await _rescheduleNotifications();
      if (mounted) setState(() {});
    }
  }

  Future<void> _pickMode(SettingsRepository settings) async {
    final l10n = L10n.of(context);
    final picked = await _pickFrom<NotificationMode>(
      title: l10n.settingsMode,
      options: NotificationMode.values,
      current: settings.notificationMode,
      labelOf: (v) => v == NotificationMode.dailyTime
          ? l10n.settingsModeDailyTime
          : l10n.settingsModeThreshold,
    );
    if (picked != null) {
      await settings.setNotificationMode(picked);
      await _rescheduleNotifications();
      if (mounted) setState(() {});
    }
  }

  Future<void> _pickTime(SettingsRepository settings) async {
    final current = settings.notificationTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked != null) {
      await settings.setNotificationTime(DayTime(picked.hour, picked.minute));
      await _rescheduleNotifications();
      if (mounted) setState(() {});
    }
  }

  Future<void> _pickThreshold(SettingsRepository settings) async {
    const options = [20, 30, 50, 80, 120];
    final picked = await _pickFrom<int>(
      title: L10n.of(context).settingsThreshold,
      options: options,
      current: settings.threshold,
      labelOf: (v) => '$v',
    );
    if (picked != null) {
      await settings.setThreshold(picked);
      await _rescheduleNotifications();
      if (mounted) setState(() {});
    }
  }

  Future<void> _pickTheme() async {
    final l10n = L10n.of(context);
    final picked = await _pickFrom<ThemeMode>(
      title: l10n.settingsDarkMode,
      options: ThemeMode.values,
      current: ref.read(themeControllerProvider),
      labelOf: (v) => switch (v) {
        ThemeMode.system => l10n.themeSystem,
        ThemeMode.light => l10n.themeLight,
        ThemeMode.dark => l10n.themeDark,
      },
    );
    if (picked != null) {
      await ref.read(themeControllerProvider.notifier).set(picked);
    }
  }

  Future<T?> _pickFrom<T>({
    required String title,
    required List<T> options,
    required T current,
    required String Function(T) labelOf,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SheetScaffold(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _GroupHeader(title.toUpperCase()),
            for (final option in options)
              _ValueRow(
                label: labelOf(option),
                value: option == current ? '✓' : null,
                showDivider: option != options.last,
                onTap: () => Navigator.pop(context, option),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  // --- Information and deletion ---------------------------------------

  Future<void> _showInfo(String title, String body) {
    final palette = context.palette;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SheetScaffold(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: AppText.voice(size: 19, color: palette.textPrimary)),
            const SizedBox(height: AppSpacing.md),
            Text(
              body,
              style: AppText.body(
                size: 15,
                color: palette.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAll() async {
    final l10n = L10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteAllTitle),
        content: Text(l10n.deleteAllBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: RatingColors.again),
            child: Text(l10n.deleteAllConfirm),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // All three at once: cards and logs, media files on disk, and settings.
    // Deleting only the database would leave the user's photos unreachable
    // on disk.
    await ref.read(cardRepositoryProvider).deleteAll();
    await ref.read(mediaStoreProvider).deleteAll();
    await ref.read(settingsRepositoryProvider).resetAll();

    ref.invalidate(reviewQueueProvider);
    ref.invalidate(libraryCardsProvider);
    ref.invalidate(libraryStatsProvider);

    if (mounted) Navigator.pop(context);
  }
}

// --- Row components -----------------------------------------------------

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.xxl,
        bottom: AppSpacing.xs,
      ),
      child: Text(
        label,
        style: AppText.body(
          size: 11,
          weight: 600,
          color: context.palette.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.label,
    this.value,
    this.onTap,
    this.danger = false,
    this.showDivider = true,
  });

  final String label;
  final String? value;
  final VoidCallback? onTap;
  final bool danger;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 2),
        decoration: showDivider
            ? BoxDecoration(
                border: Border(bottom: BorderSide(color: palette.border)),
              )
            : null,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppText.body(
                  size: 15,
                  weight: 500,
                  color: danger ? RatingColors.again : palette.textPrimary,
                ),
              ),
            ),
            if (value != null)
              Text(
                value!,
                style: AppText.body(size: 15, color: palette.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppText.body(
                size: 15,
                weight: 500,
                color: palette.textPrimary,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: AppPalette.accent,
          ),
        ],
      ),
    );
  }
}
