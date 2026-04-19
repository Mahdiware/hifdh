import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hifdh/core/services/quran_database.dart';
import 'package:hifdh/core/theme/app_background.dart';
import 'package:hifdh/features/quiz/ui/quiz_home_page.dart';
import 'package:hifdh/features/quiz/ui/surah_selection_dialog.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';
import 'package:hifdh/shared/models/quiz_settings.dart';
import 'package:hifdh/shared/models/surah.dart';
import 'package:hifdh/shared/widgets/liquid_glass.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum QuizSelectionType { pageRange, juzRange, surahSelection }

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  static const String _prefQuizMode = 'quiz_selected_mode';
  static const String _prefPageStart = 'quiz_page_start';
  static const String _prefPageEnd = 'quiz_page_end';
  static const String _prefJuzStart = 'quiz_juz_start';
  static const String _prefJuzEnd = 'quiz_juz_end';
  static const String _prefSurahNumbers = 'quiz_surah_numbers';

  QuizSelectionType _selectedType = QuizSelectionType.pageRange;
  List<Surah> _selectedSurahs = [];
  List<Surah> _allSurahs = [];
  List<int> _storedSurahNumbers = [];

  int _juzStart = 1;
  int _juzEnd = 30;

  final TextEditingController _fromPageController = TextEditingController();
  final TextEditingController _toPageController = TextEditingController();
  bool _didUserSwitchMode = false;
  SharedPreferences? _prefs;
  Timer? _pagePrefsDebounce;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadSurahs();
    _primePrefs();
  }

  @override
  void dispose() {
    _pagePrefsDebounce?.cancel();
    _fromPageController.dispose();
    _toPageController.dispose();
    super.dispose();
  }

  Future<void> _primePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  QuizSelectionType _modeFromPref(String? value) {
    switch (value) {
      case 'juz_range':
        return QuizSelectionType.juzRange;
      case 'surah_selection':
        return QuizSelectionType.surahSelection;
      case 'page_range':
      default:
        return QuizSelectionType.pageRange;
    }
  }

  String _modeToPref(QuizSelectionType mode) {
    switch (mode) {
      case QuizSelectionType.juzRange:
        return 'juz_range';
      case QuizSelectionType.surahSelection:
        return 'surah_selection';
      case QuizSelectionType.pageRange:
        return 'page_range';
    }
  }

  List<Surah> _resolveSelectedSurahs(
    List<int> selectedNumbers,
    List<Surah> allSurahs,
  ) {
    final selectedSet = selectedNumbers.toSet();
    final mapped =
        allSurahs.where((surah) => selectedSet.contains(surah.number)).toList()
          ..sort((a, b) => a.number.compareTo(b.number));
    return mapped;
  }

  Future<void> _loadSurahs() async {
    final surahs = await QuranDatabase().getAllSurahs();
    if (mounted) {
      final mapped = _resolveSelectedSurahs(_storedSurahNumbers, surahs);
      setState(() {
        _allSurahs = surahs;
        if (_storedSurahNumbers.isNotEmpty) {
          _selectedSurahs = mapped;
        }
      });
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await _getPrefs();
    final int start = prefs.getInt(_prefPageStart) ?? 1;
    final int end = prefs.getInt(_prefPageEnd) ?? 604;
    final int juzStart = (prefs.getInt(_prefJuzStart) ?? 1).clamp(1, 30);
    final int juzEnd = (prefs.getInt(_prefJuzEnd) ?? 30).clamp(1, 30);
    final QuizSelectionType mode = _modeFromPref(
      prefs.getString(_prefQuizMode),
    );
    final List<int> storedSurahs =
        (prefs.getStringList(_prefSurahNumbers) ?? const <String>[])
            .map(int.tryParse)
            .whereType<int>()
            .toList();

    if (mounted) {
      final mapped = _allSurahs.isEmpty
          ? const <Surah>[]
          : _resolveSelectedSurahs(storedSurahs, _allSurahs);

      setState(() {
        _fromPageController.text = start.toString();
        _toPageController.text = end.toString();
        _juzStart = juzStart <= juzEnd ? juzStart : juzEnd;
        _juzEnd = juzStart <= juzEnd ? juzEnd : juzStart;
        if (!_didUserSwitchMode) {
          _selectedType = mode;
        }
        _storedSurahNumbers = storedSurahs;
        if (mapped.isNotEmpty) {
          _selectedSurahs = mapped;
        }
      });
    }
  }

  Future<void> _saveSelectedMode() async {
    final prefs = await _getPrefs();
    await prefs.setString(_prefQuizMode, _modeToPref(_selectedType));
  }

  Future<void> _savePagePreferences() async {
    final prefs = await _getPrefs();
    final start = int.tryParse(_fromPageController.text.trim());
    final end = int.tryParse(_toPageController.text.trim());
    if (start != null) {
      await prefs.setInt(_prefPageStart, start);
    }
    if (end != null) {
      await prefs.setInt(_prefPageEnd, end);
    }
  }

  Future<void> _saveJuzPreferences() async {
    final prefs = await _getPrefs();
    await prefs.setInt(_prefJuzStart, _juzStart);
    await prefs.setInt(_prefJuzEnd, _juzEnd);
  }

  Future<void> _saveSurahPreferences() async {
    final prefs = await _getPrefs();
    final values = _selectedSurahs
        .map((surah) => surah.number.toString())
        .toList();
    await prefs.setStringList(_prefSurahNumbers, values);
  }

  void _schedulePagePreferenceSave() {
    _pagePrefsDebounce?.cancel();
    _pagePrefsDebounce = Timer(const Duration(milliseconds: 260), () {
      _savePagePreferences();
    });
  }

  Future<void> _saveAllPreferences() async {
    _pagePrefsDebounce?.cancel();
    await _saveSelectedMode();
    await _savePagePreferences();
    await _saveJuzPreferences();
    await _saveSurahPreferences();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _setSelectedType(QuizSelectionType type) {
    if (_selectedType == type) return;
    setState(() {
      _selectedType = type;
      _didUserSwitchMode = true;
    });
    _saveSelectedMode();
  }

  Future<void> _showSurahSelectionDialog() async {
    if (_allSurahs.isEmpty) {
      await _loadSurahs();
    }

    if (!mounted) return;

    final result = await showDialog<List<Surah>>(
      context: context,
      builder: (context) => SurahSelectionDialog(
        initialSelectedSurahs: _selectedSurahs,
        availableSurahs: _allSurahs,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedSurahs = result;
        _selectedSurahs.sort((a, b) => a.number.compareTo(b.number));
        _storedSurahNumbers = _selectedSurahs
            .map((surah) => surah.number)
            .toList();
      });
      await _saveSurahPreferences();
    }
  }

  Future<void> _startTesting() async {
    final l10n = AppLocalizations.of(context)!;

    if (_selectedType == QuizSelectionType.surahSelection) {
      if (_selectedSurahs.isEmpty) {
        _showMessage(l10n.selectSurahMessage);
        return;
      }

      await _saveAllPreferences();
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuizHomePage(
            settings: QuizSettings(
              surahNumbers: _selectedSurahs.map((s) => s.number).toList(),
            ),
          ),
        ),
      );
      return;
    }

    if (_selectedType == QuizSelectionType.juzRange) {
      if (_juzStart < 1 || _juzEnd < 1 || _juzStart > _juzEnd || _juzEnd > 30) {
        _showMessage(l10n.invalidNumberFormat);
        return;
      }

      await _saveAllPreferences();
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuizHomePage(
            settings: QuizSettings(
              juz: _juzStart == _juzEnd ? _juzStart : null,
              startJuz: _juzStart,
              endJuz: _juzEnd,
            ),
          ),
        ),
      );
      return;
    }

    String startText = _fromPageController.text.trim();
    String endText = _toPageController.text.trim();

    if (startText.isEmpty || endText.isEmpty) {
      _showMessage(l10n.enterPagesMessage);
      return;
    }

    int? start = int.tryParse(startText);
    int? end = int.tryParse(endText);

    if (start == null || end == null) {
      _showMessage(l10n.invalidNumberFormat);
      return;
    }

    if (start < 1 || end < 1 || start > end || end > 604) {
      _showMessage(l10n.invalidPageRange);
      return;
    }

    await _saveAllPreferences();
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizHomePage(
          settings: QuizSettings(startPage: start, endPage: end),
        ),
      ),
    );
  }

  String _modeTitle(AppLocalizations l10n) {
    switch (_selectedType) {
      case QuizSelectionType.pageRange:
        return l10n.pageRangeTitle;
      case QuizSelectionType.juzRange:
        return l10n.juz;
      case QuizSelectionType.surahSelection:
        return l10n.surahSelectionTitle;
    }
  }

  String _modeSubtitle(AppLocalizations l10n) {
    switch (_selectedType) {
      case QuizSelectionType.pageRange:
        return l10n.enterPagesMessage;
      case QuizSelectionType.juzRange:
        return '${l10n.juz} $_juzStart - $_juzEnd';
      case QuizSelectionType.surahSelection:
        if (_selectedSurahs.isEmpty) {
          return l10n.selectSurahMessage;
        }
        return '${_selectedSurahs.length} ${l10n.surah}';
    }
  }

  IconData _modeIcon() {
    switch (_selectedType) {
      case QuizSelectionType.pageRange:
        return Icons.menu_book_rounded;
      case QuizSelectionType.juzRange:
        return Icons.layers_rounded;
      case QuizSelectionType.surahSelection:
        return Icons.list_alt_rounded;
    }
  }

  Widget _buildTypeButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final selectedForeground = isDark ? Colors.white : const Color(0xFF123B69);
    final unselectedForeground = isDark
        ? Colors.white70
        : const Color(0xFF4E6383);
    final selectedTint = isDark
        ? const Color(0xFF3A5D88).withValues(alpha: 0.6)
        : const Color(0xFFDDEBFF).withValues(alpha: 0.92);

    return Expanded(
      child: LiquidGlass(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(12),
        blur: 11,
        tint: isSelected
            ? selectedTint
            : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.56)),
        border: Border.all(
          color: isSelected
              ? selectedForeground.withValues(alpha: 0.28)
              : (isDark ? Colors.white10 : Colors.black12),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 16,
                        color: isSelected
                            ? selectedForeground
                            : unselectedForeground,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: isSelected
                              ? selectedForeground
                              : unselectedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberInputField({
    required bool isDark,
    required TextEditingController controller,
    required String label,
    required VoidCallback onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : const Color(0xFF1A436F),
      ),
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      onChanged: (_) => onChanged(),
    );
  }

  Widget _buildJuzDropdownField({
    required bool isDark,
    required String label,
    required String itemPrefix,
    required int value,
    required List<int> items,
    required ValueChanged<int> onChanged,
  }) {
    final textColor = isDark ? Colors.white : const Color(0xFF1A436F);
    final menuColor = Theme.of(context).popupMenuTheme.color;
    final safeValue = items.contains(value)
        ? value
        : (items.isNotEmpty ? items.first : null);

    if (safeValue != null && safeValue != value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        onChanged(safeValue);
      });
    }

    return DropdownButtonFormField<int>(
      initialValue: safeValue,
      isExpanded: true,
      menuMaxHeight: 320,
      borderRadius: BorderRadius.circular(16),
      dropdownColor: menuColor,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: textColor),
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      items: items
          .map(
            (juz) => DropdownMenuItem<int>(
              value: juz,
              child: Text('$itemPrefix $juz'),
            ),
          )
          .toList(),
      onChanged: (newValue) {
        if (newValue == null) return;
        onChanged(newValue);
      },
    );
  }

  Widget _buildEditorActionCard({
    required bool isDark,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final accent = isDark ? const Color(0xFF91B8E9) : const Color(0xFF1C4D88);

    return LiquidGlass(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(16),
      blur: 13,
      tint: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.74),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [const Color(0x662B4C77), const Color(0x55365E92)]
            : [const Color(0xFFF4F8FF), const Color(0xFFE7F1FF)],
      ),
      border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.menu_book_rounded, size: 20, color: accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A436F),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF4D6684),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedSurahTile(bool isDark, Surah surah, int index) {
    final locale = Localizations.localeOf(context).languageCode;
    final title = locale == 'ar' ? surah.name : surah.englishName;

    return LiquidGlass(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderRadius: BorderRadius.circular(12),
      blur: 10,
      tint: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.white.withValues(alpha: 0.64),
      border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : const Color(0xFFDCEBFF),
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Text(
              '${surah.number}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF184777),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1A436F),
              ),
            ),
          ),
          InkWell(
            onTap: () {
              setState(() {
                _selectedSurahs.removeAt(index);
                _storedSurahNumbers = _selectedSurahs
                    .map((s) => s.number)
                    .toList();
              });
              _saveSurahPreferences();
            },
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeEditor(bool isDark) {
    final l10n = AppLocalizations.of(context)!;

    switch (_selectedType) {
      case QuizSelectionType.pageRange:
        return LiquidGlass(
          padding: const EdgeInsets.all(16),
          borderRadius: BorderRadius.circular(16),
          blur: 14,
          tint: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.72),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.pageRangeTitle,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1A436F),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildNumberInputField(
                      isDark: isDark,
                      controller: _fromPageController,
                      label: l10n.fromPageLabel,
                      onChanged: _schedulePagePreferenceSave,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildNumberInputField(
                      isDark: isDark,
                      controller: _toPageController,
                      label: l10n.toPageLabel,
                      onChanged: _schedulePagePreferenceSave,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '1 - 604',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : const Color(0xFF4D6684),
                ),
              ),
            ],
          ),
        );
      case QuizSelectionType.juzRange:
        final allJuz = List<int>.generate(30, (index) => index + 1);
        final endOptions = List<int>.generate(
          31 - _juzStart,
          (i) => _juzStart + i,
        );

        return LiquidGlass(
          padding: const EdgeInsets.all(16),
          borderRadius: BorderRadius.circular(16),
          blur: 14,
          tint: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.72),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.juz,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1A436F),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildJuzDropdownField(
                      isDark: isDark,
                      label: '${l10n.fromPageLabel} (${l10n.juz})',
                      itemPrefix: l10n.juz,
                      value: _juzStart,
                      items: allJuz,
                      onChanged: (value) {
                        setState(() {
                          _juzStart = value;
                          if (_juzEnd < value) {
                            _juzEnd = value;
                          }
                        });
                        _saveJuzPreferences();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildJuzDropdownField(
                      isDark: isDark,
                      label: '${l10n.toPageLabel} (${l10n.juz})',
                      itemPrefix: l10n.juz,
                      value: _juzEnd,
                      items: endOptions,
                      onChanged: (value) {
                        setState(() {
                          _juzEnd = value;
                        });
                        _saveJuzPreferences();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${l10n.juz} $_juzStart - $_juzEnd',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : const Color(0xFF4D6684),
                ),
              ),
            ],
          ),
        );
      case QuizSelectionType.surahSelection:
        return Column(
          children: [
            _buildEditorActionCard(
              isDark: isDark,
              title: l10n.selectSurahsButton,
              subtitle: _selectedSurahs.isEmpty
                  ? l10n.selectSurahMessage
                  : '${_selectedSurahs.length} ${l10n.surah}',
              onTap: _showSurahSelectionDialog,
            ),
            if (_selectedSurahs.isNotEmpty) ...[
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: LiquidGlass(
                  padding: const EdgeInsets.all(8),
                  borderRadius: BorderRadius.circular(16),
                  blur: 14,
                  tint: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.72),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            '${_selectedSurahs.length} ${l10n.surah}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF4D6684),
                            ),
                          ),
                          const Spacer(),
                          LiquidGlass(
                            padding: EdgeInsets.zero,
                            borderRadius: BorderRadius.circular(10),
                            blur: 8,
                            tint: isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.white.withValues(alpha: 0.74),
                            border: Border.all(
                              color: isDark ? Colors.white10 : Colors.black12,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedSurahs.clear();
                                    _storedSurahNumbers = <int>[];
                                  });
                                  _saveSurahPreferences();
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.clear_all_rounded,
                                        size: 16,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF1A436F),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${l10n.delete} ${l10n.all}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF1A436F),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _selectedSurahs.length,
                          separatorBuilder: (context, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final surah = _selectedSurahs[index];
                            return _buildSelectedSurahTile(
                              isDark,
                              surah,
                              index,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final startButtonColor = isDark
        ? const Color(0xFF5C7DA3)
        : const Color(0xFF58779A);
    final l10n = AppLocalizations.of(context)!;

    return DecoratedBox(
      decoration: AppBackground.pageDecoration(theme),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LiquidGlass(
                    padding: const EdgeInsets.all(16),
                    borderRadius: BorderRadius.circular(18),
                    blur: 20,
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0x50355D9F), const Color(0x66234A89)]
                          : [const Color(0xDCE7F4FF), const Color(0xCCD2E6FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black26,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _modeIcon(),
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1D4A8C),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _modeTitle(l10n),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF143A60),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _modeSubtitle(l10n),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.92)
                                      : const Color(0xFF2B5076),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  LiquidGlass(
                    padding: const EdgeInsets.all(4),
                    borderRadius: BorderRadius.circular(14),
                    blur: 14,
                    tint: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.white.withValues(alpha: 0.68),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black26,
                    ),
                    child: Row(
                      children: [
                        _buildTypeButton(
                          label: AppLocalizations.of(context)!.pageRangeTitle,
                          icon: Icons.menu_book_rounded,
                          isSelected:
                              _selectedType == QuizSelectionType.pageRange,
                          onTap: () =>
                              _setSelectedType(QuizSelectionType.pageRange),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildTypeButton(
                          label: AppLocalizations.of(context)!.juz,
                          icon: Icons.layers_rounded,
                          isSelected:
                              _selectedType == QuizSelectionType.juzRange,
                          onTap: () =>
                              _setSelectedType(QuizSelectionType.juzRange),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildTypeButton(
                          label: AppLocalizations.of(
                            context,
                          )!.surahSelectionTitle,
                          icon: Icons.list_alt_rounded,
                          isSelected:
                              _selectedType == QuizSelectionType.surahSelection,
                          onTap: () => _setSelectedType(
                            QuizSelectionType.surahSelection,
                          ),
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: KeyedSubtree(
                      key: ValueKey<String>('quiz-mode-${_selectedType.name}'),
                      child: _buildModeEditor(isDark),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: LiquidGlass(
              padding: const EdgeInsets.all(6),
              borderRadius: BorderRadius.circular(18),
              blur: 16,
              tint: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.7),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black26,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: LiquidGlass(
                  padding: EdgeInsets.zero,
                  borderRadius: BorderRadius.circular(14),
                  blur: 12,
                  tint: isDark
                      ? const Color(0xFF3A5D85).withValues(alpha: 0.6)
                      : const Color(0xFFDCEBFF).withValues(alpha: 0.92),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xAA335B8F), const Color(0x994171AA)]
                        : [const Color(0xFFF3F8FF), const Color(0xFFDCEBFF)],
                  ),
                  border: Border.all(
                    color: startButtonColor.withValues(alpha: 0.34),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _startTesting,
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox.expand(
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.play_arrow_rounded,
                                size: 20,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A4B87),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                l10n.startQuizButton,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1A4B87),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
