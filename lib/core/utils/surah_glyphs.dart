class SurahGlyphs {
  static final List<String> list = List.generate(114, (index) {
    final surahNumber = index + 1;
    // The font encodes Surah 1 as 0x4001, Surah 10 as 0x4010, Surah 100 as 0x4100.
    // This means the decimal digits of the Surah number are treated as Hex digits.
    final offset = int.parse(surahNumber.toString(), radix: 16);
    return "${String.fromCharCode(0x4000 + offset)}\u4000";
  });
}
