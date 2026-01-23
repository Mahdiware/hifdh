import 'package:flutter/material.dart';
import 'package:hifdh/core/services/database_helper.dart';
import 'package:hifdh/core/services/planner_database_helper.dart';
import 'package:hifdh/core/theme/app_colors.dart';
import 'package:hifdh/core/utils/open_quran.dart';
import 'package:hifdh/features/progress/models/ayah_color.dart';
import 'package:hifdh/shared/models/plan_task.dart';
import 'package:hifdh/shared/widgets/collapsible_note_card.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:hifdh/features/settings/logic/preferences_provider.dart';

class AyahAnalysisSheet extends StatefulWidget {
  final int surahId;
  final String surahName;

  const AyahAnalysisSheet({
    super.key,
    required this.surahId,
    required this.surahName,
  });

  @override
  State<AyahAnalysisSheet> createState() => _AyahAnalysisSheetState();
}

class _AyahAnalysisSheetState extends State<AyahAnalysisSheet> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _ayahs = []; // {id, number}
  Map<int, List<TaskNote>> _ayahNotes = {};
  Map<int, int> _ayahConsecutiveRights = {};
  Map<int, int> _ayahMistakeCounts = {};
  bool _isReadMode = false;

  @override
  void initState() {
    super.initState();
    final prefs = Provider.of<PreferencesProvider>(context, listen: false);
    _isReadMode = prefs.defaultToReadMode;

    _initialLoad();
  }

  Future<void> _initialLoad() async {
    setState(() => _isLoading = true);
    final enrichedAyahs = await DatabaseHelper().getAyahsMetadataForSurah(
      widget.surahId,
    );
    _ayahs = enrichedAyahs;
    await _refreshMistakes();
  }

  Future<void> _refreshMistakes() async {
    bool wasEmpty = _ayahs.isEmpty;
    if (wasEmpty) setState(() => _isLoading = true);

    final ids = _ayahs.map((e) => e['id'] as int).toList();
    final allNotes = await PlannerDatabaseHelper().getNotesForAyahs(ids);

    final noteMap = <int, List<TaskNote>>{};
    final consecutiveRights = <int, int>{};
    final mistakeCounts = <int, int>{};

    for (var note in allNotes) {
      if (note.ayahId != null) {
        noteMap.putIfAbsent(note.ayahId!, () => []).add(note);
      }
    }

    noteMap.forEach((ayahId, notes) {
      // Sort oldest to newest (ascending by date)
      notes.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // 1. Calculate Streak (Consecutive Rights from end)
      int streak = 0;
      for (int i = notes.length - 1; i >= 0; i--) {
        if (notes[i].type == NoteType.correct) {
          streak++;
        } else {
          break; // Stop as soon as a mistake/doubt is found
        }
      }
      consecutiveRights[ayahId] = streak;

      // 2. Calculate Recent Mistakes (Last 3 attempts)
      int mistakes = 0;
      int start = notes.length - 3;
      if (start < 0) start = 0;
      for (int i = start; i < notes.length; i++) {
        if (notes[i].type == NoteType.mistake ||
            notes[i].type == NoteType.doubt) {
          mistakes++;
        }
      }
      mistakeCounts[ayahId] = mistakes;
    });

    if (mounted) {
      setState(() {
        _ayahNotes = noteMap;
        _ayahConsecutiveRights = consecutiveRights;
        _ayahMistakeCounts = mistakeCounts;
        _isLoading = false;
      });
    }
  }

  Color _getAyahColor(int ayahId, bool isDark) {
    // If no history, return neutral
    if (!_ayahNotes.containsKey(ayahId)) {
      return Colors.transparent;
    }

    final streak = _ayahConsecutiveRights[ayahId] ?? 0;

    final mistakes = _ayahMistakeCounts[ayahId] ?? 0;
    return AyahColor.getAyahHighlightColor(mistakes, streak);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.surahName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: "QuranFont",
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.mistakesAnalysis,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black26 : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.all(2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildToggleItem(
                                l10n.analyze,
                                Icons.analytics_outlined,
                                !_isReadMode,
                                () => setState(() => _isReadMode = false),
                                isDark,
                              ),
                              _buildToggleItem(
                                l10n.read,
                                Icons.menu_book_rounded,
                                _isReadMode,
                                () => setState(() => _isReadMode = true),
                                isDark,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          _buildLegendItem(AyahColor.level1, "1"),
                          const SizedBox(width: 8),
                          _buildLegendItem(AyahColor.level2, "2"),
                          const SizedBox(width: 8),
                          _buildLegendItem(AyahColor.level3, "3"),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 8,
                          children: _ayahs.map((ayah) {
                            final id = ayah['id'] as int;
                            final number = ayah['ayahNumber'] as int;
                            final color = _getAyahColor(id, isDark);
                            Color pillColor;
                            Color textColor;

                            // Check transparency (Mastered or Neutral)
                            if (color == Colors.transparent ||
                                color == AyahColor.level0) {
                              pillColor = isDark
                                  ? Colors.white10
                                  : Colors.grey[200]!;
                              textColor = isDark
                                  ? Colors.white70
                                  : Colors.black87;
                            } else {
                              pillColor = color;
                              // Calculate text contrast
                              if (pillColor.computeLuminance() > 0.5) {
                                textColor = Colors.black87;
                              } else {
                                textColor = Colors.white;
                              }
                            }

                            return InkWell(
                              onTap: () async {
                                if (_isReadMode) {
                                  openQuranLink(widget.surahId, number);
                                  return;
                                }
                                bool hasChanges = false;
                                await showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).scaffoldBackgroundColor,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(24),
                                      ),
                                    ),
                                    child: _AyahHistorySheet(
                                      surahNumber: widget.surahId,
                                      surahName: widget.surahName,
                                      ayahNumber: number,
                                      initialNotes: _ayahNotes[id] ?? [],
                                      onDeleteNote: (int noteId) async {
                                        await PlannerDatabaseHelper()
                                            .deleteTaskNote(noteId);
                                        hasChanges = true;
                                      },
                                    ),
                                  ),
                                );
                                if (hasChanges) {
                                  _refreshMistakes();
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 44,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: pillColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "$number",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildToggleItem(
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
    bool isDark,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white24 : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? (isDark ? Colors.white : AppColors.primaryNavy)
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.primaryNavy,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AyahHistorySheet extends StatefulWidget {
  final int surahNumber;
  final String surahName;
  final int ayahNumber;
  final List<TaskNote> initialNotes;
  final Future<void> Function(int) onDeleteNote;

  const _AyahHistorySheet({
    required this.surahName,
    required this.ayahNumber,
    required this.initialNotes,
    required this.onDeleteNote,
    required this.surahNumber,
  });

  @override
  State<_AyahHistorySheet> createState() => _AyahHistorySheetState();
}

class _AyahHistorySheetState extends State<_AyahHistorySheet> {
  late List<TaskNote> _notes;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _notes = List.from(widget.initialNotes);
    // Arrange (sort) by date (Newest First) "as one file"
    _notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleDelete(int noteId) async {
    await widget.onDeleteNote(noteId);
    if (mounted) {
      setState(() {
        _notes.removeWhere((n) => n.id == noteId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${widget.surahName} : ${widget.ayahNumber}",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: "QuranFont",
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${_notes.length} ${l10n.notesHistory}",
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () =>
                    openQuranLink(widget.surahNumber, widget.ayahNumber),
                icon: Icon(Icons.menu_book_rounded),
              ),
            ],
          ),
          const Divider(height: 32),
          Expanded(
            child: _notes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 48,
                          color: AppColors.successGreen.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.noMistakesRecorded,
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _notes.length,
                    itemBuilder: (context, index) {
                      final note = _notes[index];
                      return CollapsibleNoteCard(
                        note: note,
                        onDelete: note.id == null
                            ? () {}
                            : () => _handleDelete(note.id!),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
