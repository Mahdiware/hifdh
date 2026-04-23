import 'package:flutter/material.dart';
import 'package:hifdh/core/services/quran_database.dart';
import 'package:hifdh/core/services/planner_database.dart';
import 'package:hifdh/core/theme/app_colors.dart';
import 'package:hifdh/core/utils/open_quran.dart';
import 'package:hifdh/features/progress/models/ayah_color.dart';
import 'package:hifdh/shared/models/plan_task.dart';
import 'package:hifdh/shared/widgets/collapsible_note_card.dart';
import 'package:hifdh/shared/widgets/liquid_glass.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:hifdh/features/settings/logic/preferences_provider.dart';

class AyahAnalysisSheet extends StatefulWidget {
  final PlanUnitType unitType;
  final int unitId;
  final String title;

  const AyahAnalysisSheet({
    super.key,
    required this.unitType,
    required this.unitId,
    required this.title,
  });

  @override
  State<AyahAnalysisSheet> createState() => _AyahAnalysisSheetState();
}

class _AyahAnalysisSheetState extends State<AyahAnalysisSheet> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _ayahs =
      []; // {id, number, surahNumber, surahEnglishName}
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
    final enrichedAyahs = await QuranDatabase().getAyahsForPlanUnit(
      unitType: widget.unitType,
      unitId: widget.unitId,
    );
    _ayahs = enrichedAyahs;
    await _refreshMistakes();
  }

  Future<void> _refreshMistakes() async {
    bool wasEmpty = _ayahs.isEmpty;
    if (wasEmpty) setState(() => _isLoading = true);

    final ids = _ayahs.map((e) => e['id'] as int).toList();
    final allNotes = await PlannerDatabase().getNotesForAyahs(ids);

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
      notes.sort((a, b) {
        final dateCompare = a.createdAt.compareTo(b.createdAt);
        if (dateCompare != 0) return dateCompare;
        return (a.id ?? 0).compareTo(b.id ?? 0);
      });

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
        return LiquidGlass(
          padding: EdgeInsets.zero,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          blur: 20,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF1A2E4D), AppColors.backgroundDark]
                : [const Color(0xFFF2F7FF), AppColors.backgroundLight],
          ),
          tint: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.64),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: LiquidGlass(
                  padding: const EdgeInsets.all(16),
                  borderRadius: BorderRadius.circular(18),
                  blur: 14,
                  tint: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.white.withValues(alpha: 0.7),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : AppColors.dividerLight,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
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
                                        : const Color(0xFF4D6380),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          LiquidGlass(
                            padding: const EdgeInsets.all(3),
                            borderRadius: BorderRadius.circular(11),
                            blur: 10,
                            tint: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.white.withValues(alpha: 0.7),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white10
                                  : AppColors.primaryNavy.withValues(
                                      alpha: 0.1,
                                    ),
                            ),
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
                                const SizedBox(width: 4),
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
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildLegendItem(AyahColor.mastered, "0"),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _ayahs
                              .fold<Map<int, List<Map<String, dynamic>>>>({}, (
                                map,
                                ayah,
                              ) {
                                final surahNum = ayah['surahNumber'] as int;
                                map.putIfAbsent(surahNum, () => []).add(ayah);
                                return map;
                              })
                              .entries
                              .map((entry) {
                                final ayahs = entry.value;
                                final surahName =
                                    ayahs.first['surahArabicName'] as String;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (widget.unitType != PlanUnitType.surah)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                          top: 4,
                                        ),
                                        child: Text(
                                          surahName,
                                          style: TextStyle(
                                            fontFamily: "QuranFont",
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black87,
                                          ),
                                        ),
                                      ),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 8,
                                      children: ayahs.map((ayah) {
                                        final id = ayah['id'] as int;
                                        final number =
                                            ayah['ayahNumber'] as int;
                                        final sNum = ayah['surahNumber'] as int;
                                        final sName =
                                            ayah['surahArabicName'] as String;

                                        final color = _getAyahColor(id, isDark);
                                        Color pillBackground;
                                        Color borderColor;
                                        Color textColor;

                                        if (color == Colors.transparent) {
                                          pillBackground = isDark
                                              ? Colors.white10
                                              : const Color(0xFFE9EFFA);
                                          borderColor = isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.22,
                                                )
                                              : const Color(0xFF9DB3CC);
                                          textColor = isDark
                                              ? Colors.white70
                                              : Colors.black87;
                                        } else {
                                          pillBackground = isDark
                                              ? color.withValues(alpha: 0.42)
                                              : color.withValues(alpha: 0.24);
                                          borderColor = isDark
                                              ? color.withValues(alpha: 0.95)
                                              : color.withValues(alpha: 0.64);
                                          textColor =
                                              ThemeData.estimateBrightnessForColor(
                                                    pillBackground,
                                                  ) ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : Colors.black87;
                                        }

                                        return InkWell(
                                          onTap: () async {
                                            if (_isReadMode) {
                                              openQuranLink(sNum, number);
                                              return;
                                            }
                                            bool hasChanges = false;
                                            await showModalBottomSheet(
                                              context: context,
                                              isScrollControlled: true,
                                              backgroundColor:
                                                  Colors.transparent,
                                              builder: (context) =>
                                                  _AyahHistorySheet(
                                                    surahNumber: sNum,
                                                    surahName: sName,
                                                    ayahNumber: number,
                                                    initialNotes:
                                                        _ayahNotes[id] ?? [],
                                                    onDeleteNote:
                                                        (int noteId) async {
                                                          await PlannerDatabase()
                                                              .deleteTaskNote(
                                                                noteId,
                                                              );
                                                          hasChanges = true;
                                                        },
                                                  ),
                                            );
                                            if (hasChanges) {
                                              _refreshMistakes();
                                            }
                                          },
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: SizedBox(
                                            width: 44,
                                            height: 28,
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 180,
                                              ),
                                              curve: Curves.easeOut,
                                              decoration: BoxDecoration(
                                                color: pillBackground,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: borderColor,
                                                ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  "$number",
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: textColor,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                );
                              })
                              .toList(),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LiquidGlass(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      borderRadius: BorderRadius.circular(999),
      blur: 8,
      tint: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.7),
      border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF3F5876),
            ),
          ),
        ],
      ),
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
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 10 : 8,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                    ? Colors.white.withValues(alpha: 0.24)
                    : Colors.white.withValues(alpha: 0.92))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? (isDark
                      ? Colors.white.withValues(alpha: 0.22)
                      : AppColors.primaryNavy.withValues(alpha: 0.16))
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? (isDark ? Colors.white : AppColors.primaryNavy)
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            if (isSelected) const SizedBox(width: 5),
            if (isSelected)
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.primaryNavy,
                ),
              ),
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

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: LiquidGlass(
        padding: const EdgeInsets.all(24),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        blur: 20,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF1D3253), AppColors.backgroundDark]
              : [const Color(0xFFF3F8FF), AppColors.backgroundLight],
        ),
        tint: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.66),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[350],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
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
                SizedBox(
                  width: 40,
                  height: 40,
                  child: LiquidGlass(
                    padding: EdgeInsets.zero,
                    borderRadius: BorderRadius.circular(12),
                    blur: 10,
                    tint: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.white.withValues(alpha: 0.7),
                    border: Border.all(
                      color: isDark
                          ? Colors.white10
                          : AppColors.primaryNavy.withValues(alpha: 0.12),
                    ),
                    child: IconButton(
                      onPressed: () =>
                          openQuranLink(widget.surahNumber, widget.ayahNumber),
                      icon: Icon(
                        Icons.menu_book_rounded,
                        color: isDark ? Colors.white : AppColors.primaryNavy,
                      ),
                    ),
                  ),
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
                            color: AppColors.successGreen.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.noMistakesRecorded,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
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
      ),
    );
  }
}
