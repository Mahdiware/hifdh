class AyahSearchQuery {
  final int? surahNumber;
  final int? ayahNumber;

  AyahSearchQuery({this.surahNumber, this.ayahNumber});

  // Parses "2:200", "2", "200"
  static AyahSearchQuery? parse(String query) {
    if (query.isEmpty) return null;
    query = query.trim();

    // Case 1: "2:200" or "2 200"
    if (query.contains(':') || query.contains(' ')) {
      final parts = query.split(RegExp(r'[: ]+'));
      if (parts.length >= 2) {
        final rSurah = int.tryParse(parts[0]);
        final rAyah = int.tryParse(parts[1]);
        if (rSurah != null && rAyah != null) {
          return AyahSearchQuery(surahNumber: rSurah, ayahNumber: rAyah);
        }
      }
    }

    // Case 2: Single number "2"
    final val = int.tryParse(query);
    if (val != null) {
      return AyahSearchQuery(surahNumber: val);
    }
    return null;
  }

  bool isSpecificAyah() => surahNumber != null && ayahNumber != null;
}
