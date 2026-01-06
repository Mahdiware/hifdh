class QuizSettings {
  final int? startPage;
  final int? endPage;
  final List<int>? surahNumbers;
  final int? juz;

  const QuizSettings({
    this.startPage,
    this.endPage,
    this.surahNumbers,
    this.juz,
  });

  bool get isPageRange => startPage != null && endPage != null;
  bool get isSurahRange => surahNumbers != null && surahNumbers!.isNotEmpty;
  bool get isJuz => juz != null;
}
