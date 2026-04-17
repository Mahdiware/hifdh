import 'package:flutter/material.dart';
import 'package:hifdh/core/services/quran_database.dart';
import 'package:hifdh/core/theme/app_background.dart';
import 'package:hifdh/features/quiz/ui/result_page.dart';
import 'package:hifdh/shared/models/ayah.dart';
import 'package:hifdh/shared/models/result_item.dart';
import 'package:hifdh/shared/models/quiz_settings.dart';
import 'package:hifdh/core/utils/surah_glyphs.dart';
import 'package:hifdh/shared/widgets/theme_toggle_button.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';

class QuizHomePage extends StatefulWidget {
  final QuizSettings settings;

  const QuizHomePage({super.key, required this.settings});

  @override
  State<QuizHomePage> createState() => _QuizHomePageState();
}

class _QuizHomePageState extends State<QuizHomePage> {
  Ayah? _currentAyah;
  bool _loading = false;
  String _debugInfo = '';

  final List<ResultItem> _results = [];
  int _questionCount = 1;

  @override
  void initState() {
    super.initState();
    _loadRandomAyah();
  }

  Future<void> _loadRandomAyah() async {
    setState(() {
      _loading = true;
      _debugInfo = '';
    });

    try {
      final dbHelper = QuranDatabase();
      Ayah? ayah;

      if (widget.settings.surahNumbers != null &&
          widget.settings.surahNumbers!.isNotEmpty) {
        ayah = await dbHelper.getRandomAyahBySurahList(
          widget.settings.surahNumbers!,
        );
      } else if (widget.settings.isJuzRange) {
        ayah = await dbHelper.getRandomAyahByJuzRange(
          widget.settings.startJuz!,
          widget.settings.endJuz!,
        );
      } else if (widget.settings.juz != null) {
        ayah = await dbHelper.getRandomAyahByJuz(widget.settings.juz!);
      } else if (widget.settings.startPage != null &&
          widget.settings.endPage != null) {
        ayah = await dbHelper.getRandomAyahByPageRange(
          widget.settings.startPage!,
          widget.settings.endPage!,
        );
      } else {
        ayah = await dbHelper.getRandomAyah();
      }

      if (!mounted) return;

      if (ayah != null) {
        setState(() {
          _currentAyah = ayah;
        });
      } else {
        setState(() {
          _debugInfo += '${AppLocalizations.of(context)!.noAyahFound}\n';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _debugInfo += 'Error: $e\n';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _showAnswerDialog() async {
    if (_currentAyah == null) return;

    // Preload next ayah
    final dbHelper = QuranDatabase();
    final nextAyah = await dbHelper.getAyahBySurahAyah(
      _currentAyah!.surahNumber,
      _currentAyah!.ayahNumber + 1,
    );

    // We need a stateful builder for the dialog to handle next/prev ayah updates
    int offset = nextAyah != null ? 1 : 0;
    Ayah currentDialogAyah = nextAyah ?? _currentAyah!;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> navigateAyah(int direction) async {
              final newOffset = offset + direction;
              final dbHelper = QuranDatabase();
              final newAyah = await dbHelper.getAyahBySurahAyah(
                _currentAyah!.surahNumber,
                _currentAyah!.ayahNumber + newOffset,
              );

              if (newAyah != null) {
                offset = newOffset;
                setDialogState(() {
                  currentDialogAyah = newAyah;
                });
              }
            }

            return AlertDialog(
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 250,
                      child: SingleChildScrollView(
                        child: Text(
                          currentDialogAyah.text,
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                            fontFamily: 'QuranFont',
                            fontSize: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back_ios,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          onPressed: () => navigateAyah(1),
                        ),
                        Text(
                          "${currentDialogAyah.surahNumber}:${currentDialogAyah.ayahNumber}",
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.arrow_forward_ios,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          onPressed: () => navigateAyah(-1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppLocalizations.of(context)!.close),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _checkAnswerDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.didYouGetItRight),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _recordAnswer(false);
            },
            child: Text(
              AppLocalizations.of(context)!.no,
              style: const TextStyle(color: Colors.red),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _recordAnswer(true);
            },
            child: Text(
              AppLocalizations.of(context)!.yes,
              style: const TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  void _recordAnswer(bool isCorrect) {
    if (_currentAyah != null) {
      _results.add(ResultItem(ayah: _currentAyah!, isCorrect: isCorrect));
      setState(() {
        _questionCount++;
      });
      _loadRandomAyah();
    }
  }

  void _finishQuiz() {
    if (_results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.questionAnsweredError),
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => ResultPage(results: _results)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: DecoratedBox(
        decoration: AppBackground.pageDecoration(theme),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.20 : 0.06,
                      ),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: theme.colorScheme.onSurface,
                      ),
                      onPressed: () => Navigator.pop(context),
                      tooltip: AppLocalizations.of(context)!.back,
                    ),
                    const Spacer(),
                    const ThemeToggleButton(),
                    IconButton(
                      icon: const Icon(Icons.flag_outlined),
                      onPressed: _finishQuiz,
                      tooltip: AppLocalizations.of(context)!.finishQuiz,
                      color: colorScheme.error,
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF355E9E), const Color(0xFF274A86)]
                        : [const Color(0xFFEBF4FF), const Color(0xFFDCEBFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.20)
                            : colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "${AppLocalizations.of(context)!.question} $_questionCount",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.completeVersePrompt,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _currentAyah == null
                    ? Center(
                        child: Text(
                          _debugInfo,
                          style: TextStyle(color: textColor),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? Colors.white10 : Colors.black12,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.18 : 0.06,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      _currentAyah!.text,
                                      textAlign: TextAlign.center,
                                      textDirection: TextDirection.rtl,
                                      style: TextStyle(
                                        fontFamily: 'QuranFont',
                                        fontSize: 30,
                                        height: 1.6,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Divider(
                                height: 1,
                                color: theme.dividerColor.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  12,
                                  12,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    SurahGlyphs.list[_currentAyah!.surahNumber -
                                        1],
                                    style: const TextStyle(
                                      fontFamily: 'SurahFont',
                                      fontSize: 36,
                                      color: Color(0xFF2BA403),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _showAnswerDialog,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textColor,
                          padding: const EdgeInsets.all(12),
                          side: BorderSide(
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.visibility_outlined, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              AppLocalizations.of(context)!.showAnswer,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _checkAnswerDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.all(12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.navigate_next_rounded, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              AppLocalizations.of(context)!.nextQuestion,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
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
