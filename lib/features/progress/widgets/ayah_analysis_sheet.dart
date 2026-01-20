import 'package:flutter/material.dart';
import 'package:hifdh/core/services/database_helper.dart';
import 'package:hifdh/core/services/planner_database_helper.dart';
import 'package:hifdh/core/theme/app_colors.dart';
import 'package:hifdh/core/utils/open_quran.dart';
import 'package:hifdh/shared/models/plan_task.dart';
import 'package:hifdh/shared/widgets/collapsible_note_card.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';

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
  Map<int, int> _ayahMistakeCounts = {};

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    setState(() => _isLoading = true);
    // Fetch static Ayah structure only once
    final enrichedAyahs = await DatabaseHelper().getAyahsMetadataForSurah(
      widget.surahId,
    );
    _ayahs = enrichedAyahs;
    // Then load dynamic data
    await _refreshMistakes();
  }

  Future<void> _refreshMistakes() async {
    bool wasEmpty = _ayahs.isEmpty;
    if (wasEmpty) setState(() => _isLoading = true);

    final allNotes = await PlannerDatabaseHelper().getNotesForUnit(
      PlanUnitType.surah,
      widget.surahId,
    );

    final noteMap = <int, List<TaskNote>>{};
    final mistakeCounts = <int, int>{};

    // Group notes by Ayah
    for (var note in allNotes) {
      if (note.ayahId != null) {
        noteMap.putIfAbsent(note.ayahId!, () => []).add(note);
      }
    }

    // Calculate mistakes based on last 5 entries
    noteMap.forEach((ayahId, notes) {
      // Sort recent first
      notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Analyze last 5 attempts
      final recent = notes.take(5);
      final count = recent.where((n) => n.type != NoteType.correct).length;
      mistakeCounts[ayahId] = count;
    });

    if (mounted) {
      setState(() {
        _ayahNotes = noteMap;
        _ayahMistakeCounts = mistakeCounts;
        _isLoading = false;
      });
    }
  }

  Color _getAyahColor(int ayahId, bool isDark) {
    final count = _ayahMistakeCounts[ayahId] ?? 0;

    if (count == 0) {
      return isDark ? Colors.white : Colors.black;
    } else if (count == 1) {
      return AppColors.successGreen;
    } else if (count == 2) {
      return Colors.amber;
    } else if (count == 3) {
      return AppColors.accentOrange;
    } else {
      return AppColors.errorRed;
    }
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
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Text(
                      widget.surahName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: "QuranFont",
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.mistakesAnalysis,
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLegendItem(AppColors.errorRed, "4+"),
                        const SizedBox(width: 12),
                        _buildLegendItem(AppColors.accentOrange, "3"),
                        const SizedBox(width: 12),
                        _buildLegendItem(Colors.amber, "2"),
                        const SizedBox(width: 12),
                        _buildLegendItem(AppColors.successGreen, "1"),
                      ],
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
                            final isNeutral =
                                color == (isDark ? Colors.white : Colors.black);

                            Color pillColor;
                            Color textColor;

                            if (isNeutral) {
                              pillColor = isDark
                                  ? Colors.white10
                                  : Colors.grey[200]!;
                              textColor = isDark
                                  ? Colors.white70
                                  : Colors.black87;
                            } else {
                              pillColor = color;
                              if (color == AppColors.successGreen) {
                                pillColor = const Color(0xFFA8E000);
                                textColor = const Color(0xFF243B00);
                              } else if (color == Colors.amber) {
                                textColor = Colors.black87;
                              } else {
                                textColor = Colors.white;
                              }
                            }

                            return InkWell(
                              onTap: () async {
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
                        showCorrectNote: true,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
