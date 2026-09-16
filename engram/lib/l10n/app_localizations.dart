import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L10n
/// returned by `L10n.of(context)`.
///
/// Applications need to include `L10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L10n.localizationsDelegates,
///   supportedLocales: L10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L10n.supportedLocales
/// property.
abstract class L10n {
  L10n(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n)!;
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// Application name. Not translated.
  ///
  /// In en, this message translates to:
  /// **'Engram'**
  String get appTitle;

  /// Capture mode chips at the top of the Add screen.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get modeCamera;

  /// No description provided for @modeText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get modeText;

  /// No description provided for @modeImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get modeImport;

  /// No description provided for @modeAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get modeAudio;

  /// No description provided for @navAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get navAdd;

  /// No description provided for @navReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get navReview;

  /// Switcher pill label. count is ALWAYS the capped daily suggestion, never the raw overdue total.
  ///
  /// In en, this message translates to:
  /// **'Review · {count}'**
  String navReviewWithCount(int count);

  /// Large serif placeholder on the Text capture screen. Warm, direct, second person.
  ///
  /// In en, this message translates to:
  /// **'What do you want to remember?'**
  String get textPrompt;

  /// No description provided for @addAnswer.
  ///
  /// In en, this message translates to:
  /// **'Add answer'**
  String get addAnswer;

  /// No description provided for @addNote.
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get addNote;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'optional'**
  String get optional;

  /// No description provided for @answerHint.
  ///
  /// In en, this message translates to:
  /// **'You can add the answer too'**
  String get answerHint;

  /// No description provided for @noteHint.
  ///
  /// In en, this message translates to:
  /// **'A short note'**
  String get noteHint;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Shown when writing a captured card fails (disk full, file gone). Warm, never blaming the user.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t save. Give it another try?'**
  String get saveFailed;

  /// No description provided for @reviewTapToReveal.
  ///
  /// In en, this message translates to:
  /// **'Tap to see the answer'**
  String get reviewTapToReveal;

  /// Shown instead of tapToReveal when the card has no answer.
  ///
  /// In en, this message translates to:
  /// **'Do you remember?'**
  String get reviewTapToRemember;

  /// No description provided for @reviewListenThenReveal.
  ///
  /// In en, this message translates to:
  /// **'Listen, then tap to see the answer'**
  String get reviewListenThenReveal;

  /// No description provided for @reviewLookThenReveal.
  ///
  /// In en, this message translates to:
  /// **'What was in this? Tap to remember'**
  String get reviewLookThenReveal;

  /// Maps to FSRS Again/Hard/Good/Easy. Short enough for four side-by-side buttons on a 375px screen. Never blaming.
  ///
  /// In en, this message translates to:
  /// **'No idea'**
  String get ratingAgain;

  /// No description provided for @ratingHard.
  ///
  /// In en, this message translates to:
  /// **'Barely'**
  String get ratingHard;

  /// No description provided for @ratingGood.
  ///
  /// In en, this message translates to:
  /// **'Almost'**
  String get ratingGood;

  /// No description provided for @ratingEasy.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get ratingEasy;

  /// No description provided for @reviewDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'That\'s it for today'**
  String get reviewDoneTitle;

  /// No description provided for @reviewDoneSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing else is due'**
  String get reviewDoneSubtitle;

  /// No description provided for @reviewDoneAction.
  ///
  /// In en, this message translates to:
  /// **'Back to capturing'**
  String get reviewDoneAction;

  /// No description provided for @reviewEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing to review right now'**
  String get reviewEmptyTitle;

  /// No description provided for @reviewEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Capture something and it\'ll show up here.'**
  String get reviewEmptySubtitle;

  /// No description provided for @reviewEmptyAction.
  ///
  /// In en, this message translates to:
  /// **'Start capturing'**
  String get reviewEmptyAction;

  /// No description provided for @libraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Your cards'**
  String get libraryTitle;

  /// No description provided for @libraryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No cards yet'**
  String get libraryEmptyTitle;

  /// No description provided for @libraryEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your first capture will show up here.'**
  String get libraryEmptySubtitle;

  /// No description provided for @libraryStatTotal.
  ///
  /// In en, this message translates to:
  /// **'total cards'**
  String get libraryStatTotal;

  /// No description provided for @libraryStatAccuracy.
  ///
  /// In en, this message translates to:
  /// **'accuracy'**
  String get libraryStatAccuracy;

  /// No description provided for @libraryStatKnown.
  ///
  /// In en, this message translates to:
  /// **'known'**
  String get libraryStatKnown;

  /// No description provided for @cardDetailQuestion.
  ///
  /// In en, this message translates to:
  /// **'QUESTION'**
  String get cardDetailQuestion;

  /// No description provided for @cardStatAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get cardStatAccuracy;

  /// No description provided for @cardStatReviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get cardStatReviews;

  /// No description provided for @cardStatLastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen'**
  String get cardStatLastSeen;

  /// No description provided for @cardStatNextReview.
  ///
  /// In en, this message translates to:
  /// **'Next review'**
  String get cardStatNextReview;

  /// No description provided for @sortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get sortNewest;

  /// No description provided for @sortWeakest.
  ///
  /// In en, this message translates to:
  /// **'Weakest'**
  String get sortWeakest;

  /// No description provided for @sortNextReview.
  ///
  /// In en, this message translates to:
  /// **'Next review'**
  String get sortNextReview;

  /// Library search field. Searches the question, the answer and the PDF source label; works alongside the filters.
  ///
  /// In en, this message translates to:
  /// **'Search your cards'**
  String get librarySearchHint;

  /// No description provided for @filterNoMatch.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches this filter'**
  String get filterNoMatch;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Show all cards'**
  String get clearFilters;

  /// Card detail: shown instead of a date when the card has never been reviewed, or when it is already due.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get neverReviewed;

  /// No description provided for @dueNow.
  ///
  /// In en, this message translates to:
  /// **'Ready now'**
  String get dueNow;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Confirmation before wiping all data. Plain and factual — no guilt, no drama.
  ///
  /// In en, this message translates to:
  /// **'Delete everything?'**
  String get deleteAllTitle;

  /// No description provided for @deleteAllBody.
  ///
  /// In en, this message translates to:
  /// **'This removes every card, every review and your settings from this device. It can\'t be undone.'**
  String get deleteAllBody;

  /// No description provided for @deleteAllConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete everything'**
  String get deleteAllConfirm;

  /// No description provided for @privacyBody.
  ///
  /// In en, this message translates to:
  /// **'Engram keeps everything on this device. There\'s no account, no server, no analytics. Nothing you capture leaves your phone.'**
  String get privacyBody;

  /// No description provided for @aboutBody.
  ///
  /// In en, this message translates to:
  /// **'Engram — capture anything in seconds, remember it for good.'**
  String get aboutBody;

  /// No description provided for @levelNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get levelNew;

  /// No description provided for @levelWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get levelWeak;

  /// No description provided for @levelLearning.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get levelLearning;

  /// No description provided for @levelKnown.
  ///
  /// In en, this message translates to:
  /// **'Known'**
  String get levelKnown;

  /// No description provided for @cropSelectArea.
  ///
  /// In en, this message translates to:
  /// **'Select area'**
  String get cropSelectArea;

  /// No description provided for @cropHintArea.
  ///
  /// In en, this message translates to:
  /// **'Drag to select, or keep the whole thing'**
  String get cropHintArea;

  /// No description provided for @cropContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get cropContinue;

  /// Drawer label on the Import panel. Video items carry a play badge.
  ///
  /// In en, this message translates to:
  /// **'RECENT PHOTOS AND VIDEOS'**
  String get importRecent;

  /// No description provided for @importNoPhotos.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get importNoPhotos;

  /// No description provided for @recordHint.
  ///
  /// In en, this message translates to:
  /// **'Hold to record'**
  String get recordHint;

  /// No description provided for @recordReleaseHint.
  ///
  /// In en, this message translates to:
  /// **'Let go when you\'re done'**
  String get recordReleaseHint;

  /// Shown when a hold-to-record gesture is released almost immediately. Explains the gesture instead of blaming the user.
  ///
  /// In en, this message translates to:
  /// **'That was too short — hold the button while you talk'**
  String get recordTooShort;

  /// No description provided for @importPickPdf.
  ///
  /// In en, this message translates to:
  /// **'or pick a PDF'**
  String get importPickPdf;

  /// No description provided for @pdfPageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {count}'**
  String pdfPageOf(int page, int count);

  /// No description provided for @pdfOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'That PDF wouldn\'t open. Try another one?'**
  String get pdfOpenFailed;

  /// No description provided for @permAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get permAllow;

  /// No description provided for @permCameraDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera access isn\'t enabled. You can turn it on in your phone settings.'**
  String get permCameraDenied;

  /// No description provided for @permMicDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone access isn\'t enabled. You can turn it on in your phone settings.'**
  String get permMicDenied;

  /// Shown before the system dialog, in the Import drawer. The camera and microphone have no equivalent: there the shutter itself is the ask.
  ///
  /// In en, this message translates to:
  /// **'Let Engram see your photos to turn them into cards.'**
  String get permPhotosBody;

  /// Shown after the system dialog was declined — it won't appear a second time, so the text has to point at settings.
  ///
  /// In en, this message translates to:
  /// **'Photo access isn\'t enabled. You can turn it on in your phone settings.'**
  String get permPhotosDenied;

  /// No description provided for @settingsReview.
  ///
  /// In en, this message translates to:
  /// **'REVIEW'**
  String get settingsReview;

  /// No description provided for @settingsDailyLimit.
  ///
  /// In en, this message translates to:
  /// **'Daily limit'**
  String get settingsDailyLimit;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'NOTIFICATIONS'**
  String get settingsNotifications;

  /// No description provided for @settingsReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get settingsReminders;

  /// No description provided for @settingsMode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get settingsMode;

  /// No description provided for @settingsModeDailyTime.
  ///
  /// In en, this message translates to:
  /// **'Daily time'**
  String get settingsModeDailyTime;

  /// No description provided for @settingsModeThreshold.
  ///
  /// In en, this message translates to:
  /// **'When cards pile up'**
  String get settingsModeThreshold;

  /// No description provided for @settingsTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get settingsTime;

  /// No description provided for @settingsThreshold.
  ///
  /// In en, this message translates to:
  /// **'Threshold'**
  String get settingsThreshold;

  /// No description provided for @settingsShowCount.
  ///
  /// In en, this message translates to:
  /// **'Show card count'**
  String get settingsShowCount;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'APPEARANCE'**
  String get settingsAppearance;

  /// No description provided for @settingsDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get settingsDarkMode;

  /// Appearance options. 'Match device' is the default — the app follows the system setting rather than forcing a look.
  ///
  /// In en, this message translates to:
  /// **'Match device'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @settingsOther.
  ///
  /// In en, this message translates to:
  /// **'OTHER'**
  String get settingsOther;

  /// No description provided for @settingsExport.
  ///
  /// In en, this message translates to:
  /// **'Export data'**
  String get settingsExport;

  /// Confirmation after a manual export. States what left the app so the user can trust the backup.
  ///
  /// In en, this message translates to:
  /// **'Saved {count} cards to that folder, media included'**
  String exportDone(int count);

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'The export didn\'t finish. Maybe try a different folder?'**
  String get exportFailed;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacy;

  /// No description provided for @settingsDeleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete all data'**
  String get settingsDeleteAll;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// One-time hint shown the first time the user hits the daily cap. Must never imply falling behind.
  ///
  /// In en, this message translates to:
  /// **'There\'s more waiting'**
  String get dailyLimitHintTitle;

  /// No description provided for @dailyLimitHintBody.
  ///
  /// In en, this message translates to:
  /// **'Engram keeps each day short on purpose. You can raise the daily limit in settings whenever you like.'**
  String get dailyLimitHintBody;

  /// count is the capped daily suggestion, never the raw overdue total.
  ///
  /// In en, this message translates to:
  /// **'{count} cards are waiting for you'**
  String notifyDailyWithCount(int count);

  /// No description provided for @notifyDailyNoCount.
  ///
  /// In en, this message translates to:
  /// **'A few cards are waiting for you'**
  String get notifyDailyNoCount;

  /// No description provided for @notifyPileUp.
  ///
  /// In en, this message translates to:
  /// **'Your cards have been stacking up'**
  String get notifyPileUp;

  /// No description provided for @notifyPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Reminders need notification permission. You can turn it on in your phone settings.'**
  String get notifyPermissionDenied;

  /// Softer tone, sent once after several days away. Warm, never guilt-inducing.
  ///
  /// In en, this message translates to:
  /// **'Your cards are still here whenever you are'**
  String get notifyComeBack;
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  Future<L10n> load(Locale locale) {
    return SynchronousFuture<L10n>(lookupL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

L10n lookupL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return L10nEn();
  }

  throw FlutterError(
      'L10n.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
