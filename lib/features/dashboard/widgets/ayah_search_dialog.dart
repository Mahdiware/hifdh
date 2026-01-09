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
  List<Map<String, dynamic>> _filteredAyahs = [];

  @override
  void initState() {
    super.initState();
    _filteredAyahs = widget.ayahs;
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filter() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _filteredAyahs = widget.ayahs);
      return;
    }

    final search = AyahSearchQuery.parse(query);

    setState(() {
      _filteredAyahs = widget.ayahs.where((row) {
        final surah = row['surahNumber'] as int;
        final ayah = row['ayahNumber'] as int;

        // 1. AyahSearchQuery Logic (e.g. 2:200)
        if (search != null) {
          if (search.isSpecificAyah()) {
            return surah == search.surahNumber && ayah == search.ayahNumber;
          }
          if (search.surahNumber != null && search.ayahNumber == null) {
            // If searched "2", matches all ayahs in Surah 2
            if (surah == search.surahNumber) return true;
          }
        }

        // 2. Text Search
        final text = (row['text'] as String).toLowerCase();
        final q = query.toLowerCase();
        return text.contains(q) ||
            "$surah:$ayah".contains(q) ||
            "$ayah".contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Theme aware
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            height: 300,
            child: _filteredAyahs.isEmpty
                ? Center(
                    child: Text(
                      "No matches",
                      style: TextStyle(
                        color: isDark ? Colors.grey : Colors.black54,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _filteredAyahs.length,
                    separatorBuilder: (c, i) => Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: isDark ? Colors.white10 : Colors.grey[200],
                    ),
                    itemBuilder: (context, index) {
                      final row = _filteredAyahs[index];
                      return ListTile(
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
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        onTap: () {
                          widget.onSelected(row['id'] as int);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
