import '../../data/models/memory_card.dart';
import '../../data/models/review_log.dart';
import '../../data/repositories/settings_repository.dart';

/// The **pure** representation of exported data.
///
/// Independent of the file system and of plugins: all that lives here is the
/// answer to "which field goes into the file". That lets a unit test guard the
/// completeness of the backup -- add a field to the schema and forget this
/// place, and the test fails. If a backup silently loses data, the user finds
/// out only while restoring it, which is the worst possible moment.
abstract final class ExportBundle {
  /// Format version. If a field is renamed later, the importing side has to
  /// know which version it is talking to.
  static const int formatVersion = 1;

  static Map<String, Object?> build({
    required List<MemoryCard> cards,
    required List<ReviewLog> logs,
    required SettingsRepository settings,
    required DateTime exportedAt,
  }) {
    return {
      'formatVersion': formatVersion,
      'app': 'engram',
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'settings': settingsToJson(settings),
      'cards': cards.map(cardToJson).toList(),
      'reviewLogs': logs.map(logToJson).toList(),
    };
  }

  /// **Every** field of the card. Media paths stay relative so that they match
  /// the `media/` folder in the backup exactly.
  static Map<String, Object?> cardToJson(MemoryCard card) => {
        'id': card.id,
        'type': card.type.name,
        'prompt': card.prompt,
        'answer': card.answer,
        'mediaPath': card.mediaPath,
        'thumbnailPath': card.thumbnailPath,
        'mediaDurationMs': card.mediaDurationMs,
        'mediaStartMs': card.mediaStartMs,
        'mediaEndMs': card.mediaEndMs,
        'sourceLabel': card.sourceLabel,
        'createdAt': card.createdAt.toUtc().toIso8601String(),
        'fsrsState': card.fsrsState.name,
        'step': card.step,
        'stability': card.stability,
        'difficulty': card.difficulty,
        'dueAt': card.dueAt.toUtc().toIso8601String(),
        'lastReviewedAt': card.lastReviewedAt?.toUtc().toIso8601String(),
        'reps': card.reps,
        'lapses': card.lapses,
      };

  static Map<String, Object?> logToJson(ReviewLog log) => {
        'id': log.id,
        'cardId': log.cardId,
        'rating': log.rating.name,
        'reviewedAt': log.reviewedAt.toUtc().toIso8601String(),
        'elapsedDays': log.elapsedDays,
        'scheduledDays': log.scheduledDays,
      };

  static Map<String, Object?> settingsToJson(SettingsRepository s) => {
        'dailyCap': s.dailyCap,
        'notificationsEnabled': s.notificationsEnabled,
        'notificationMode': s.notificationMode.name,
        'notificationTime': s.notificationTime.toString(),
        'showCountInNotification': s.showCountInNotification,
        'threshold': s.threshold,
      };

  /// The field lists the test stands guard over.
  ///
  /// Deliberately not derived from the model: a hand-written list is what makes
  /// **the test fail** when a field is added to the schema. Derived
  /// automatically, the test would stay green and the gap would go unnoticed.
  static const Set<String> cardFields = {
    'id',
    'type',
    'prompt',
    'answer',
    'mediaPath',
    'thumbnailPath',
    'mediaDurationMs',
    'mediaStartMs',
    'mediaEndMs',
    'sourceLabel',
    'createdAt',
    'fsrsState',
    'step',
    'stability',
    'difficulty',
    'dueAt',
    'lastReviewedAt',
    'reps',
    'lapses',
  };

  static const Set<String> logFields = {
    'id',
    'cardId',
    'rating',
    'reviewedAt',
    'elapsedDays',
    'scheduledDays',
  };

  static const Set<String> settingsFields = {
    'dailyCap',
    'notificationsEnabled',
    'notificationMode',
    'notificationTime',
    'showCountInNotification',
    'threshold',
  };
}
