import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_so.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('so'),
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'Hifdh'**
  String get appTitle;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @plans.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get plans;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @systemTheme.
  ///
  /// In en, this message translates to:
  /// **'System Theme'**
  String get systemTheme;

  /// No description provided for @lightTheme.
  ///
  /// In en, this message translates to:
  /// **'Light Theme'**
  String get lightTheme;

  /// No description provided for @darkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark Theme'**
  String get darkTheme;

  /// No description provided for @backupRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get backupRestore;

  /// No description provided for @createBackup.
  ///
  /// In en, this message translates to:
  /// **'Create Backup'**
  String get createBackup;

  /// No description provided for @restoreBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore Backup'**
  String get restoreBackup;

  /// No description provided for @resetData.
  ///
  /// In en, this message translates to:
  /// **'Reset Data'**
  String get resetData;

  /// No description provided for @resetDataConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Reset All Data?'**
  String get resetDataConfirmation;

  /// No description provided for @resetDataWarning.
  ///
  /// In en, this message translates to:
  /// **'This will delete all your tasks, notes, and progress history. This action cannot be undone.'**
  String get resetDataWarning;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @resetEverything.
  ///
  /// In en, this message translates to:
  /// **'Reset Everything'**
  String get resetEverything;

  /// No description provided for @dataResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'All data has been reset.'**
  String get dataResetSuccess;

  /// No description provided for @backupCreated.
  ///
  /// In en, this message translates to:
  /// **'Backup created successfully'**
  String get backupCreated;

  /// No description provided for @backupRestored.
  ///
  /// In en, this message translates to:
  /// **'Backup restored successfully'**
  String get backupRestored;

  /// No description provided for @quizSetup.
  ///
  /// In en, this message translates to:
  /// **'Quiz Setup'**
  String get quizSetup;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// No description provided for @quiz.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get quiz;

  /// No description provided for @activeTasks.
  ///
  /// In en, this message translates to:
  /// **'Active Tasks'**
  String get activeTasks;

  /// No description provided for @noActiveTasks.
  ///
  /// In en, this message translates to:
  /// **'No active tasks.'**
  String get noActiveTasks;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @inProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get inProgress;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @complete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get complete;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @memorize.
  ///
  /// In en, this message translates to:
  /// **'Memorize'**
  String get memorize;

  /// No description provided for @revision.
  ///
  /// In en, this message translates to:
  /// **'Revision'**
  String get revision;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @createNewPlan.
  ///
  /// In en, this message translates to:
  /// **'Create New Plan'**
  String get createNewPlan;

  /// No description provided for @targetDate.
  ///
  /// In en, this message translates to:
  /// **'Target Date'**
  String get targetDate;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get selectDate;

  /// No description provided for @surah.
  ///
  /// In en, this message translates to:
  /// **'Surah'**
  String get surah;

  /// No description provided for @juz.
  ///
  /// In en, this message translates to:
  /// **'Juz'**
  String get juz;

  /// No description provided for @page.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get page;

  /// No description provided for @startAyah.
  ///
  /// In en, this message translates to:
  /// **'Start Ayah'**
  String get startAyah;

  /// No description provided for @endAyah.
  ///
  /// In en, this message translates to:
  /// **'End Ayah'**
  String get endAyah;

  /// No description provided for @startPage.
  ///
  /// In en, this message translates to:
  /// **'Start Page'**
  String get startPage;

  /// No description provided for @endPage.
  ///
  /// In en, this message translates to:
  /// **'End Page'**
  String get endPage;

  /// No description provided for @assignTask.
  ///
  /// In en, this message translates to:
  /// **'Assign Task'**
  String get assignTask;

  /// No description provided for @pleaseSelectSurah.
  ///
  /// In en, this message translates to:
  /// **'Please select a Surah'**
  String get pleaseSelectSurah;

  /// No description provided for @pleaseSelectJuz.
  ///
  /// In en, this message translates to:
  /// **'Please select a Juz'**
  String get pleaseSelectJuz;

  /// No description provided for @pleaseSelectPageRange.
  ///
  /// In en, this message translates to:
  /// **'Please enter valid page range'**
  String get pleaseSelectPageRange;

  /// No description provided for @selectSearchAyah.
  ///
  /// In en, this message translates to:
  /// **'Select/Search Ayah...'**
  String get selectSearchAyah;

  /// No description provided for @unknownAyah.
  ///
  /// In en, this message translates to:
  /// **'Unknown Ayah'**
  String get unknownAyah;

  /// No description provided for @descriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (Optional)...'**
  String get descriptionOptional;

  /// No description provided for @pleaseSelectAyah.
  ///
  /// In en, this message translates to:
  /// **'Please select an Ayah'**
  String get pleaseSelectAyah;

  /// No description provided for @noNotesYet.
  ///
  /// In en, this message translates to:
  /// **'No notes yet'**
  String get noNotesYet;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @doubt.
  ///
  /// In en, this message translates to:
  /// **'Doubt'**
  String get doubt;

  /// No description provided for @mistake.
  ///
  /// In en, this message translates to:
  /// **'Mistake'**
  String get mistake;

  /// No description provided for @searchHistory.
  ///
  /// In en, this message translates to:
  /// **'Search History...'**
  String get searchHistory;

  /// No description provided for @sortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest First'**
  String get sortNewest;

  /// No description provided for @sortOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest First'**
  String get sortOldest;

  /// No description provided for @noHistory.
  ///
  /// In en, this message translates to:
  /// **'No history available'**
  String get noHistory;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @stats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get stats;

  /// No description provided for @memorized.
  ///
  /// In en, this message translates to:
  /// **'Memorized'**
  String get memorized;

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remaining;

  /// No description provided for @memorizeTasksFirst.
  ///
  /// In en, this message translates to:
  /// **'Memorize Tasks First'**
  String get memorizeTasksFirst;

  /// No description provided for @revisionTasksFirst.
  ///
  /// In en, this message translates to:
  /// **'Revision Tasks First'**
  String get revisionTasksFirst;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @noNotesRecorded.
  ///
  /// In en, this message translates to:
  /// **'No notes recorded'**
  String get noNotesRecorded;

  /// No description provided for @selectSurah.
  ///
  /// In en, this message translates to:
  /// **'Select Surah'**
  String get selectSurah;

  /// No description provided for @selectJuz.
  ///
  /// In en, this message translates to:
  /// **'Select Juz'**
  String get selectJuz;

  /// No description provided for @subdivision.
  ///
  /// In en, this message translates to:
  /// **'Subdivision'**
  String get subdivision;

  /// No description provided for @fullJuz.
  ///
  /// In en, this message translates to:
  /// **'Full Juz'**
  String get fullJuz;

  /// No description provided for @hizb.
  ///
  /// In en, this message translates to:
  /// **'Hizb'**
  String get hizb;

  /// No description provided for @wholeJuz.
  ///
  /// In en, this message translates to:
  /// **'Whole Juz'**
  String get wholeJuz;

  /// No description provided for @nisfHizb.
  ///
  /// In en, this message translates to:
  /// **'Nisf Hizb'**
  String get nisfHizb;

  /// No description provided for @rubuc.
  ///
  /// In en, this message translates to:
  /// **'Rubuc'**
  String get rubuc;

  /// No description provided for @selectDeadline.
  ///
  /// In en, this message translates to:
  /// **'Select Deadline'**
  String get selectDeadline;

  /// No description provided for @createPlan.
  ///
  /// In en, this message translates to:
  /// **'Create Plan'**
  String get createPlan;

  /// No description provided for @planCreatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Plan Created Successfully!'**
  String get planCreatedSuccess;

  /// No description provided for @pleaseSelectDeadline.
  ///
  /// In en, this message translates to:
  /// **'Please select a deadline'**
  String get pleaseSelectDeadline;

  /// No description provided for @startAyahErrorRange.
  ///
  /// In en, this message translates to:
  /// **'Start Ayah must be between 1 and {max}'**
  String startAyahErrorRange(int max);

  /// No description provided for @endAyahErrorRange.
  ///
  /// In en, this message translates to:
  /// **'End Ayah must be between 1 and {max}'**
  String endAyahErrorRange(int max);

  /// No description provided for @startAyahErrorOrder.
  ///
  /// In en, this message translates to:
  /// **'Start Ayah cannot be after End Ayah'**
  String get startAyahErrorOrder;

  /// No description provided for @pleaseEnterValidPages.
  ///
  /// In en, this message translates to:
  /// **'Please enter valid pages'**
  String get pleaseEnterValidPages;

  /// No description provided for @contentMemorizedSwitch.
  ///
  /// In en, this message translates to:
  /// **'Content is already memorized. Switched to Revision.'**
  String get contentMemorizedSwitch;

  /// No description provided for @contentNotMemorizedSwitch.
  ///
  /// In en, this message translates to:
  /// **'Content is not yet memorized. Switched to Memorize.'**
  String get contentNotMemorizedSwitch;

  /// No description provided for @noSurahsLoaded.
  ///
  /// In en, this message translates to:
  /// **'No Surahs loaded'**
  String get noSurahsLoaded;

  /// No description provided for @revisionsShort.
  ///
  /// In en, this message translates to:
  /// **'Revs'**
  String get revisionsShort;

  /// No description provided for @viewJuzHistoryNotes.
  ///
  /// In en, this message translates to:
  /// **'View Juz History & Notes'**
  String get viewJuzHistoryNotes;

  /// No description provided for @surahTask.
  ///
  /// In en, this message translates to:
  /// **'Surah Task'**
  String get surahTask;

  /// No description provided for @juzTask.
  ///
  /// In en, this message translates to:
  /// **'Juz Task'**
  String get juzTask;

  /// No description provided for @activeTaskSingle.
  ///
  /// In en, this message translates to:
  /// **'Active Task'**
  String get activeTaskSingle;

  /// No description provided for @coveredByJuz.
  ///
  /// In en, this message translates to:
  /// **'Covered by Juz'**
  String get coveredByJuz;

  /// No description provided for @percentMemorized.
  ///
  /// In en, this message translates to:
  /// **'{pct}% Memorized'**
  String percentMemorized(int pct);

  /// No description provided for @activity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity;

  /// No description provided for @hifdhPerformance.
  ///
  /// In en, this message translates to:
  /// **'Hifdh Performance'**
  String get hifdhPerformance;

  /// No description provided for @days7.
  ///
  /// In en, this message translates to:
  /// **'7 Days'**
  String get days7;

  /// No description provided for @days30.
  ///
  /// In en, this message translates to:
  /// **'30 Days'**
  String get days30;

  /// No description provided for @months3.
  ///
  /// In en, this message translates to:
  /// **'3 Months'**
  String get months3;

  /// No description provided for @months6.
  ///
  /// In en, this message translates to:
  /// **'6 Months'**
  String get months6;

  /// No description provided for @year1.
  ///
  /// In en, this message translates to:
  /// **'1 Year'**
  String get year1;

  /// No description provided for @noActivityPeriod.
  ///
  /// In en, this message translates to:
  /// **'No activity in this period'**
  String get noActivityPeriod;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @progressAndNotes.
  ///
  /// In en, this message translates to:
  /// **'Progress & Notes'**
  String get progressAndNotes;

  /// No description provided for @notesHistory.
  ///
  /// In en, this message translates to:
  /// **'Notes History'**
  String get notesHistory;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @noNotesRecordedYet.
  ///
  /// In en, this message translates to:
  /// **'No notes recorded yet'**
  String get noNotesRecordedYet;

  /// No description provided for @noAyahFound.
  ///
  /// In en, this message translates to:
  /// **'No ayah found matching criteria'**
  String get noAyahFound;

  /// No description provided for @didYouGetItRight.
  ///
  /// In en, this message translates to:
  /// **'Did you get it right?'**
  String get didYouGetItRight;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @questionAnsweredError.
  ///
  /// In en, this message translates to:
  /// **'No questions answered yet!'**
  String get questionAnsweredError;

  /// No description provided for @finishQuiz.
  ///
  /// In en, this message translates to:
  /// **'Finish Quiz'**
  String get finishQuiz;

  /// No description provided for @question.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get question;

  /// No description provided for @completeVersePrompt.
  ///
  /// In en, this message translates to:
  /// **'Complete the Verse'**
  String get completeVersePrompt;

  /// No description provided for @showAnswer.
  ///
  /// In en, this message translates to:
  /// **'Show Answer'**
  String get showAnswer;

  /// No description provided for @nextQuestion.
  ///
  /// In en, this message translates to:
  /// **'Next Question'**
  String get nextQuestion;

  /// No description provided for @quizResults.
  ///
  /// In en, this message translates to:
  /// **'Quiz Results'**
  String get quizResults;

  /// No description provided for @score.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get score;

  /// No description provided for @correct.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get correct;

  /// No description provided for @wrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong'**
  String get wrong;

  /// No description provided for @detailedReview.
  ///
  /// In en, this message translates to:
  /// **'Detailed Review'**
  String get detailedReview;

  /// No description provided for @questionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Questions'**
  String questionsCount(int count);

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @ayah.
  ///
  /// In en, this message translates to:
  /// **'Ayah'**
  String get ayah;

  /// No description provided for @selectSurahs.
  ///
  /// In en, this message translates to:
  /// **'Select Surahs'**
  String get selectSurahs;

  /// No description provided for @searchSurah.
  ///
  /// In en, this message translates to:
  /// **'Search Surah...'**
  String get searchSurah;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @selectTypeMessage.
  ///
  /// In en, this message translates to:
  /// **'Please select Type \'Page Range\' or \'Surah Selection\''**
  String get selectTypeMessage;

  /// No description provided for @selectSurahMessage.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one Surah'**
  String get selectSurahMessage;

  /// No description provided for @enterPagesMessage.
  ///
  /// In en, this message translates to:
  /// **'Please enter both start and end pages'**
  String get enterPagesMessage;

  /// No description provided for @invalidNumberFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid number format'**
  String get invalidNumberFormat;

  /// No description provided for @invalidPageRange.
  ///
  /// In en, this message translates to:
  /// **'Invalid page range (1-604)'**
  String get invalidPageRange;

  /// No description provided for @pageRangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Page Range'**
  String get pageRangeTitle;

  /// No description provided for @fromPageLabel.
  ///
  /// In en, this message translates to:
  /// **'From Page'**
  String get fromPageLabel;

  /// No description provided for @toPageLabel.
  ///
  /// In en, this message translates to:
  /// **'To Page'**
  String get toPageLabel;

  /// No description provided for @surahSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Surah Selection'**
  String get surahSelectionTitle;

  /// No description provided for @selectSurahsButton.
  ///
  /// In en, this message translates to:
  /// **'Select Surahs'**
  String get selectSurahsButton;

  /// No description provided for @startQuizButton.
  ///
  /// In en, this message translates to:
  /// **'Start Quiz'**
  String get startQuizButton;

  /// No description provided for @backupToFile.
  ///
  /// In en, this message translates to:
  /// **'Backup to a file'**
  String get backupToFile;

  /// No description provided for @backupFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup failed: {error}'**
  String backupFailed(Object error);

  /// No description provided for @restoreFromFile.
  ///
  /// In en, this message translates to:
  /// **'Restore from a file'**
  String get restoreFromFile;

  /// No description provided for @restoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed: {error}'**
  String restoreFailed(Object error);

  /// No description provided for @clearAllData.
  ///
  /// In en, this message translates to:
  /// **'Clear all tasks and progress'**
  String get clearAllData;

  /// No description provided for @generalNote.
  ///
  /// In en, this message translates to:
  /// **'General Note'**
  String get generalNote;

  /// No description provided for @completedOn.
  ///
  /// In en, this message translates to:
  /// **'Completed On'**
  String get completedOn;

  /// No description provided for @taskType.
  ///
  /// In en, this message translates to:
  /// **'Task Type'**
  String get taskType;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'so'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'so':
      return AppLocalizationsSo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
