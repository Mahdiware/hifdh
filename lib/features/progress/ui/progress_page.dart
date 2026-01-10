import 'package:flutter/material.dart';
import 'package:hifdh/core/services/planner_database_helper.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';
import 'package:hifdh/shared/models/plan_task.dart';
import 'package:hifdh/shared/models/surah.dart';
import 'package:hifdh/core/services/database_helper.dart';
import 'package:hifdh/core/theme/app_colors.dart';
import 'package:hifdh/core/utils/progress_chart_helper.dart';
import 'package:hifdh/features/progress/widgets/activity_chart.dart';
import 'package:hifdh/features/progress/widgets/progress_header_card.dart';
import 'package:hifdh/features/progress/widgets/unit_details_sheet.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Data State
  bool _isLoading = true;
  double _memPercentage = 0.0;
  List<QuranProgress> _surahProgress = [];
  List<Surah> _surahs = [];
  List<Map<String, dynamic>> _chartData = [];
  Map<String, int> _overallStats = {'total': 0, 'completed': 0, 'pending': 0};

  // Active tasks to map to Juz/Hizb
  List<PlanTask> _activeTasks = [];

  // Chart Range
  int _selectedStatRange = 7;

  // Cache for Juz -> Surahs mapping
  final Map<int, List<int>> _juzSurahMap = {};

  // Page Coverage for granular calculation
  List<bool> _pageCoverage = [];
  Map<int, double> _surahExactProgress =
      {}; // Computed granular progress per Surah

  // Cache for Juz Page Ranges
  final Map<int, Map<String, int>> _juzPageRanges = {};
  // Cache for Surah Page Ranges
  final Map<int, Map<String, int>> _surahPageRanges = {};

  // Note Caches
  Map<int, List<TaskNote>> _surahNotes = {};
  Map<int, List<TaskNote>> _juzNotes = {};
  Map<int, List<TaskNote>> _hizbNotes = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    // Listen for data changes from other tabs
    PlannerDatabaseHelper().dataUpdateNotifier.addListener(_loadData);
  }

  @override
  void dispose() {
    PlannerDatabaseHelper().dataUpdateNotifier.removeListener(_loadData);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Parallel fetch Basic Data
      final basicFutures = await Future.wait([
        PlannerDatabaseHelper().getMemorizedPercentage(),
        PlannerDatabaseHelper().getAllSurahProgress(),
        DatabaseHelper().getAllSurahs(),
        PlannerDatabaseHelper().getCompletionStats(
          days: _selectedStatRange,
        ), // Use selected range
        PlannerDatabaseHelper().getStats(),
        PlannerDatabaseHelper().getActiveTasks(),
      ]);

      // Fetch Juz Mappings (Parallel 30 queries)
      // Only if not loaded? Nah, load always for now to be safe or check cache.
      if (_juzSurahMap.isEmpty) {
        final juzFutures = await Future.wait(
          List.generate(30, (i) => DatabaseHelper().getSurahsInJuz(i + 1)),
        );
        for (int i = 0; i < 30; i++) {
          _juzSurahMap[i + 1] = juzFutures[i];
        }
      }

      // Fetch Page Coverage and Juz/Surah Ranges
      final coverageFuture = PlannerDatabaseHelper().getGlobalPageCoverage();
      final ayahsFuture = PlannerDatabaseHelper().getGlobalCoveredAyahs();
      final metaFuture = DatabaseHelper().getAllQuranMeta();

      if (_juzPageRanges.isEmpty) {
        final rangeFutures = await Future.wait(
          List.generate(30, (i) => DatabaseHelper().getJuzPageRange(i + 1)),
        );
        for (int i = 0; i < 30; i++) {
          _juzPageRanges[i + 1] = rangeFutures[i];
        }
      }

      if (_surahPageRanges.isEmpty) {
        final surahRanges = await DatabaseHelper().getAllSurahPageRanges();
        for (var r in surahRanges) {
          _surahPageRanges[r['surahNumber']!] = r;
        }
      }

      final coverage = await coverageFuture;
      final coveredAyahs = await ayahsFuture;
      final quranMeta = await metaFuture;

      // Fetch and Map Notes
      final allNotes = await PlannerDatabaseHelper().getAllNotesWithTasks();
      final metaMap = {for (var m in quranMeta) m['id'] as int: m};

      final sNotes = <int, List<TaskNote>>{};
      final jNotes = <int, List<TaskNote>>{};
      final hNotes = <int, List<TaskNote>>{};

      for (var row in allNotes) {
        final note = TaskNote.fromMap(row);

        if (note.ayahId != null && metaMap.containsKey(note.ayahId)) {
          final m = metaMap[note.ayahId]!;
          final surah = m['surahNumber'] as int;
          final juz = m['juzNumber'] as int;
          final rub = m['rubNumber'] as int;
          final hizb = ((rub - 1) ~/ 4) + 1;

          sNotes.putIfAbsent(surah, () => []).add(note);
          jNotes.putIfAbsent(juz, () => []).add(note);
          hNotes.putIfAbsent(hizb, () => []).add(note);
        } else {
          final uTypeVal = row['unitType'] as int;
          final uId = row['unitId'] as int;
          final uType = PlanUnitType.values[uTypeVal];

          if (uType == PlanUnitType.surah) {
            sNotes.putIfAbsent(uId, () => []).add(note);
          } else if (uType == PlanUnitType.juz) {
            jNotes.putIfAbsent(uId, () => []).add(note);
          }
        }
      }

      // Compute Granular Progress per Surah
      final Map<int, double> granularProgress = {};
      final Map<int, List<int>> surahAyahIds = {};
      for (final m in quranMeta) {
        final s = m['surahNumber'] as int;
        surahAyahIds.putIfAbsent(s, () => []).add(m['id'] as int);
      }

      for (final s in surahAyahIds.keys) {
        final ids = surahAyahIds[s]!;
        final total = ids.length;
        final soFar = ids.where((id) => coveredAyahs.contains(id)).length;
        granularProgress[s] = total == 0 ? 0.0 : soFar / total;
      }

      if (mounted) {
        setState(() {
          _memPercentage = basicFutures[0] as double;
          _surahProgress = basicFutures[1] as List<QuranProgress>;
          _surahs = basicFutures[2] as List<Surah>;
          _chartData = ProgressChartHelper.normalizeChartData(
            basicFutures[3] as List<Map<String, dynamic>>,
            _selectedStatRange,
          );
          _overallStats = basicFutures[4] as Map<String, int>;
          _activeTasks = basicFutures[5] as List<PlanTask>;
          _pageCoverage = coverage;
          _surahExactProgress = granularProgress;
          _surahNotes = sNotes;
          _juzNotes = jNotes;
          _hizbNotes = hNotes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading progress: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _calculateSurahProgress(int surahNum) {
    return _surahExactProgress[surahNum] ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxScrolled) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProgressHeaderCard(
                      memPercentage: _memPercentage,
                      overallStats: _overallStats,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    ActivityChart(
                      chartData: _chartData,
                      selectedStatRange: _selectedStatRange,
                      onRangeChanged: (val) => _updateChartRange(val),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: isDark
                      ? AppColors.accentOrange
                      : AppColors.primaryNavy,
                  unselectedLabelColor: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  indicatorColor: isDark
                      ? AppColors.accentOrange
                      : AppColors.primaryNavy,
                  indicatorWeight: 3,
                  tabs: [
                    Tab(text: AppLocalizations.of(context)!.surah),
                    Tab(text: AppLocalizations.of(context)!.juz),
                    Tab(text: AppLocalizations.of(context)!.hizb),
                  ],
                ),
                isDark,
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildSurahList(isDark),
            _buildJuzList(isDark),
            _buildHizbList(isDark),
          ],
        ),
      ),
    );
  }

  Future<void> _updateChartRange(int days) async {
    setState(() => _selectedStatRange = days);
    final raw = await PlannerDatabaseHelper().getCompletionStats(days: days);
    if (mounted) {
      setState(() {
        _chartData = ProgressChartHelper.normalizeChartData(raw, days);
      });
    }
  }

  Widget _buildSurahList(bool isDark) {
    if (_surahs.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.noSurahsLoaded,
          style: TextStyle(color: Colors.grey[400]),
        ),
      );
    }

    return ListView.builder(
      itemCount: _surahs.length,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemBuilder: (context, index) {
        final surah = _surahs[index];
        final progress = _surahProgress.firstWhere(
          (p) => p.unitId == surah.number,
          orElse: () => QuranProgress(
            unitId: surah.number,
            isMemorized: false,
            revisionCount: 0,
          ),
        );

        // Find any active tasks for this Surah
        final activeTask = _activeTasks.firstWhere(
          (t) => t.unitType == PlanUnitType.surah && t.unitId == surah.number,
          orElse: () => PlanTask(
            id: -1,
            unitType: PlanUnitType.surah,
            unitId: 0,
            title: '',
            type: TaskType.memorize,
            deadline: DateTime.now(),
            createdAt: DateTime.now(),
          ),
        );
        final hasActive = activeTask.id != -1;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark
                  ? Colors.transparent
                  : AppColors.dividerLight.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 4,
                  bottom: 4,
                ),
                leading: Builder(
                  builder: (context) {
                    final pct = _calculateSurahProgress(surah.number);
                    final isFull = progress.isMemorized || pct >= 0.999;

                    if (isFull) {
                      return Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.successGreen,
                              AppColors.successGreenDark,
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 20,
                        ),
                      );
                    } else if (pct > 0.0) {
                      // Partial progress indicator
                      return SizedBox(
                        width: 42,
                        height: 42,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: pct,
                              backgroundColor: isDark
                                  ? Colors.white10
                                  : Colors.grey.withValues(alpha: 0.1),
                              color: AppColors.accentOrange,
                              strokeWidth: 3,
                            ),
                            Text(
                              "${(pct * 100).toInt()}%",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      // Normal Number
                      return Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? AppColors.backgroundDark
                              : AppColors.backgroundLight,
                        ),
                        child: Text(
                          "${surah.number}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      );
                    }
                  },
                ),
                title: Text(
                  surah.englishName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: hasActive
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.accentOrange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              AppLocalizations.of(context)!.inProgress,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.accentOrange,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Text(
                        surah.name,
                        style: TextStyle(
                          fontFamily: "QuranFont",
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (progress.revisionCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentOrange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "${progress.revisionCount} ${AppLocalizations.of(context)!.revisionsShort}",
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentOrange,
                          ),
                        ),
                      ),
                  ],
                ),
                onTap: () {
                  _showUnitDetails(
                    context,
                    PlanUnitType.surah,
                    surah.number,
                    "${AppLocalizations.of(context)!.surah} ${surah.englishName}",
                    preloadedNotes: _surahNotes[surah.number],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildJuzList(bool isDark) {
    return ListView.builder(
      itemCount: 30,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final juzNum = index + 1;

        // 1. Tasks explicitly for this Juz (Revision/Memorization)
        final explicitJuzTasks = _activeTasks.where(
          (t) => t.unitType == PlanUnitType.juz && t.unitId == juzNum,
        );

        // 2. Tasks for Surahs contained in this Juz
        final surahsInJuz = _juzSurahMap[juzNum] ?? [];
        final surahTasks = _activeTasks.where(
          (t) =>
              t.unitType == PlanUnitType.surah &&
              surahsInJuz.contains(t.unitId),
        );

        // 3. Tasks for Hizbs in this Juz (Hizb 2*juz -1, 2*juz)
        // Subtitle text matching is loose but matches user intent "Hizb 1 and Hizb 2"
        final hizb1 = (juzNum * 2) - 1;
        final hizb2 = (juzNum * 2);

        final hizbTasks = _activeTasks.where((t) {
          final sub = t.subtitle?.toLowerCase() ?? "";
          return sub.contains("hizb $hizb1") || sub.contains("hizb $hizb2");
        });

        // Combined Active Tasks
        final allActive = [...explicitJuzTasks, ...surahTasks, ...hizbTasks];
        // Deduplicate by ID
        final uniqueActive = <int, PlanTask>{};
        for (var t in allActive) {
          if (t.id != null) uniqueActive[t.id!] = t;
        }
        final displayTasks = uniqueActive.values.toList();

        // Determine Juz Progress from Page Coverage
        final range = _juzPageRanges[juzNum];
        double estimatedProg = 0.0;
        bool isFullyMemorized = false;

        if (range != null && _pageCoverage.isNotEmpty) {
          int start = range['startPage']!;
          int end = range['endPage']!;
          int total = end - start + 1;
          int coveredCount = 0;

          // Validate range against coverage array size (605)
          if (total > 0 && start > 0 && end < _pageCoverage.length) {
            for (int p = start; p <= end; p++) {
              if (_pageCoverage[p]) coveredCount++;
            }
            estimatedProg = coveredCount / total;
            isFullyMemorized = estimatedProg >= 0.99; // Tolerance
          }
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark
                  ? Colors.transparent
                  : AppColors.dividerLight.withValues(alpha: 0.5),
            ),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isFullyMemorized
                      ? const LinearGradient(
                          colors: [
                            AppColors.successGreen,
                            AppColors.successGreenDark,
                          ],
                        )
                      : null,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (!isFullyMemorized)
                      CircularProgressIndicator(
                        value: estimatedProg,
                        strokeWidth: 3,
                        color: AppColors.accentOrange,
                        backgroundColor: isDark
                            ? AppColors.dividerDark
                            : AppColors.dividerLight,
                      )
                    else
                      const Icon(Icons.check, color: Colors.white, size: 24),

                    if (!isFullyMemorized)
                      Text(
                        "$juzNum",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                  ],
                ),
              ),
              title: Text(
                "${AppLocalizations.of(context)!.juz} $juzNum",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: displayTasks.isNotEmpty
                  ? Text(
                      "${displayTasks.length} ${AppLocalizations.of(context)!.activeTasks}",
                      style: const TextStyle(color: AppColors.accentOrange),
                    )
                  : Text(
                      AppLocalizations.of(
                        context,
                      )!.percentMemorized((estimatedProg * 100).toInt()),
                      style: TextStyle(
                        fontSize: 12,
                        color: isFullyMemorized
                            ? AppColors.successGreen
                            : (isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight),
                      ),
                    ),
              children: [
                // Option to view all notes for the Juz
                ListTile(
                  leading: const Icon(
                    Icons.history_edu,
                    size: 20,
                    color: AppColors.primaryNavy,
                  ),
                  title: Text(
                    AppLocalizations.of(context)!.viewJuzHistoryNotes,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 16),
                  dense: true,
                  onTap: () => _showUnitDetails(
                    context,
                    PlanUnitType.juz,
                    juzNum,
                    "${AppLocalizations.of(context)!.juz} $juzNum",
                    preloadedNotes: _juzNotes[juzNum],
                  ),
                ),
                if (displayTasks.isNotEmpty) const Divider(),
                ...displayTasks.map((task) {
                  return ListTile(
                    title: Text(task.title),
                    subtitle: Text(
                      task.subtitle ??
                          (task.unitType == PlanUnitType.surah
                              ? AppLocalizations.of(context)!.surahTask
                              : AppLocalizations.of(context)!.juzTask),
                    ),
                    trailing: const Icon(Icons.arrow_forward, size: 16),
                    leading: Icon(
                      Icons.task_alt,
                      size: 18,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    onTap: () {
                      // For a task, we use the specific task note viewer or the unit viewer?
                      // If user wants "task" notes specifically, we should probably stick to unit viewer
                      // but maybe we can just open Unit viewer for the task's unit.
                      // However, the task might be for a Surah inside this Juz.
                      // Let's open the Task Details directly from HistoryPage-style logic?
                      // Or reuse _showUnitDetails with the task's unit.
                      if (task.unitType == PlanUnitType.surah) {
                        _showUnitDetails(
                          context,
                          PlanUnitType.surah,
                          task.unitId,
                          task.title,
                          preloadedNotes: _surahNotes[task.unitId],
                        );
                      } else {
                        _showUnitDetails(
                          context,
                          PlanUnitType.juz,
                          task.unitId,
                          task.title,
                          preloadedNotes: _juzNotes[task.unitId],
                        );
                      }
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHizbList(bool isDark) {
    return ListView.builder(
      itemCount: 60,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final hizbNum = index + 1;

        // Match active tasks for this Hizb
        // 1. Explicit mention in subtitle
        final relevant = _activeTasks.where((t) {
          final sub = t.subtitle?.toLowerCase() ?? "";
          return sub.contains("hizb $hizbNum");
        }).toList();

        // 2. Implicit inclusion via Juz task?
        // Hizb X resides in Juz ((X-1) ~ 2) + 1
        final parentJuz = ((hizbNum - 1) ~/ 2) + 1;
        final parentJuzTasks = _activeTasks.where((t) {
          if (t.unitType != PlanUnitType.juz || t.unitId != parentJuz) {
            return false;
          }
          // Exclude partial Juz tasks (Rubuc/Hizb specific) from determining
          // "Covered by Juz" status for the whole Juz.
          // If a task is specific to a Hizb/Rubuc, it shouldn't imply the whole Juz is active.
          final sub = t.subtitle?.toLowerCase() ?? "";
          return !sub.contains("hizb") && !sub.contains("rubuc");
        }).toList();

        final hasActive = relevant.isNotEmpty || parentJuzTasks.isNotEmpty;

        // Calculate Hizb Progress
        final juzRange = _juzPageRanges[parentJuz];
        double hizbProg = 0.0;
        bool isFullyMemorized = false;

        if (juzRange != null && _pageCoverage.isNotEmpty) {
          int start = juzRange['startPage']!;
          int end = juzRange['endPage']!;

          // Approximation: Split Juz pages in half
          int mid = (start + end) ~/ 2;

          // Global Hizb 1 -> Juz 1 (First half)
          // Global Hizb 2 -> Juz 1 (Second half)
          bool isFirstInJuz = (hizbNum % 2) != 0;

          int hStart = isFirstInJuz ? start : (mid + 1);
          int hEnd = isFirstInJuz ? mid : end;

          int total = hEnd - hStart + 1;
          int coveredCount = 0;

          if (total > 0 && hStart > 0 && hEnd < _pageCoverage.length) {
            for (int p = hStart; p <= hEnd; p++) {
              if (_pageCoverage[p]) coveredCount++;
            }
            hizbProg = coveredCount / total;
            isFullyMemorized = hizbProg >= 0.99;
          }
        }
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark
                  ? Colors.transparent
                  : AppColors.dividerLight.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                leading: Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isFullyMemorized
                        ? const LinearGradient(
                            colors: [
                              AppColors.successGreen,
                              AppColors.successGreenDark,
                            ],
                          )
                        : null,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (!isFullyMemorized)
                        CircularProgressIndicator(
                          value: hizbProg,
                          strokeWidth: 3,
                          color: AppColors.accentOrange,
                          backgroundColor: isDark
                              ? AppColors.dividerDark
                              : AppColors.dividerLight,
                        )
                      else
                        const Icon(Icons.check, color: Colors.white, size: 24),

                      if (!isFullyMemorized)
                        Text(
                          "$hizbNum",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                    ],
                  ),
                ),
                title: Text(
                  "${AppLocalizations.of(context)!.hizb} $hizbNum (${AppLocalizations.of(context)!.juz} $parentJuz)",
                ),
                subtitle: hasActive
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.accentOrange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              relevant.isNotEmpty
                                  ? AppLocalizations.of(
                                      context,
                                    )!.activeTaskSingle
                                  : "${AppLocalizations.of(context)!.coveredByJuz} $parentJuz",
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.accentOrange,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Text(
                        AppLocalizations.of(
                          context,
                        )!.percentMemorized((hizbProg * 100).toInt()),
                        style: TextStyle(
                          fontSize: 12,
                          color: isFullyMemorized
                              ? AppColors.successGreen
                              : (isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight),
                        ),
                      ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ), // Always show arrow to imply tappable
                onTap: () {
                  // Hizb not directly supported in DB unit types yet,
                  // but we can map it to Juz for now or show empty notes if we don't have explicit Hizb unit type.
                  // Or better: Show notes for the Parent Juz? Or just "Coming Soon"?
                  // Let's show Parent Juz notes for context.
                  _showUnitDetails(
                    context,
                    PlanUnitType.juz,
                    parentJuz,
                    "${AppLocalizations.of(context)!.hizb} $hizbNum (${AppLocalizations.of(context)!.juz} $parentJuz)",
                    preloadedNotes: _hizbNotes[hizbNum],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showUnitDetails(
    BuildContext context,
    PlanUnitType type,
    int unitId,
    String title, {
    List<TaskNote>? preloadedNotes,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return UnitDetailsSheet(
          type: type,
          unitId: unitId,
          title: title,
          preloadedNotes: preloadedNotes,
        );
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final bool isDark;

  _SliverAppBarDelegate(this._tabBar, this.isDark);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight, // Match scaffold
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return true;
  }
}
