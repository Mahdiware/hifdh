import 'package:flutter/material.dart';
import 'package:hifdh/core/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hifdh/shared/models/surah.dart';
import 'package:hifdh/shared/models/quiz_settings.dart';
import 'package:hifdh/core/services/quran_database.dart';
import 'package:hifdh/features/quiz/ui/surah_selection_dialog.dart';
import 'package:hifdh/features/quiz/ui/quiz_home_page.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';
import 'package:hifdh/shared/widgets/expandable_option_card.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  bool _isPageRangeExpanded = false;
  bool _isSurahRangeExpanded = false;
  List<Surah> _selectedSurahs = [];
  List<Surah> _allSurahs = [];

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

  Future<void> _loadSurahs() async {
    final surahs = await QuranDatabase().getAllSurahs();
    if (mounted) {
      setState(() {
        _allSurahs = surahs;
      });
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to 1-604 if not set
    int start = prefs.getInt('start_page') ?? 1;
    int end = prefs.getInt('end_page') ?? 604;

    if (mounted) {
      setState(() {
        _fromPageController.text = start.toString();
        _toPageController.text = end.toString();
      });
    }
  }

  Future<void> _savePreferences(int start, int end) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('start_page', start);
    await prefs.setInt('end_page', end);
  }

  void _togglePageRange() {
    setState(() {
      _isPageRangeExpanded = !_isPageRangeExpanded;
      if (_isPageRangeExpanded) {
        _isSurahRangeExpanded = false;
      }
    });
  }

  void _toggleSurahRange() {
    setState(() {
      _isSurahRangeExpanded = !_isSurahRangeExpanded;
      if (_isSurahRangeExpanded) {
        _isPageRangeExpanded = false;
      }
    });
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
        // Sort by number
        _selectedSurahs.sort((a, b) => a.number.compareTo(b.number));
      });
    }
  }

  void _startTesting() {
    final l10n = AppLocalizations.of(context)!;
    if (!_isPageRangeExpanded && !_isSurahRangeExpanded) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.selectTypeMessage)));
      return;
    }

    if (_isSurahRangeExpanded) {
      if (_selectedSurahs.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.selectSurahMessage)));
        return;
      }

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

    String startText = _fromPageController.text.trim();
    String endText = _toPageController.text.trim();

    if (startText.isEmpty || endText.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.enterPagesMessage)));
      return;
    }

    int? start = int.tryParse(startText);
    int? end = int.tryParse(endText);

    if (start == null || end == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.invalidNumberFormat)));
      return;
    }

    if (start < 1 || end < 1 || start > end || end > 604) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.invalidPageRange)));
      return;
    }

    _savePreferences(start, end);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizHomePage(
          settings: QuizSettings(startPage: start, endPage: end),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        // CONTENT
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Page Range Card
                ExpandableOptionCard(
                  title: AppLocalizations.of(context)!.pageRangeTitle,
                  isExpanded: _isPageRangeExpanded,
                  onToggle: _togglePageRange,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _fromPageController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(
                                context,
                              )!.fromPageLabel,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _toPageController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(
                                context,
                              )!.toPageLabel,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Surah Selection Card
                ExpandableOptionCard(
                  title: AppLocalizations.of(context)!.surahSelectionTitle,
                  isExpanded: _isSurahRangeExpanded,
                  onToggle: _toggleSurahRange,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _showSurahSelectionDialog,
                          icon: const Icon(Icons.add),
                          label: Text(
                            AppLocalizations.of(context)!.selectSurahsButton,
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                        if (_selectedSurahs.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            height: 250,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.3),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListView.separated(
                              itemCount: _selectedSurahs.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
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
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _selectedSurahs.remove(surah);
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Start Button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _startTesting,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? AppColors.surfaceDark
                    : AppColors.backgroundLight,
                foregroundColor: isDark ? Colors.white : Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: Text(
                AppLocalizations.of(context)!.startQuizButton,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
