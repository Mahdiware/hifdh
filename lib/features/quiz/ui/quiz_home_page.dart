import 'package:flutter/material.dart';
import 'package:hifdh/core/services/database_helper.dart';
import 'package:hifdh/features/quiz/ui/result_page.dart';
import 'package:hifdh/shared/models/ayah.dart';
import 'package:hifdh/shared/models/result_item.dart';
import 'package:hifdh/shared/models/quiz_settings.dart';
import 'package:hifdh/core/utils/surah_glyphs.dart';
import 'package:hifdh/shared/widgets/theme_toggle_button.dart';

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
      final dbHelper = DatabaseHelper();
      Ayah? ayah;

      if (widget.settings.surahNumbers != null &&
          widget.settings.surahNumbers!.isNotEmpty) {
        ayah = await dbHelper.getRandomAyahBySurahList(
          widget.settings.surahNumbers!,
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

      if (ayah != null) {
        setState(() {
          _currentAyah = ayah;
        });
      } else {
        setState(() {
          _debugInfo += 'No ayah found matching criteria.\n';
        });
      }
    } catch (e) {
      setState(() {
        _debugInfo += 'Error: $e\n';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _showAnswerDialog() async {
    if (_currentAyah == null) return;

    // Preload next ayah
    final dbHelper = DatabaseHelper();
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
              final dbHelper = DatabaseHelper();
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
                          icon: const Icon(Icons.arrow_back_ios),
                          onPressed: () => navigateAyah(1),
                        ),
                        Text(
                          "${currentDialogAyah.surahNumber}:${currentDialogAyah.ayahNumber}",
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios),
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
                  child: const Text("Close"),
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
        title: const Text("Did you get it right?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _recordAnswer(false);
            },
            child: const Text("No", style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _recordAnswer(true);
            },
            child: const Text("Yes", style: TextStyle(color: Colors.green)),
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
        const SnackBar(content: Text("There is no question answered!")),
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
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      // backgroundColor: const Color(0xFF232635), // Use theme background
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 8.0,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Back',
                  ),
                  const Spacer(),
                  const ThemeToggleButton(),
                  IconButton(
                    icon: const Icon(Icons.flag_outlined),
                    onPressed: _finishQuiz,
                    tooltip: 'Finish Quiz',
                    color: Colors.red,
                  ),
                ],
              ),
            ),

            // QUESTION INFO
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "Question $_questionCount",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                  Text(
                    "أكمل قوله تعالى",
                    style: TextStyle(
                      fontSize: 22,
                      fontFamily: 'QuranFont',
                      color: textColor,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),

            // CONTENT
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
                  : Column(
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
                                  fontSize: 28,
                                  height: 1.5,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Surah Name
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 12.0,
                            top: 12.0,
                            bottom: 12.0,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              SurahGlyphs.list[_currentAyah!.surahNumber - 1],
                              style: const TextStyle(
                                fontFamily: 'SurahFont',
                                fontSize: 40,
                                color: Color(0xFF2BA403),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),

            const Divider(height: 1, thickness: 1, color: Colors.grey),

            // CONTROLS
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _showAnswerDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.all(12),
                      ),
                      child: const Text(
                        "Show Answer",
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _checkAnswerDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2BA403),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(12),
                      ),
                      child: const Text(
                        "Next Question",
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
