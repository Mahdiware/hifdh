import 'package:flutter/material.dart';
import 'package:hifdh/shared/models/plan_task.dart';
import 'package:hifdh/core/services/planner_database.dart';
import 'package:hifdh/core/services/quran_database.dart';
import 'package:hifdh/core/theme/app_colors.dart';
import 'package:hifdh/shared/widgets/collapsible_note_card.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';
import 'package:hifdh/features/progress/widgets/ayah_analysis_sheet.dart';

class UnitDetailsSheet extends StatefulWidget {
  final PlanUnitType type;
  final int unitId;
  final String title;
  final List<TaskNote>? preloadedNotes;

  const UnitDetailsSheet({
    super.key,
    required this.type,
    required this.unitId,
    required this.title,
    this.preloadedNotes,
  });

  @override
  State<UnitDetailsSheet> createState() => _UnitDetailsSheetState();
}

class _UnitDetailsSheetState extends State<UnitDetailsSheet> {
  late Future<List<TaskNote>> _notesFuture;
  Future<List<Map<String, dynamic>>>? _breakdownFuture;

  Future<List<Map<String, dynamic>>> _fetchBreakdown() async {
    try {
      final quranDb = QuranDatabase();
      final unitAyahs = await quranDb.getAyahsForPlanUnit(
        unitType: widget.type,
        unitId: widget.unitId,
      );

      if (unitAyahs.isEmpty) return [];

      final surahMap = <int, Map<String, dynamic>>{};

      // Fetch memorized IDs
      final memorizedIds = await PlannerDatabase().getMemorizedAyahIds();
      final memorizedSet = memorizedIds.toSet();

      for (final ayah in unitAyahs) {
        final sNum = ayah['surahNumber'] as int;
        final id = ayah['id'] as int;
        final ayahNum = ayah['ayahNumber'] as int;

        if (!surahMap.containsKey(sNum)) {
          surahMap[sNum] = {
            'number': sNum,
            'englishName': ayah['surahEnglishName'],
            'arabicName': ayah['surahArabicName'],
            'totalAyahs': 0,
            'memorizedCount': 0,
            'minAyah': ayahNum,
            'maxAyah': ayahNum,
          };
        }
        final data = surahMap[sNum]!;
        data['totalAyahs'] = (data['totalAyahs'] as int) + 1;

        if (ayahNum < (data['minAyah'] as int)) {
          data['minAyah'] = ayahNum;
        }
        if (ayahNum > (data['maxAyah'] as int)) {
          data['maxAyah'] = ayahNum;
        }

        if (memorizedSet.contains(id)) {
          data['memorizedCount'] = (data['memorizedCount'] as int) + 1;
        }
      }

      final list = surahMap.values.toList()
        ..sort((a, b) => (a['number'] as int).compareTo(b['number'] as int));
      return list;
    } catch (e) {
      debugPrint("Error loading breakdown: $e");
      return [];
    }
  }

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _breakdownFuture = _fetchBreakdown();
  }

  void _loadNotes() {
    if (widget.preloadedNotes != null) {
      _notesFuture = Future.value(
        widget.preloadedNotes!
            .where((n) => n.type != NoteType.correct)
            .toList(),
      );
    } else {
      _notesFuture = PlannerDatabase()
          .getNotesForUnit(widget.type, widget.unitId)
          .then(
            (notes) => notes.where((n) => n.type != NoteType.correct).toList(),
          );
    }
  }

  Future<void> _deleteNote(int id) async {
    await PlannerDatabase().deleteTaskNote(id);
    if (mounted) {
      setState(() {
        _notesFuture = PlannerDatabase().getNotesForUnit(
          widget.type,
          widget.unitId,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    String typeName;
    switch (widget.type) {
      case PlanUnitType.surah:
        typeName = l10n.surah;
        break;
      case PlanUnitType.juz:
        typeName = l10n.juz;
        break;
      case PlanUnitType.page:
        typeName = l10n.page;
        break;
      default:
        typeName = "Custom";
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return FutureBuilder<List<TaskNote>>(
          future: _notesFuture,
          builder: (context, snapshot) {
            return ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      "$typeName ${l10n.progressAndNotes}",
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Stats Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            context,
                            l10n.total,
                            "${snapshot.data?.length ?? 0}",
                            Colors.blue,
                            Icons.list_alt_rounded,
                            isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            context,
                            l10n.mistake,
                            "${snapshot.data?.where((n) => n.type == NoteType.mistake).length ?? 0}",
                            AppColors.errorRed,
                            Icons.cancel_outlined,
                            isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            context,
                            l10n.doubt,
                            "${snapshot.data?.where((n) => n.type == NoteType.doubt).length ?? 0}",
                            const Color(0xFFFFB74D), // Soft Orange
                            Icons.help_outline_rounded,
                            isDark,
                          ),
                        ),
                      ],
                    ),

                    if (widget.type == PlanUnitType.surah ||
                        widget.type == PlanUnitType.juz ||
                        widget.type == PlanUnitType.hizb) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => AyahAnalysisSheet(
                                unitType: widget.type,
                                unitId: widget.unitId,
                                title: widget.title,
                              ),
                            );
                          },
                          icon: const Icon(Icons.analytics_outlined),
                          label: Text(l10n.mistakesAnalysis),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(
                              color: isDark
                                  ? AppColors.accentOrange
                                  : AppColors.primaryNavy,
                            ),
                            foregroundColor: isDark
                                ? AppColors.accentOrange
                                : AppColors.primaryNavy,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],

                    if (_breakdownFuture != null)
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: _breakdownFuture,
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          if (!snap.hasData || snap.data!.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 24),
                              Text(
                                l10n.juzContents,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.primaryNavy,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...snap.data!.map((data) {
                                final total = data['totalAyahs'] as int;
                                final memorized = data['memorizedCount'] as int;
                                final progress = total > 0
                                    ? memorized / total
                                    : 0.0;
                                final isComplete = progress >= 0.99;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white10
                                        : Colors.grey[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white12
                                          : Colors.grey[200]!,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.black26
                                              : Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isComplete
                                                ? AppColors.successGreen
                                                : (isDark
                                                      ? Colors.white24
                                                      : Colors.grey[300]!),
                                          ),
                                        ),
                                        child: isComplete
                                            ? const Icon(
                                                Icons.check,
                                                size: 16,
                                                color: AppColors.successGreen,
                                              )
                                            : Text(
                                                "${data['number']}",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark
                                                      ? Colors.white70
                                                      : Colors.grey[600],
                                                ),
                                              ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "${data['englishName']} (${l10n.ayah} ${data['minAyah']} - ${data['maxAyah']})",
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                              child: LinearProgressIndicator(
                                                value: progress,
                                                minHeight: 4,
                                                backgroundColor: isDark
                                                    ? Colors.black26
                                                    : Colors.grey[200],
                                                color: isComplete
                                                    ? AppColors.successGreen
                                                    : AppColors.accentOrange,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        "${(progress * 100).toInt()}%",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: isComplete
                                              ? AppColors.successGreen
                                              : AppColors.accentOrange,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          );
                        },
                      ),

                    const SizedBox(height: 24),
                    // Notes Section Header
                    Row(
                      children: [
                        Icon(
                          Icons.sticky_note_2_outlined,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.primaryNavy,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.notesHistory,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.primaryNavy,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (!snapshot.hasData || snapshot.data!.isEmpty)
                      _buildEmptyNotesState(isDark)
                    else
                      ...snapshot.data!.map(
                        (note) => CollapsibleNoteCard(
                          note: note,
                          onDelete: () => _deleteNote(note.id!),
                        ),
                      ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryNavy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(l10n.close),
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyNotesState(bool isDark) {
    return Builder(
      builder: (context) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.backgroundDark
                : AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.transparent : AppColors.dividerLight,
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.notes,
                size: 40,
                color: AppColors.textSecondaryLight.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.noNotesRecordedYet,
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String count,
    Color color,
    IconData icon,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
