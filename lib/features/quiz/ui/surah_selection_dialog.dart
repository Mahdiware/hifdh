import 'package:flutter/material.dart';
import 'package:hifdh/shared/models/surah.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';
import 'package:hifdh/shared/widgets/liquid_glass.dart';

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

  Widget _buildFooterButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool isPrimary,
    required bool isDark,
  }) {
    final accent = isPrimary
        ? (isDark ? const Color(0xFF93BBEA) : const Color(0xFF1A4B87))
        : (isDark ? Colors.white : const Color(0xFF2C4C70));

    return LiquidGlass(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(12),
      blur: 10,
      tint: isPrimary
          ? (isDark
                ? const Color(0xFF395E8A).withValues(alpha: 0.56)
                : const Color(0xFFDCEBFF).withValues(alpha: 0.9))
          : (isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.7)),
      border: Border.all(
        color: isPrimary
            ? accent.withValues(alpha: 0.34)
            : (isDark ? Colors.white12 : Colors.black12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: accent),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.w700, color: accent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSurahRow(
    BuildContext context,
    Surah surah,
    bool isSelected,
    bool isDark,
  ) {
    final locale = Localizations.localeOf(context).languageCode;
    final displayName = locale == 'ar' ? surah.name : surah.englishName;

    return LiquidGlass(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(14),
      blur: 10,
      tint: isSelected
          ? (isDark
                ? const Color(0xFF3F618A).withValues(alpha: 0.42)
                : const Color(0xFFDCEBFF).withValues(alpha: 0.84))
          : (isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.56)),
      border: Border.all(
        color: isSelected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
            : (isDark ? Colors.white10 : Colors.black12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleSurah(surah),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : (isDark ? Colors.white54 : Colors.black38),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 10),
                Text(
                  surah.glyph,
                  style: const TextStyle(fontFamily: 'SurahFont', fontSize: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${surah.number}. $displayName',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1B446F),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: LiquidGlass(
          padding: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(24),
          blur: 20,
          tint: isDark
              ? Colors.white.withValues(alpha: 0.09)
              : Colors.white.withValues(alpha: 0.64),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
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
                        l10n.selectSurahs,
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
                child: LiquidGlass(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  borderRadius: BorderRadius.circular(14),
                  blur: 12,
                  tint: isDark
                      ? colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.2,
                        )
                      : colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.45,
                        ),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: l10n.searchSurah,
                      prefixIcon: Icon(
                        Icons.search,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      border: InputBorder.none,
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
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: _buildSurahRow(context, surah, isSelected, isDark),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildFooterButton(
                        label: l10n.cancel,
                        icon: Icons.close_rounded,
                        onTap: () => Navigator.pop(context),
                        isPrimary: false,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFooterButton(
                        label: l10n.confirm,
                        icon: Icons.check_rounded,
                        onTap: () => Navigator.pop(context, _selectedSurahs),
                        isPrimary: true,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
