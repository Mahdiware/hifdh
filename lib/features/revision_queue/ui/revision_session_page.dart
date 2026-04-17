import 'package:flutter/material.dart';
import 'package:hifdh/core/services/planner_database.dart';
import 'package:hifdh/core/theme/app_background.dart';
import 'package:hifdh/core/theme/app_colors.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';
import 'package:hifdh/shared/models/plan_task.dart';

class RevisionSessionPage extends StatefulWidget {
  final List<Map<String, dynamic>> initialQueue;

  const RevisionSessionPage({super.key, required this.initialQueue});

  @override
  State<RevisionSessionPage> createState() => _RevisionSessionPageState();
}

class _RevisionSessionPageState extends State<RevisionSessionPage> {
  late List<Map<String, dynamic>> _remaining;
  int _index = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _remaining = List<Map<String, dynamic>>.from(widget.initialQueue);
  }

  Future<String?> _promptOptionalNote(AppLocalizations l10n) async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.queueOptionalNote),
          content: TextField(
            controller: controller,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: l10n.descriptionOptional,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text(l10n.confirm),
            ),
          ],
        );
      },
    );

    return result;
  }

  Future<void> _submitCurrent(NoteType outcome) async {
    if (_remaining.isEmpty || _isSubmitting) return;

    final l10n = AppLocalizations.of(context)!;
    final current = _remaining[_index];
    final ayahId = (current['ayahId'] as num?)?.toInt() ?? 0;
    if (ayahId <= 0) return;

    var note = '';
    if (outcome != NoteType.correct) {
      final result = await _promptOptionalNote(l10n);
      if (result == null) return;
      note = result;
    }

    setState(() => _isSubmitting = true);

    try {
      await PlannerDatabase().recordRevisionQueueOutcome(
        ayahId: ayahId,
        outcome: outcome,
        note: note,
      );

      if (!mounted) return;

      setState(() {
        _remaining.removeAt(_index);

        if (_remaining.isEmpty) {
          return;
        }

        if (_index >= _remaining.length) {
          _index = _remaining.length - 1;
        }
      });

      if (_remaining.isEmpty && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.queueSessionComplete)));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorWithMessage(e.toString()))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _goNext() {
    if (_remaining.isEmpty) return;
    setState(() {
      _index = (_index + 1) % _remaining.length;
    });
  }

  void _goPrevious() {
    if (_remaining.isEmpty) return;
    setState(() {
      _index = (_index - 1 + _remaining.length) % _remaining.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final surfaceColor = theme.colorScheme.surface;

    if (_remaining.isEmpty) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          title: Text(l10n.queueSession),
        ),
        body: DecoratedBox(
          decoration: AppBackground.pageDecoration(theme),
          child: Center(child: Text(l10n.queueSessionComplete)),
        ),
      );
    }

    final current = _remaining[_index];
    final surahNumber = (current['surahNumber'] as num?)?.toInt() ?? 0;
    final ayahNumber = (current['ayahNumber'] as num?)?.toInt() ?? 0;
    final surahName = (current['surahArabicName'] as String?) ?? l10n.unknown;
    final ayahText = (current['ayahText'] as String?) ?? '';
    final progressLabel = '${_index + 1}/${_remaining.length}';

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        scrolledUnderElevation: 0,
        title: Text(l10n.queueSession),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black12,
              ),
            ),
            child: Center(
              child: Text(
                progressLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: AppBackground.pageDecoration(theme),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$surahNumber:$ayahNumber',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            surahName,
                            style: const TextStyle(
                              fontFamily: 'QuranFont',
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      ayahText,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontSize: 28,
                        fontFamily: 'QuranFont',
                        color: isDark
                            ? Colors.white
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _goPrevious,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: (_index + 1) / _remaining.length,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    IconButton(
                      onPressed: _goNext,
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSubmitting
                              ? null
                              : () => _submitCurrent(NoteType.mistake),
                          icon: const Icon(Icons.close),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            minimumSize: const Size(0, 50),
                          ),
                          label: Text(l10n.mistake),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSubmitting
                              ? null
                              : () => _submitCurrent(NoteType.doubt),
                          icon: const Icon(Icons.help_outline),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.accentOrange,
                            minimumSize: const Size(0, 50),
                          ),
                          label: Text(l10n.doubt),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () => _submitCurrent(NoteType.correct),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline_rounded),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 54),
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                      ),
                      label: Text(l10n.correct),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
