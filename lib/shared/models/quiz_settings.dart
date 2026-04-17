class QuizSettings {
  final int? startPage;
  final int? endPage;
  final List<int>? surahNumbers;
  final int? juz;
  final int? startJuz;
  final int? endJuz;

  const QuizSettings({
    this.startPage,
    this.endPage,
    this.surahNumbers,
    this.juz,
    this.startJuz,
    this.endJuz,
  });

  bool get isPageRange => startPage != null && endPage != null;
  bool get isSurahRange => surahNumbers != null && surahNumbers!.isNotEmpty;
  bool get isJuzRange => startJuz != null && endJuz != null;
  bool get isJuz => juz != null || isJuzRange;
}
