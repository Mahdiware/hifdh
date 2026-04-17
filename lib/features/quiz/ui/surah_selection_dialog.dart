import 'package:flutter/material.dart';
import 'package:hifdh/shared/models/surah.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';

class SurahSelectionDialog extends StatefulWidget {
  final List<Surah> initialSelectedSurahs;
  final List<Surah> availableSurahs;
  final bool isSingleSelection;

  const SurahSelectionDialog({
    super.key,
    required this.initialSelectedSurahs,
    required this.availableSurahs,
    this.isSingleSelection = false,
  });

  @override
  State<SurahSelectionDialog> createState() => _SurahSelectionDialogState();
}

class _SurahSelectionDialogState extends State<SurahSelectionDialog> {
  late List<Surah> _selectedSurahs;
  late List<Surah> _filteredSurahs;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedSurahs = List.from(widget.initialSelectedSurahs);
    _filteredSurahs = widget.availableSurahs;
    _searchController.addListener(_filterSurahs);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterSurahs() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredSurahs = widget.availableSurahs;
      } else {
        _filteredSurahs = widget.availableSurahs.where((surah) {
          return surah.name.contains(query) ||
              surah.englishName.toLowerCase().contains(query) ||
              surah.number.toString().contains(query);
        }).toList();
      }
    });
  }

  void _toggleSurah(Surah surah) {
    setState(() {
      if (widget.isSingleSelection) {
        _selectedSurahs = [surah];
      } else {
        if (_selectedSurahs.contains(surah)) {
          _selectedSurahs.remove(surah);
        } else {
          _selectedSurahs.add(surah);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF355E9E), const Color(0xFF274A86)]
                    : [const Color(0xFF90BCFF), const Color(0xFF5B90E6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.menu_book_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.selectSurahs,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (!widget.isSingleSelection)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_selectedSurahs.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.searchSurah,
                prefixIcon: Icon(
                  Icons.search,
                  color: colorScheme.onSurfaceVariant,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.55,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredSurahs.length,
              itemBuilder: (context, index) {
                final surah = _filteredSurahs[index];
                final isSelected = _selectedSurahs.contains(surah);
                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: CheckboxListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    title: Text(
                      surah.glyph,
                      style: const TextStyle(
                        fontFamily: 'SurahFont',
                        fontSize: 24,
                      ),
                    ),
                    subtitle: Text(
                      "${surah.number}. ${Localizations.localeOf(context).languageCode == 'ar' ? surah.name : surah.englishName}",
                    ),
                    value: isSelected,
                    activeColor: colorScheme.primary,
                    checkColor: Colors.white,
                    onChanged: (bool? value) {
                      _toggleSurah(surah);
                    },
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppLocalizations.of(context)!.cancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, _selectedSurahs),
                  child: Text(AppLocalizations.of(context)!.confirm),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
