import 'package:flutter/material.dart';
import 'package:hifdh/core/theme/app_colors.dart';
import 'package:hifdh/core/utils/ayah_search_query.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';
import 'package:hifdh/shared/widgets/liquid_glass.dart';

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
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: LiquidGlass(
          padding: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(24),
          blur: 20,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1A2B47), const Color(0xFF14233B)]
                : [const Color(0xFFEFF5FF), const Color(0xFFDCEAFF)],
          ),
          tint: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.72),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF264B84), const Color(0xFF1F3965)]
                        : [
                            const Color(0xFFBFD7FF).withValues(alpha: 0.7),
                            const Color(0xFFA9C6F5).withValues(alpha: 0.56),
                          ],
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.travel_explore_rounded,
                      color: isDark ? Colors.white : AppColors.primaryNavy,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.selectSearchAyah,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.primaryNavy,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark ? Colors.white : AppColors.primaryNavy,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: LiquidGlass(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  borderRadius: BorderRadius.circular(14),
                  blur: 10,
                  tint: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.78),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.16)
                        : AppColors.primaryNavy.withValues(alpha: 0.12),
                  ),
                  boxShadow: const [],
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.searchAyahExamplesHint,
                      hintStyle: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.55)
                            : AppColors.textSecondaryLight,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.75)
                            : AppColors.primaryNavy,
                      ),
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 420,
                child: _listItems.isEmpty
                    ? Center(
                        child: Text(
                          l10n.noMatches,
                          style: TextStyle(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.72)
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _listItems.length,
                        padding: const EdgeInsets.only(bottom: 10),
                        itemBuilder: (context, index) {
                          final item = _listItems[index];
                          if (item['type'] == 'header') {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 9,
                              ),
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : AppColors.primaryNavy.withValues(
                                      alpha: 0.06,
                                    ),
                              child: Row(
                                children: [
                                  Text(
                                    isArabic
                                        ? item['titleAr']
                                        : item['titleEn'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.primaryNavy,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '(${l10n.ayahs} ${item['subtitle']})',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white70
                                          : AppColors.textSecondaryLight,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            final row = item['data'] as Map<String, dynamic>;
                            final surahTitle =
                                ((isArabic
                                        ? row['surahArabicName']
                                        : row['surahEnglishName'])
                                    as String?) ??
                                'Surah ${row['surahNumber']}';

                            return Column(
                              children: [
                                ListTile(
                                  dense: true,
                                  leading: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : AppColors.primaryNavy.withValues(
                                              alpha: 0.08,
                                            ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      "${row['surahNumber']}:${row['ayahNumber']}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : AppColors.primaryNavy,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    surahTitle,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                  subtitle: Text(
                                    row['text'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'QuranFont',
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.78)
                                          : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                  trailing: Icon(
                                    Icons.chevron_right_rounded,
                                    color: isDark
                                        ? Colors.white70
                                        : AppColors.primaryNavy,
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
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : AppColors.dividerLight,
                                ),
                              ],
                            );
                          }
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
