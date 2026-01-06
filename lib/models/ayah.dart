class Ayah {
  final String text;
  final int surahNumber;
  final int ayahNumber;
  final String? surahName;

  Ayah({
    required this.text,
    required this.surahNumber,
    required this.ayahNumber,
    this.surahName,
  });

  factory Ayah.fromMap(Map<String, dynamic> map) {
    return Ayah(
      text: map['text'] as String,
      surahNumber: map['surahNumber'] as int,
      ayahNumber: map['ayahNumber'] as int,
      surahName: map['surahArabicName'] as String?,
    );
  }

  @override
  String toString() {
    return 'Ayah(surah: $surahNumber, ayah: $ayahNumber, text: $text)';
  }
}
