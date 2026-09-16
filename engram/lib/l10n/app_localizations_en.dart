// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class L10nEn extends L10n {
  L10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Engram';

  @override
  String get modeCamera => 'Camera';

  @override
  String get modeText => 'Text';

  @override
  String get modeImport => 'Import';

  @override
  String get modeAudio => 'Audio';

  @override
  String get navAdd => 'Add';

  @override
  String get navReview => 'Review';

  @override
  String navReviewWithCount(int count) {
    return 'Review · $count';
  }

  @override
  String get textPrompt => 'What do you want to remember?';

  @override
  String get addAnswer => 'Add answer';

  @override
  String get addNote => 'Add note';

  @override
  String get optional => 'optional';

  @override
  String get answerHint => 'You can add the answer too';

  @override
  String get noteHint => 'A short note';

  @override
  String get save => 'Save';

  @override
  String get saveFailed => 'That didn\'t save. Give it another try?';

  @override
  String get reviewTapToReveal => 'Tap to see the answer';

  @override
  String get reviewTapToRemember => 'Do you remember?';

  @override
  String get reviewListenThenReveal => 'Listen, then tap to see the answer';

  @override
  String get reviewLookThenReveal => 'What was in this? Tap to remember';

  @override
  String get ratingAgain => 'No idea';

  @override
  String get ratingHard => 'Barely';

  @override
  String get ratingGood => 'Almost';

  @override
  String get ratingEasy => 'Got it';

  @override
  String get reviewDoneTitle => 'That\'s it for today';

  @override
  String get reviewDoneSubtitle => 'Nothing else is due';

  @override
  String get reviewDoneAction => 'Back to capturing';

  @override
  String get reviewEmptyTitle => 'Nothing to review right now';

  @override
  String get reviewEmptySubtitle =>
      'Capture something and it\'ll show up here.';

  @override
  String get reviewEmptyAction => 'Start capturing';

  @override
  String get libraryTitle => 'Your cards';

  @override
  String get libraryEmptyTitle => 'No cards yet';

  @override
  String get libraryEmptySubtitle => 'Your first capture will show up here.';

  @override
  String get libraryStatTotal => 'total cards';

  @override
  String get libraryStatAccuracy => 'accuracy';

  @override
  String get libraryStatKnown => 'known';

  @override
  String get cardDetailQuestion => 'QUESTION';

  @override
  String get cardStatAccuracy => 'Accuracy';

  @override
  String get cardStatReviews => 'Reviews';

  @override
  String get cardStatLastSeen => 'Last seen';

  @override
  String get cardStatNextReview => 'Next review';

  @override
  String get sortNewest => 'Newest';

  @override
  String get sortWeakest => 'Weakest';

  @override
  String get sortNextReview => 'Next review';

  @override
  String get librarySearchHint => 'Search your cards';

  @override
  String get filterNoMatch => 'Nothing matches this filter';

  @override
  String get clearFilters => 'Show all cards';

  @override
  String get neverReviewed => 'Not yet';

  @override
  String get dueNow => 'Ready now';

  @override
  String get cancel => 'Cancel';

  @override
  String get deleteAllTitle => 'Delete everything?';

  @override
  String get deleteAllBody =>
      'This removes every card, every review and your settings from this device. It can\'t be undone.';

  @override
  String get deleteAllConfirm => 'Delete everything';

  @override
  String get privacyBody =>
      'Engram keeps everything on this device. There\'s no account, no server, no analytics. Nothing you capture leaves your phone.';

  @override
  String get aboutBody =>
      'Engram — capture anything in seconds, remember it for good.';

  @override
  String get levelNew => 'New';

  @override
  String get levelWeak => 'Weak';

  @override
  String get levelLearning => 'Learning';

  @override
  String get levelKnown => 'Known';

  @override
  String get cropSelectArea => 'Select area';

  @override
  String get cropHintArea => 'Drag to select, or keep the whole thing';

  @override
  String get cropContinue => 'Continue';

  @override
  String get importRecent => 'RECENT PHOTOS AND VIDEOS';

  @override
  String get importNoPhotos => 'Nothing here yet';

  @override
  String get recordHint => 'Hold to record';

  @override
  String get recordReleaseHint => 'Let go when you\'re done';

  @override
  String get recordTooShort =>
      'That was too short — hold the button while you talk';

  @override
  String get importPickPdf => 'or pick a PDF';

  @override
  String pdfPageOf(int page, int count) {
    return 'Page $page of $count';
  }

  @override
  String get pdfOpenFailed => 'That PDF wouldn\'t open. Try another one?';

  @override
  String get permAllow => 'Allow';

  @override
  String get permCameraDenied =>
      'Camera access isn\'t enabled. You can turn it on in your phone settings.';

  @override
  String get permMicDenied =>
      'Microphone access isn\'t enabled. You can turn it on in your phone settings.';

  @override
  String get permPhotosBody =>
      'Let Engram see your photos to turn them into cards.';

  @override
  String get permPhotosDenied =>
      'Photo access isn\'t enabled. You can turn it on in your phone settings.';

  @override
  String get settingsReview => 'REVIEW';

  @override
  String get settingsDailyLimit => 'Daily limit';

  @override
  String get settingsNotifications => 'NOTIFICATIONS';

  @override
  String get settingsReminders => 'Reminders';

  @override
  String get settingsMode => 'Mode';

  @override
  String get settingsModeDailyTime => 'Daily time';

  @override
  String get settingsModeThreshold => 'When cards pile up';

  @override
  String get settingsTime => 'Time';

  @override
  String get settingsThreshold => 'Threshold';

  @override
  String get settingsShowCount => 'Show card count';

  @override
  String get settingsAppearance => 'APPEARANCE';

  @override
  String get settingsDarkMode => 'Dark mode';

  @override
  String get themeSystem => 'Match device';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsOther => 'OTHER';

  @override
  String get settingsExport => 'Export data';

  @override
  String exportDone(int count) {
    return 'Saved $count cards to that folder, media included';
  }

  @override
  String get exportFailed =>
      'The export didn\'t finish. Maybe try a different folder?';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsDeleteAll => 'Delete all data';

  @override
  String get settingsAbout => 'About';

  @override
  String get dailyLimitHintTitle => 'There\'s more waiting';

  @override
  String get dailyLimitHintBody =>
      'Engram keeps each day short on purpose. You can raise the daily limit in settings whenever you like.';

  @override
  String notifyDailyWithCount(int count) {
    return '$count cards are waiting for you';
  }

  @override
  String get notifyDailyNoCount => 'A few cards are waiting for you';

  @override
  String get notifyPileUp => 'Your cards have been stacking up';

  @override
  String get notifyPermissionDenied =>
      'Reminders need notification permission. You can turn it on in your phone settings.';

  @override
  String get notifyComeBack => 'Your cards are still here whenever you are';
}
