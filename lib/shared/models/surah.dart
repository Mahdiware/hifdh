import 'package:hifdh/core/utils/surah_glyphs.dart';

class Surah {
  final int number;
  final String name;
  final String englishName;

  const Surah({
    required this.number,
    required this.name,
    required this.englishName,
  });

  String get glyph {
    if (number >= 1 && number <= 114) {
      return SurahGlyphs.list[number - 1];
    }
    return "";
  }

  factory Surah.fromMap(Map<String, dynamic> map) {
    return Surah(
      number: map['surahNumber'] as int,
      name: map['surahArabicName'] as String,
      englishName: map['surahName'] as String,
    );
  }
}
