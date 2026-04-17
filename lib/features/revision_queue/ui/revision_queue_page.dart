import 'package:flutter/material.dart';
import 'package:hifdh/core/services/planner_database.dart';
import 'package:hifdh/core/theme/app_background.dart';
import 'package:hifdh/core/theme/app_colors.dart';
import 'package:hifdh/features/revision_queue/ui/revision_session_page.dart';
import 'package:hifdh/features/settings/logic/preferences_provider.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';
import 'package:hifdh/shared/models/plan_task.dart';
import 'package:provider/provider.dart';

enum RevisionQueueFilter { due, weak, mastered, all }

enum RevisionQueueSort { highest, oldest }

class RevisionQueuePage extends StatefulWidget {
  const RevisionQueuePage({super.key});

  @override
  State<RevisionQueuePage> createState() => _RevisionQueuePageState();
}

class _RevisionQueuePageState extends State<RevisionQueuePage> {
  bool _isLoading = true;
  int? _processingAyahId;
  List<Map<String, dynamic>> _queueItems = [];
  Map<String, int> _summary = const {
    'due': 0,
    'weak': 0,
    'mastered': 0,
    'total': 0,
  };
  RevisionQueueFilter _filter = RevisionQueueFilter.due;
  RevisionQueueSort _sort = RevisionQueueSort.highest;

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  String _filterValue(RevisionQueueFilter filter) {
    switch (filter) {
      case RevisionQueueFilter.weak:
        return 'weak';
      case RevisionQueueFilter.mastered:
        return 'mastered';
      case RevisionQueueFilter.all:
        return 'all';
      case RevisionQueueFilter.due:
        return 'due';
    }
  }

  String _sortValue(RevisionQueueSort sort) {
    switch (sort) {
      case RevisionQueueSort.oldest:
        return 'oldest';
      case RevisionQueueSort.highest:
        return 'highest';
    }
  }

  Future<void> _loadQueue({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _isLoading = true);
    }

    try {
      final prefs = context.read<PreferencesProvider>();
      final dailyTarget = prefs.revisionQueueDailyTarget;
      final includeMastered =
          _filter == RevisionQueueFilter.mastered ||
          _filter == RevisionQueueFilter.all ||
          prefs.revisionQueueIncludeMastered;
      final requestedLimit = _filter == RevisionQueueFilter.all
          ? (dailyTarget * 2).clamp(10, 200)
          : dailyTarget;

      final data = await Future.wait([
        PlannerDatabase().getRevisionQueue(
          limit: requestedLimit,
          includeMastered: includeMastered,
          filter: _filterValue(_filter),
          sort: _sortValue(_sort),
        ),
        PlannerDatabase().getRevisionQueueSummary(includeMastered: true),
      ]);

      if (!mounted) return;

      setState(() {
        _queueItems = data[0] as List<Map<String, dynamic>>;
        _summary = data[1] as Map<String, int>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load queue: $e')));
    }
  }

  String _reasonLabel(AppLocalizations l10n, String reason) {
    if (reason == 'not_memorized') {
      return l10n.queueReasonNotMemorized;
    }
    if (reason == 'maintenance') {
      return l10n.queueReasonMaintenance;
    }
    if (reason.startsWith('mistakes:')) {
      final count = int.tryParse(reason.split(':').last) ?? 0;
      return l10n.queueReasonMistakes(count);
    }
    if (reason.startsWith('doubts:')) {
      final count = int.tryParse(reason.split(':').last) ?? 0;
      return l10n.queueReasonDoubts(count);
    }
    if (reason.startsWith('days_since:')) {
      final days = int.tryParse(reason.split(':').last) ?? 0;
      return l10n.queueReasonDays(days);
    }
    if (reason.startsWith('last_result:')) {
      return l10n.queueReasonLastNeedsWork;
    }
    return reason;
  }

  Future<String?> _showOptionalNoteDialog(AppLocalizations l10n) async {
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
              hintText: l10n.descriptionOptional,
              border: const OutlineInputBorder(),
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

  Future<void> _recordOutcome(
    Map<String, dynamic> item,
    NoteType outcome,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final ayahId = (item['ayahId'] as num?)?.toInt() ?? 0;
    if (ayahId <= 0) return;

    String note = '';
    if (outcome != NoteType.correct) {
      final noteResult = await _showOptionalNoteDialog(l10n);
      if (noteResult == null) return;
      note = noteResult;
    }

    setState(() => _processingAyahId = ayahId);

    try {
      await PlannerDatabase().recordRevisionQueueOutcome(
        ayahId: ayahId,
        outcome: outcome,
        note: note,
      );

      if (!mounted) return;

      final message = switch (outcome) {
        NoteType.correct => l10n.queueMarkedCorrect,
        NoteType.doubt => l10n.queueMarkedDoubt,
        NoteType.mistake => l10n.queueMarkedMistake,
      };

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));

      await _loadQueue(showLoading: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorWithMessage(e.toString()))),
      );
    } finally {
      if (mounted) {
        setState(() => _processingAyahId = null);
      }
    }
  }

  Future<void> _openSessionMode() async {
    final l10n = AppLocalizations.of(context)!;
    if (_queueItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.queueNoItems)));
      return;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => RevisionSessionPage(initialQueue: _queueItems),
      ),
    );

    if (result == true && mounted) {
      await _loadQueue(showLoading: false);
    }
  }

  Widget _buildSummaryChip({
    required String label,
    required int value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildQueueCard(Map<String, dynamic> item, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    final ayahId = (item['ayahId'] as num?)?.toInt() ?? 0;
    final reasons = (item['reasons'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList();
    final surahNumber = (item['surahNumber'] as num?)?.toInt() ?? 0;
    final ayahNumber = (item['ayahNumber'] as num?)?.toInt() ?? 0;
    final surahName = (item['surahArabicName'] as String?) ?? '';
    final text = (item['ayahText'] as String?) ?? '';
    final score = (item['priorityScore'] as num?)?.toDouble() ?? 0;
    final daysSince = (item['daysSinceReview'] as num?)?.toInt() ?? 0;
    final mistakes = (item['mistakeCount'] as num?)?.toInt() ?? 0;
    final doubts = (item['doubtCount'] as num?)?.toInt() ?? 0;
    final revisions = (item['revisions'] as num?)?.toInt() ?? 0;

    final busy = _processingAyahId == ayahId;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryNavy.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$surahNumber:$ayahNumber',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    surahName.isEmpty ? l10n.unknown : surahName,
                    style: const TextStyle(
                      fontFamily: 'QuranFont',
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  score.toStringAsFixed(1),
                  style: TextStyle(
                    color: isDark ? Colors.orange[200] : AppColors.accentOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (text.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                text,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontSize: 17,
                  fontFamily: 'QuranFont',
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMiniTag(l10n.queueReasonDays(daysSince), isDark),
                _buildMiniTag('${l10n.revisionsShort}: $revisions', isDark),
                _buildMiniTag('${l10n.mistake}: $mistakes', isDark),
                _buildMiniTag('${l10n.doubt}: $doubts', isDark),
              ],
            ),
            if (reasons.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: reasons
                    .map(
                      (reason) => _buildReasonTag(_reasonLabel(l10n, reason)),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => _recordOutcome(item, NoteType.mistake),
                    icon: const Icon(Icons.close, size: 18),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    label: Text(l10n.mistake),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => _recordOutcome(item, NoteType.doubt),
                    icon: const Icon(Icons.help_outline, size: 18),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accentOrange,
                    ),
                    label: Text(l10n.doubt),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: busy
                        ? null
                        : () => _recordOutcome(item, NoteType.correct),
                    icon: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: Text(l10n.correct),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniTag(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white70 : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildReasonTag(String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildQueueHeroCard(
    AppLocalizations l10n,
    bool isDark,
    int queueTarget,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final due = _summary['due'] ?? 0;
    final weak = _summary['weak'] ?? 0;
    final mastered = _summary['mastered'] ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withValues(alpha: 0.2),
            colorScheme.tertiary.withValues(alpha: 0.18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.auto_graph_rounded, color: colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.revisionQueueTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${l10n.queueDue}: $due  •  ${l10n.queueWeak}: $weak  •  ${l10n.queueMastered}: $mastered',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.queueDailyTarget(queueTarget),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final prefs = context.watch<PreferencesProvider>();
    final queueTarget = prefs.revisionQueueDailyTarget;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        scrolledUnderElevation: 0,
        title: Text(l10n.revisionQueueTitle),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              tooltip: l10n.queueStartSession,
              onPressed: _openSessionMode,
              icon: const Icon(Icons.play_circle_outline_rounded),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () => _loadQueue(showLoading: false),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: AppBackground.pageDecoration(theme),
        child: RefreshIndicator(
          onRefresh: () => _loadQueue(showLoading: false),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildQueueHeroCard(l10n, isDark, queueTarget),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildSummaryChip(
                    label: l10n.queueDue,
                    value: _summary['due'] ?? 0,
                    color: const Color(0xFFE65100),
                  ),
                  _buildSummaryChip(
                    label: l10n.queueWeak,
                    value: _summary['weak'] ?? 0,
                    color: const Color(0xFFC62828),
                  ),
                  _buildSummaryChip(
                    label: l10n.queueMastered,
                    value: _summary['mastered'] ?? 0,
                    color: const Color(0xFF2E7D32),
                  ),
                  _buildSummaryChip(
                    label: l10n.total,
                    value: _summary['total'] ?? 0,
                    color: AppColors.primaryNavy,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<RevisionQueueFilter>(
                        key: ValueKey('queue-filter-${_filter.name}'),
                        initialValue: _filter,
                        decoration: InputDecoration(labelText: l10n.filter),
                        items: [
                          DropdownMenuItem(
                            value: RevisionQueueFilter.due,
                            child: Text(l10n.queueDue),
                          ),
                          DropdownMenuItem(
                            value: RevisionQueueFilter.weak,
                            child: Text(l10n.queueWeak),
                          ),
                          DropdownMenuItem(
                            value: RevisionQueueFilter.mastered,
                            child: Text(l10n.queueMastered),
                          ),
                          DropdownMenuItem(
                            value: RevisionQueueFilter.all,
                            child: Text(l10n.all),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _filter = value);
                          _loadQueue(showLoading: false);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<RevisionQueueSort>(
                        key: ValueKey('queue-sort-${_sort.name}'),
                        initialValue: _sort,
                        decoration: InputDecoration(labelText: l10n.sort),
                        items: [
                          DropdownMenuItem(
                            value: RevisionQueueSort.highest,
                            child: Text(l10n.queueHighestPriority),
                          ),
                          DropdownMenuItem(
                            value: RevisionQueueSort.oldest,
                            child: Text(l10n.queueOldestFirst),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _sort = value);
                          _loadQueue(showLoading: false);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_queueItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: Center(
                    child: Text(
                      l10n.queueNoItems,
                      style: TextStyle(
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                  ),
                )
              else
                ..._queueItems.map((item) => _buildQueueCard(item, isDark)),
            ],
          ),
        ),
      ),
    );
  }
}
