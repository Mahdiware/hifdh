import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hifdh/core/services/quran_database.dart';
import 'package:hifdh/core/theme/app_background.dart';
import 'package:hifdh/core/theme/app_colors.dart';
import 'package:hifdh/features/quiz/ui/quiz_home_page.dart';
import 'package:hifdh/features/quiz/ui/surah_selection_dialog.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';
import 'package:hifdh/shared/models/quiz_settings.dart';
import 'package:hifdh/shared/models/surah.dart';
import 'package:hifdh/shared/widgets/selection_card.dart';
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

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadSurahs();
  }

  @override
  void dispose() {
    _fromPageController.dispose();
    _toPageController.dispose();
    super.dispose();
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
    final prefs = await SharedPreferences.getInstance();
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
        _selectedType = mode;
        _storedSurahNumbers = storedSurahs;
        if (mapped.isNotEmpty) {
          _selectedSurahs = mapped;
        }
      });
    }
  }

  Future<void> _saveSelectedMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefQuizMode, _modeToPref(_selectedType));
  }

  Future<void> _savePagePreferences() async {
    final prefs = await SharedPreferences.getInstance();
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefJuzStart, _juzStart);
    await prefs.setInt(_prefJuzEnd, _juzEnd);
  }

  Future<void> _saveSurahPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final values = _selectedSurahs
        .map((surah) => surah.number.toString())
        .toList();
    await prefs.setStringList(_prefSurahNumbers, values);
  }

  Future<void> _saveAllPreferences() async {
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
    final colorScheme = Theme.of(context).colorScheme;
    final selectedBackground = isDark
        ? colorScheme.primary.withValues(alpha: 0.72)
        : colorScheme.primary.withValues(alpha: 0.14);
    final selectedForeground = isDark ? Colors.white : colorScheme.primary;
    final unselectedForeground = isDark
        ? Colors.white70
        : AppColors.textSecondaryLight;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? selectedBackground : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? selectedForeground : unselectedForeground,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
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
    );
  }

  Widget _buildModeEditor(bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    final surfaceColor = Theme.of(context).colorScheme.surface;

    switch (_selectedType) {
      case QuizSelectionType.pageRange:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _fromPageController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: l10n.fromPageLabel),
                  onChanged: (_) => _savePagePreferences(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _toPageController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: l10n.toPageLabel),
                  onChanged: (_) => _savePagePreferences(),
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

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: ValueKey<String>('juz-start-$_juzStart-$_juzEnd'),
                  initialValue: _juzStart,
                  decoration: InputDecoration(
                    labelText: '${l10n.fromPageLabel} (${l10n.juz})',
                  ),
                  items: allJuz
                      .map(
                        (juz) => DropdownMenuItem<int>(
                          value: juz,
                          child: Text('${l10n.juz} $juz'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
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
                child: DropdownButtonFormField<int>(
                  key: ValueKey<String>('juz-end-$_juzStart-$_juzEnd'),
                  initialValue: _juzEnd,
                  decoration: InputDecoration(
                    labelText: '${l10n.toPageLabel} (${l10n.juz})',
                  ),
                  items: endOptions
                      .map(
                        (juz) => DropdownMenuItem<int>(
                          value: juz,
                          child: Text('${l10n.juz} $juz'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _juzEnd = value;
                    });
                    _saveJuzPreferences();
                  },
                ),
              ),
            ],
          ),
        );
      case QuizSelectionType.surahSelection:
        final l10n = AppLocalizations.of(context)!;

        return Column(
          children: [
            SelectionCard(
              title: l10n.selectSurahsButton,
              subtitle: _selectedSurahs.isEmpty
                  ? l10n.selectSurahMessage
                  : '${_selectedSurahs.length} ${l10n.surah}',
              icon: Icons.menu_book_outlined,
              onTap: _showSurahSelectionDialog,
              isSelected: _selectedSurahs.isNotEmpty,
            ),
            if (_selectedSurahs.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 280),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _selectedSurahs.length,
                  separatorBuilder: (context, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final surah = _selectedSurahs[index];
                    return ListTile(
                      title: Text(
                        surah.glyph,
                        style: const TextStyle(
                          fontFamily: 'SurahFont',
                          fontSize: 24,
                        ),
                      ),
                      subtitle: Text(surah.englishName),
                      trailing: IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedSurahs.removeAt(index);
                            _storedSurahNumbers = _selectedSurahs
                                .map((s) => s.number)
                                .toList();
                          });
                          _saveSurahPreferences();
                        },
                      ),
                    );
                  },
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
    final colorScheme = theme.colorScheme;
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
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF355D9F), const Color(0xFF234A89)]
                            : [
                                const Color(0xFF87B7FF),
                                const Color(0xFF548DE6),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
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
                                  color: isDark ? Colors.white : Colors.white,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _modeSubtitle(l10n),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.92),
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
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
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
                    child: Container(
                      key: ValueKey<String>('quiz-mode-${_selectedType.name}'),
                      child: _buildModeEditor(isDark),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _startTesting,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_arrow_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      l10n.startQuizButton,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
