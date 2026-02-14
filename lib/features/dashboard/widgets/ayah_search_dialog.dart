import 'package:flutter/material.dart';
import 'package:hifdh/core/theme/app_colors.dart';
import 'package:hifdh/core/utils/ayah_search_query.dart';

class AyahSearchDialog extends StatefulWidget {
  final List<Map<String, dynamic>> ayahs;
  final Function(int) onSelected;

  const AyahSearchDialog({
    super.key,
    required this.ayahs,
    required this.onSelected,
  });

  @override
  State<AyahSearchDialog> createState() => _AyahSearchDialogState();
}

class _AyahSearchDialogState extends State<AyahSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _listItems = [];

  @override
  void initState() {
    super.initState();
    _filter(); // Initial population
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filter() {
    final query = _searchController.text.trim();
    List<Map<String, dynamic>> results;

    if (query.isEmpty) {
      results = widget.ayahs;
    } else {
      final search = AyahSearchQuery.parse(query);
      results = widget.ayahs.where((row) {
        final surah = row['surahNumber'] as int;
        final ayah = row['ayahNumber'] as int;

        if (search != null) {
          if (search.isSpecificAyah()) {
            return surah == search.surahNumber && ayah == search.ayahNumber;
          }
          if (search.surahNumber != null && search.ayahNumber == null) {
            if (surah == search.surahNumber) return true;
          }
        }

        final text = (row['text'] as String).toLowerCase();
        final q = query.toLowerCase();
        return text.contains(q) ||
            "$surah:$ayah".contains(q) ||
            "$ayah".contains(q);
      }).toList();
    }

    // Grouping Logic
    _listItems = [];
    if (results.isEmpty) {
      setState(() {});
      return;
    }

    Map<int, List<Map<String, dynamic>>> groups = {};
    for (var row in results) {
      final s = row['surahNumber'] as int;
      if (!groups.containsKey(s)) {
        groups[s] = [];
      }
      groups[s]!.add(row);
    }

    // Flatten groups
    groups.forEach((surahNum, ayahs) {
      final first = ayahs.first;
      final start = first['ayahNumber'];
      final end = ayahs.last['ayahNumber']; // Assuming sorted
      final nameEn = first['surahEnglishName'] ?? 'Surah $surahNum';
      final nameAr = first['surahArabicName'] ?? '';

      _listItems.add({
        'type': 'header',
        'surahNumber': surahNum,
        'titleEn': nameEn,
        'titleAr': nameAr,
        'subtitle': "$start - $end",
        'count': ayahs.length,
      });

      _listItems.addAll(ayahs.map((a) => {'type': 'ayah', 'data': a}));
    });

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Theme aware
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Dialog(
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: "Search (e.g. 2:200, 2 200, content)...",
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey : Colors.grey[600],
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white12 : Colors.grey[300]!,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          SizedBox(
            height: 400, // Increased height for better view
            child: _listItems.isEmpty
                ? Center(
                    child: Text(
                      "No matches",
                      style: TextStyle(
                        color: isDark ? Colors.grey : Colors.black54,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _listItems.length,
                    itemBuilder: (context, index) {
                      final item = _listItems[index];
                      if (item['type'] == 'header') {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          color: isDark
                              ? Colors.grey.withValues(alpha: 0.1)
                              : Colors.grey[100],
                          child: Row(
                            children: [
                              Text(
                                isArabic ? item['titleAr'] : item['titleEn'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "(${isArabic ? 'الآيات' : 'Ayahs'} ${item['subtitle']})",
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey
                                      : Colors.grey[700],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      } else {
                        final row = item['data'] as Map<String, dynamic>;
                        return Column(
                          children: [
                            ListTile(
                              dense: true,
                              title: Text(
                                "${row['surahNumber']}:${row['ayahNumber']}",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              subtitle: Text(
                                row['text'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'QuranFont',
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),
                              onTap: () {
                                widget.onSelected(row['id'] as int);
                                Navigator.pop(context);
                              },
                            ),
                            Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                              color: isDark ? Colors.white10 : Colors.grey[200],
                            ),
                          ],
                        );
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
