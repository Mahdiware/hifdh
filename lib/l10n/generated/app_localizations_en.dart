// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Hifdh';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get plans => 'Plans';

  @override
  String get history => 'History';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get systemTheme => 'System Theme';

  @override
  String get lightTheme => 'Light Theme';

  @override
  String get darkTheme => 'Dark Theme';

  @override
  String get backupRestore => 'Backup & Restore';

  @override
  String get createBackup => 'Create Backup';

  @override
  String get restoreBackup => 'Restore Backup';

  @override
  String get resetData => 'Reset Data';

  @override
  String get resetDataConfirmation => 'Reset All Data?';

  @override
  String get resetDataWarning =>
      'This will delete all your tasks, notes, and progress history. This action cannot be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get resetEverything => 'Reset Everything';

  @override
  String get dataResetSuccess => 'All data has been reset.';

  @override
  String get backupCreated => 'Backup created successfully';

  @override
  String get backupRestored => 'Backup restored successfully';

  @override
  String get quizSetup => 'Quiz Setup';

  @override
  String get progress => 'Progress';

  @override
  String get quiz => 'Quiz';

  @override
  String get activeTasks => 'Active Tasks';

  @override
  String get noActiveTasks => 'No active tasks.';

  @override
  String get pending => 'Pending';

  @override
  String get inProgress => 'In Progress';

  @override
  String get unknown => 'Unknown';

  @override
  String get start => 'Start';

  @override
  String get complete => 'Complete';

  @override
  String get done => 'Done';

  @override
  String get memorize => 'Memorize';

  @override
  String get revision => 'Revision';

  @override
  String get notes => 'Notes';

  @override
  String get createNewPlan => 'Create New Plan';

  @override
  String get targetDate => 'Target Date';

  @override
  String get selectDate => 'Select Date';

  @override
  String get surah => 'Surah';

  @override
  String get juz => 'Juz';

  @override
  String get page => 'Page';

  @override
  String get startAyah => 'Start Ayah';

  @override
  String get endAyah => 'End Ayah';

  @override
  String get startPage => 'Start Page';

  @override
  String get endPage => 'End Page';

  @override
  String get assignTask => 'Assign Task';

  @override
  String get pleaseSelectSurah => 'Please select a Surah';

  @override
  String get pleaseSelectJuz => 'Please select a Juz';

  @override
  String get pleaseSelectPageRange => 'Please enter valid page range';

  @override
  String get selectSearchAyah => 'Select/Search Ayah...';

  @override
  String get unknownAyah => 'Unknown Ayah';

  @override
  String get descriptionOptional => 'Description (Optional)...';

  @override
  String get pleaseSelectAyah => 'Please select an Ayah';

  @override
  String get noNotesYet => 'No notes yet';

  @override
  String get note => 'Note';

  @override
  String get doubt => 'Doubt';

  @override
  String get mistake => 'Mistake';

  @override
  String get searchHistory => 'Search History...';

  @override
  String get sortNewest => 'Newest First';

  @override
  String get sortOldest => 'Oldest First';

  @override
  String get noHistory => 'No history available';

  @override
  String get overview => 'Overview';

  @override
  String get stats => 'Stats';

  @override
  String get memorized => 'Memorized';

  @override
  String get remaining => 'Remaining';

  @override
  String get memorizeTasksFirst => 'Memorize Tasks First';

  @override
  String get revisionTasksFirst => 'Revision Tasks First';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get noNotesRecorded => 'No notes recorded';

  @override
  String get selectSurah => 'Select Surah';

  @override
  String get selectJuz => 'Select Juz';

  @override
  String get subdivision => 'Subdivision';

  @override
  String get fullJuz => 'Full Juz';

  @override
  String get hizb => 'Hizb';

  @override
  String get wholeJuz => 'Whole Juz';

  @override
  String get nisfHizb => 'Nisf Hizb';

  @override
  String get rubuc => 'Rubuc';

  @override
  String get selectDeadline => 'Select Deadline';

  @override
  String get createPlan => 'Create Plan';

  @override
  String get planCreatedSuccess => 'Plan Created Successfully!';

  @override
  String get pleaseSelectDeadline => 'Please select a deadline';

  @override
  String startAyahErrorRange(int max) {
    return 'Start Ayah must be between 1 and $max';
  }

  @override
  String endAyahErrorRange(int max) {
    return 'End Ayah must be between 1 and $max';
  }

  @override
  String get startAyahErrorOrder => 'Start Ayah cannot be after End Ayah';

  @override
  String get pleaseEnterValidPages => 'Please enter valid pages';

  @override
  String get contentMemorizedSwitch =>
      'Content is already memorized. Switched to Revision.';

  @override
  String get contentNotMemorizedSwitch =>
      'Content is not yet memorized. Switched to Memorize.';

  @override
  String get noSurahsLoaded => 'No Surahs loaded';

  @override
  String get revisionsShort => 'Revs';

  @override
  String get viewJuzHistoryNotes => 'View Juz History & Notes';

  @override
  String get surahTask => 'Surah Task';

  @override
  String get juzTask => 'Juz Task';

  @override
  String get activeTaskSingle => 'Active Task';

  @override
  String get coveredByJuz => 'Covered by Juz';

  @override
  String percentMemorized(int pct) {
    return '$pct% Memorized';
  }

  @override
  String get activity => 'Activity';

  @override
  String get hifdhPerformance => 'Hifdh Performance';

  @override
  String get days7 => '7 Days';

  @override
  String get days30 => '30 Days';

  @override
  String get months3 => '3 Months';

  @override
  String get months6 => '6 Months';

  @override
  String get year1 => '1 Year';

  @override
  String get noActivityPeriod => 'No activity in this period';

  @override
  String get completed => 'Completed';

  @override
  String get progressAndNotes => 'Progress & Notes';

  @override
  String get notesHistory => 'Notes History';

  @override
  String get close => 'Close';

  @override
  String get noNotesRecordedYet => 'No notes recorded yet';

  @override
  String get noAyahFound => 'No ayah found matching criteria';

  @override
  String get didYouGetItRight => 'Did you get it right?';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get questionAnsweredError => 'No questions answered yet!';

  @override
  String get finishQuiz => 'Finish Quiz';

  @override
  String get question => 'Question';

  @override
  String get completeVersePrompt => 'Complete the Verse';

  @override
  String get showAnswer => 'Show Answer';

  @override
  String get nextQuestion => 'Next Question';

  @override
  String get quizResults => 'Quiz Results';

  @override
  String get score => 'Score';

  @override
  String get correct => 'Correct';

  @override
  String get wrong => 'Wrong';

  @override
  String get detailedReview => 'Detailed Review';

  @override
  String questionsCount(int count) {
    return '$count Questions';
  }

  @override
  String get home => 'Home';

  @override
  String get ayah => 'Ayah';

  @override
  String get selectSurahs => 'Select Surahs';

  @override
  String get searchSurah => 'Search Surah...';

  @override
  String get confirm => 'Confirm';

  @override
  String get selectTypeMessage =>
      'Please select Type \'Page Range\' or \'Surah Selection\'';

  @override
  String get selectSurahMessage => 'Please select at least one Surah';

  @override
  String get enterPagesMessage => 'Please enter both start and end pages';

  @override
  String get invalidNumberFormat => 'Invalid number format';

  @override
  String get invalidPageRange => 'Invalid page range (1-604)';

  @override
  String get pageRangeTitle => 'Page Range';

  @override
  String get fromPageLabel => 'From Page';

  @override
  String get toPageLabel => 'To Page';

  @override
  String get surahSelectionTitle => 'Surah Selection';

  @override
  String get selectSurahsButton => 'Select Surahs';

  @override
  String get startQuizButton => 'Start Quiz';

  @override
  String get backupToFile => 'Backup to a file';

  @override
  String backupFailed(Object error) {
    return 'Backup failed: $error';
  }

  @override
  String get restoreFromFile => 'Restore from a file';

  @override
  String restoreFailed(Object error) {
    return 'Restore failed: $error';
  }

  @override
  String get clearAllData => 'Clear all tasks and progress';

  @override
  String get generalNote => 'General Note';

  @override
  String get completedOn => 'Completed On';

  @override
  String get taskType => 'Task Type';
}
