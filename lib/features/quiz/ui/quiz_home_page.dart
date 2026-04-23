import 'package:flutter/material.dart';
import 'package:hifdh/core/services/quran_database.dart';
import 'package:hifdh/core/theme/app_background.dart';
import 'package:hifdh/core/theme/app_colors.dart';
import 'package:hifdh/features/quiz/ui/result_page.dart';
import 'package:hifdh/shared/models/ayah.dart';
import 'package:hifdh/shared/models/result_item.dart';
import 'package:hifdh/shared/models/quiz_settings.dart';
import 'package:hifdh/core/utils/surah_glyphs.dart';
import 'package:hifdh/shared/widgets/theme_toggle_button.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';
import 'package:hifdh/shared/widgets/liquid_glass.dart';

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

            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LiquidGlass(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  borderRadius: BorderRadius.circular(20),
                  blur: 18,
                  tint: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.78),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black26,
                  ),
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
                              color: theme.colorScheme.onSurface,
                            ),
                            onPressed: () => navigateAyah(1),
                          ),
                          Text(
                            "${currentDialogAyah.surahNumber}:${currentDialogAyah.ayahNumber}",
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.arrow_forward_ios,
                              color: theme.colorScheme.onSurface,
                            ),
                            onPressed: () => navigateAyah(-1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: LiquidGlass(
                          padding: EdgeInsets.zero,
                          borderRadius: BorderRadius.circular(10),
                          blur: 8,
                          tint: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.white.withValues(alpha: 0.72),
                          border: Border.all(
                            color: isDark
                                ? Colors.white10
                                : AppColors.primaryNavy.withValues(alpha: 0.14),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => Navigator.pop(context),
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                child: Text(
                                  AppLocalizations.of(context)!.close,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.primaryNavy,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final colorScheme = theme.colorScheme;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LiquidGlass(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              borderRadius: BorderRadius.circular(20),
              blur: 18,
              tint: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.78),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black26,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppLocalizations.of(context)!.didYouGetItRight,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDialogChoiceButton(
                          label: AppLocalizations.of(context)!.no,
                          icon: Icons.close_rounded,
                          accent: colorScheme.error,
                          isDark: isDark,
                          onTap: () {
                            Navigator.pop(context);
                            _recordAnswer(false);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDialogChoiceButton(
                          label: AppLocalizations.of(context)!.yes,
                          icon: Icons.check_rounded,
                          accent: Colors.green,
                          isDark: isDark,
                          onTap: () {
                            Navigator.pop(context);
                            _recordAnswer(true);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogChoiceButton({
    required String label,
    required IconData icon,
    required Color accent,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final buttonTint = accent.withValues(alpha: isDark ? 0.74 : 0.68);
    final foreground =
        ThemeData.estimateBrightnessForColor(buttonTint) == Brightness.dark
        ? Colors.white
        : Colors.black87;

    return LiquidGlass(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(12),
      blur: 10,
      tint: buttonTint,
      border: Border.all(color: accent.withValues(alpha: isDark ? 0.56 : 0.5)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool isPrimary,
    required bool isDark,
  }) {
    final accent = isPrimary
        ? (isDark ? const Color(0xFF8EB9E9) : const Color(0xFF1D4A8C))
        : (isDark ? Colors.white : AppColors.textPrimaryLight);

    return LiquidGlass(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(12),
      blur: 12,
      tint: isPrimary
          ? (isDark
                ? const Color(0xFF3B5D84).withValues(alpha: 0.52)
                : const Color(0xFFDCEBFF).withValues(alpha: 0.86))
          : (isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.72)),
      gradient: isPrimary
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xAA335B8E), const Color(0x994070A9)]
                  : [const Color(0xFFF0F6FF), const Color(0xFFDCEBFF)],
            )
          : null,
      border: Border.all(
        color: isPrimary
            ? accent.withValues(alpha: 0.32)
            : (isDark ? Colors.white12 : Colors.black26),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: accent),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
        ),
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
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final lightAccentText = const Color(0xFF153A61);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: DecoratedBox(
        decoration: AppBackground.pageDecoration(theme),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: LiquidGlass(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  blur: 16,
                  tint: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.7),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black26,
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
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: LiquidGlass(
                  padding: const EdgeInsets.all(14),
                  borderRadius: BorderRadius.circular(16),
                  blur: 18,
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0x50355E9E), const Color(0x65274A86)]
                        : [const Color(0xFFEAF3FF), const Color(0xFFDDEAFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black26,
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
                              : const Color(0xFFCCDDF3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "${AppLocalizations.of(context)!.question} $_questionCount",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : lightAccentText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : const Color(0xFFD3E4F8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_results.length}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : lightAccentText,
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
                            color: isDark ? Colors.white : lightAccentText,
                          ),
                        ),
                      ),
                    ],
                  ),
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
                        child: LiquidGlass(
                          padding: EdgeInsets.zero,
                          borderRadius: BorderRadius.circular(20),
                          blur: 20,
                          tint: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.white.withValues(alpha: 0.74),
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.black26,
                          ),
                          child: SizedBox(
                            width: double.infinity,
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
                                      SurahGlyphs
                                          .list[_currentAyah!.surahNumber - 1],
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
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: LiquidGlass(
                  padding: const EdgeInsets.all(8),
                  borderRadius: BorderRadius.circular(18),
                  blur: 16,
                  tint: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.72),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black26,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildFooterActionButton(
                          label: AppLocalizations.of(context)!.showAnswer,
                          icon: Icons.visibility_outlined,
                          onTap: _showAnswerDialog,
                          isPrimary: false,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildFooterActionButton(
                          label: AppLocalizations.of(context)!.nextQuestion,
                          icon: Icons.navigate_next_rounded,
                          onTap: _checkAnswerDialog,
                          isPrimary: true,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
