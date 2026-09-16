import '../../domain/notifications/notification_plan.dart';
import '../../l10n/app_localizations.dart';

/// The bridge from `L10n` to the plain text carrier the planner understands.
///
/// The planner deliberately does not depend on `L10n`: staying pure Dart keeps
/// it testable, and no logic will change when another language file is added
/// later.
NotificationTexts notificationTextsOf(L10n l10n) => NotificationTexts(
      title: l10n.appTitle,
      dailyWithCount: l10n.notifyDailyWithCount,
      dailyNoCount: l10n.notifyDailyNoCount,
      pileUp: l10n.notifyPileUp,
      comeBack: l10n.notifyComeBack,
    );
