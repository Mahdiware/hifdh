// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'الحفظ';

  @override
  String get dashboard => 'لوحة القيادة';

  @override
  String get plans => 'الخطط';

  @override
  String get history => 'السجل';

  @override
  String get settings => 'الإعدادات';

  @override
  String get language => 'اللغة';

  @override
  String get theme => 'المظهر';

  @override
  String get systemTheme => 'مظهر النظام';

  @override
  String get lightTheme => 'فاتح';

  @override
  String get darkTheme => 'داكن';

  @override
  String get backupRestore => 'النسخ الاحتياطي والاستعادة';

  @override
  String get createBackup => 'إنشاء نسخة احتياطية';

  @override
  String get restoreBackup => 'استعادة نسخة احتياطية';

  @override
  String get resetData => 'إعادة تعيين البيانات';

  @override
  String get resetDataConfirmation => 'إعادة تعيين جميع البيانات؟';

  @override
  String get resetDataWarning =>
      'سيؤدي هذا إلى حذف جميع مهامك وملاحظاتك وسجل التقدم. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get cancel => 'إلغاء';

  @override
  String get resetEverything => 'مسح كل شيء';

  @override
  String get dataResetSuccess => 'تمت إعادة تعيين جميع البيانات.';

  @override
  String get backupCreated => 'تم إنشاء النسخة الاحتياطية بنجاح';

  @override
  String get backupRestored => 'تم استعادة النسخة الاحتياطية بنجاح';

  @override
  String get quizSetup => 'إعداد الاختبار';

  @override
  String get progress => 'التقدم';

  @override
  String get quiz => 'اختبار';

  @override
  String get activeTasks => 'المهام النشطة';

  @override
  String get noActiveTasks => 'لا توجد مهام نشطة.';

  @override
  String get pending => 'قيد الانتظار';

  @override
  String get inProgress => 'جاري التنفيذ';

  @override
  String get unknown => 'غير معروف';

  @override
  String get start => 'بدء';

  @override
  String get complete => 'إكمال';

  @override
  String get done => 'تم';

  @override
  String get memorize => 'حفظ';

  @override
  String get revision => 'مراجعة';

  @override
  String get notes => 'ملاحظات';

  @override
  String get createNewPlan => 'إنشاء خطة جديدة';

  @override
  String get targetDate => 'تاريخ الهدف';

  @override
  String get selectDate => 'اختر التاريخ';

  @override
  String get surah => 'سورة';

  @override
  String get juz => 'جزء';

  @override
  String get page => 'صفحة';

  @override
  String get startAyah => 'آية البداية';

  @override
  String get endAyah => 'آية النهاية';

  @override
  String get startPage => 'صفحة البداية';

  @override
  String get endPage => 'صفحة النهاية';

  @override
  String get assignTask => 'تعيين المهمة';

  @override
  String get pleaseSelectSurah => 'يرجى اختيار سورة';

  @override
  String get pleaseSelectJuz => 'يرجى اختيار جزء';

  @override
  String get pleaseSelectPageRange => 'يرجى إدخال نطاق صفحات صالح';

  @override
  String get selectSearchAyah => 'اختر/ابحث عن آية...';

  @override
  String get unknownAyah => 'آية غير معروفة';

  @override
  String get descriptionOptional => 'الوصف (اختياري)...';

  @override
  String get pleaseSelectAyah => 'يرجى اختيار آية';

  @override
  String get noNotesYet => 'لا توجد ملاحظات بعد';

  @override
  String get note => 'ملاحظة';

  @override
  String get doubt => 'شك';

  @override
  String get mistake => 'خطأ';

  @override
  String get searchHistory => 'بحث في السجل...';

  @override
  String get sortNewest => 'الأحدث أولاً';

  @override
  String get sortOldest => 'الأقدم أولاً';

  @override
  String get noHistory => 'لا يوجد سجل متاح';

  @override
  String get overview => 'نظرة عامة';

  @override
  String get stats => 'إحصائيات';

  @override
  String get memorized => 'تم الحفظ';

  @override
  String get remaining => 'متبقي';

  @override
  String get memorizeTasksFirst => 'مهام الحفظ أولاً';

  @override
  String get revisionTasksFirst => 'مهام المراجعة أولاً';

  @override
  String get today => 'اليوم';

  @override
  String get yesterday => 'أمس';

  @override
  String get noNotesRecorded => 'لا توجد ملاحظات مسجلة';

  @override
  String get selectSurah => 'اختر السورة';

  @override
  String get selectJuz => 'اختر الجزء';

  @override
  String get subdivision => 'التقسيم الفرعي';

  @override
  String get fullJuz => 'جزء كامل';

  @override
  String get hizb => 'حزب';

  @override
  String get wholeJuz => 'جزء كامل';

  @override
  String get nisfHizb => 'نصف حزب';

  @override
  String get rubuc => 'ربع';

  @override
  String get selectDeadline => 'حدد الموعد النهائي';

  @override
  String get createPlan => 'إنشاء خطة';

  @override
  String get planCreatedSuccess => 'تم إنشاء الخطة بنجاح!';

  @override
  String get pleaseSelectDeadline => 'يرجى تحديد موعد نهائي';

  @override
  String startAyahErrorRange(int max) {
    return 'يجب أن تكون آية البداية بين 1 و $max';
  }

  @override
  String endAyahErrorRange(int max) {
    return 'يجب أن تكون آية النهاية بين 1 و $max';
  }

  @override
  String get startAyahErrorOrder =>
      'لا يمكن أن تكون آية البداية بعد آية النهاية';

  @override
  String get pleaseEnterValidPages => 'يرجى إدخال صفحات صالحة';

  @override
  String get contentMemorizedSwitch =>
      'المحتوى محفوظ بالفعل. تم التبديل إلى المراجعة.';

  @override
  String get contentNotMemorizedSwitch =>
      'المحتوى غير محفوظ بعد. تم التبديل إلى الحفظ.';

  @override
  String get noSurahsLoaded => 'لم يتم تحميل السور';

  @override
  String get revisionsShort => 'مراجعات';

  @override
  String get viewJuzHistoryNotes => 'عرض سجل وملاحظات الجزء';

  @override
  String get surahTask => 'مهمة سورة';

  @override
  String get juzTask => 'مهمة جزء';

  @override
  String get activeTaskSingle => 'مهمة نشطة';

  @override
  String get coveredByJuz => 'مغطى بواسطة الجزء';

  @override
  String percentMemorized(int pct) {
    return '$pct% تم الحفظ';
  }

  @override
  String get activity => 'النشاط';

  @override
  String get hifdhPerformance => 'أداء الحفظ';

  @override
  String get days7 => '7 أيام';

  @override
  String get days30 => '30 يوماً';

  @override
  String get months3 => '3 أشهر';

  @override
  String get months6 => '6 أشهر';

  @override
  String get year1 => 'سنة واحدة';

  @override
  String get noActivityPeriod => 'لا يوجد نشاط في هذه الفترة';

  @override
  String get completed => 'مكتمل';

  @override
  String get progressAndNotes => 'السجل والملاحظات';

  @override
  String get notesHistory => 'سجل الملاحظات';

  @override
  String get close => 'إغلاق';

  @override
  String get noNotesRecordedYet => 'لم يتم تسجيل أي ملاحظات بعد';

  @override
  String get noAyahFound => 'لم يتم العثور على آية مطابقة';

  @override
  String get didYouGetItRight => 'هل أجبت بشكل صحيح؟';

  @override
  String get yes => 'نعم';

  @override
  String get no => 'لا';

  @override
  String get questionAnsweredError => 'لم يتم الإجابة على أي سؤال!';

  @override
  String get finishQuiz => 'إنهاء الاختبار';

  @override
  String get question => 'السؤال';

  @override
  String get completeVersePrompt => 'أكمل قوله تعالى';

  @override
  String get showAnswer => 'إظهار الإجابة';

  @override
  String get nextQuestion => 'السؤال التالي';

  @override
  String get quizResults => 'نتائج الاختبار';

  @override
  String get score => 'النتيجة';

  @override
  String get correct => 'صحيح';

  @override
  String get wrong => 'خطأ';

  @override
  String get detailedReview => 'مراجعة تفصيلية';

  @override
  String questionsCount(int count) {
    return '$count أسئلة';
  }

  @override
  String get home => 'الرئيسية';

  @override
  String get ayah => 'آية';

  @override
  String get selectSurahs => 'اختر السور';

  @override
  String get searchSurah => 'ابحث عن سورة...';

  @override
  String get confirm => 'تأكيد';

  @override
  String get selectTypeMessage =>
      'يرجى اختيار النوع \'نطاق الصفحات\' أو \'اختيار السور\'';

  @override
  String get selectSurahMessage => 'يرجى اختيار سورة واحدة على الأقل';

  @override
  String get enterPagesMessage => 'يرجى إدخال صفحتي البداية والنهاية';

  @override
  String get invalidNumberFormat => 'صيغة الرقم غير صحيحة';

  @override
  String get invalidPageRange => 'نطاق الصفحات غير صحيح (1-604)';

  @override
  String get pageRangeTitle => 'نطاق الصفحات';

  @override
  String get fromPageLabel => 'من صفحة';

  @override
  String get toPageLabel => 'إلى صفحة';

  @override
  String get surahSelectionTitle => 'اختيار السور';

  @override
  String get selectSurahsButton => 'اختر السور';

  @override
  String get startQuizButton => 'بدء الاختبار';

  @override
  String get backupToFile => 'النسخ الاحتياطي إلى ملف';

  @override
  String backupFailed(Object error) {
    return 'فشل النسخ الاحتياطي: $error';
  }

  @override
  String get restoreFromFile => 'استعادة من ملف';

  @override
  String restoreFailed(Object error) {
    return 'فشل الاستعادة: $error';
  }

  @override
  String get clearAllData => 'مسح جميع المهام والتقدم';

  @override
  String get generalNote => 'ملاحظة عامة';

  @override
  String get completedOn => 'أكملت في';

  @override
  String get taskType => 'نوع المهمة';
}
