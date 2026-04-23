import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hifdh/core/services/planner_database.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';
import 'package:hifdh/shared/models/plan_task.dart';
import 'package:hifdh/shared/models/surah.dart';
import 'package:hifdh/core/services/quran_database.dart';
import 'package:hifdh/core/theme/app_background.dart';
import 'package:hifdh/core/theme/app_colors.dart';
import 'package:hifdh/core/utils/progress_chart_helper.dart';
import 'package:hifdh/features/progress/widgets/activity_chart.dart';
import 'package:hifdh/features/progress/widgets/progress_header_card.dart';
import 'package:hifdh/features/progress/widgets/unit_details_sheet.dart';
import 'package:hifdh/features/progress/widgets/unit_progress_list_item.dart';
import 'package:hifdh/shared/widgets/liquid_glass.dart';
import 'package:hifdh/shared/widgets/theme_toggle_button.dart';

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
  Map<String, int> _memPercentage = {'memorized': 0, 'total': 0};
  List<QuranProgress> _surahProgress = [];
  Map<int, QuranProgress> _surahProgressById = {};
  List<Surah> _surahs = [];
  List<Map<String, dynamic>> _chartData = [];
  Map<String, int> _overallStats = {'total': 0, 'completed': 0, 'pending': 0};

  // Chart Range
  int _selectedStatRange = 7;
  // Metric for Header Card (1: Ayah, 2: Page, 3: Surah)
  int _selectedHeaderMetric = 2;

  // Cache for Juz -> Surahs mapping
  final Map<int, List<int>> _juzSurahMap = {};
  final Map<int, List<int>> _hizbSurahMap = {};

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

  // Global Ayah Stats (key: AyahID) -> {m: bool, r: int}
  Map<int, Map<String, dynamic>> _globalAyahStats = {};

  // Ayah Mapping Cache
  final Map<int, List<int>> _surahToAyahIds = {};
  final Map<int, List<int>> _juzToAyahIds = {};
  final Map<int, List<int>> _hizbToAyahIds = {};

  // Overlap Ranges
  Map<int, AyahRange> _taskRanges = {};
  final Map<int, AyahRange> _surahRanges = {};
  final Map<int, AyahRange> _juzRanges = {};
  final Map<int, AyahRange> _hizbRanges = {};
  Map<int, int> _surahActiveCounts = {};
  Map<int, int> _juzActiveCounts = {};
  Map<int, int> _hizbActiveCounts = {};

  bool _isDataRefreshRunning = false;
  bool _refreshQueued = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData(); // Initial load shows spinner

    // Listen for updates but don't show spinner for background refreshes
    PlannerDatabase().dataUpdateNotifier.addListener(_handleDataUpdate);
  }

  @override
  void dispose() {
    PlannerDatabase().dataUpdateNotifier.removeListener(_handleDataUpdate);
    _tabController.dispose();
    super.dispose();
  }

  void _handleDataUpdate() {
    // Refresh data without showing full screen loading spinner
    _loadData(showFullLoading: false);
  }

  Future<void> _ensureStaticProgressCaches() async {
    if (_juzSurahMap.isEmpty) {
      final juzFutures = await Future.wait(
        List.generate(30, (i) => QuranDatabase().getSurahsInJuz(i + 1)),
      );
      for (int i = 0; i < 30; i++) {
        _juzSurahMap[i + 1] = juzFutures[i];
      }
    }

    if (_juzPageRanges.isEmpty) {
      final ranges = await Future.wait(
        List.generate(
          30,
          (i) => PlannerDatabase().getCachedJuzPageRange(i + 1),
        ),
      );
      for (int i = 0; i < 30; i++) {
        _juzPageRanges[i + 1] = ranges[i];
      }
    }

    if (_surahPageRanges.isEmpty) {
      final ranges = await Future.wait(
        List.generate(
          114,
          (i) => PlannerDatabase().getCachedSurahPageRange(i + 1),
        ),
      );
      for (int i = 0; i < 114; i++) {
        _surahPageRanges[i + 1] = ranges[i];
      }
    }

    if (_surahToAyahIds.isEmpty) {
      final surahAyahLists = await Future.wait(
        List.generate(
          114,
          (i) => PlannerDatabase().getCachedAyahIdsForSurah(i + 1),
        ),
      );
      for (int i = 0; i < 114; i++) {
        final surah = i + 1;
        final ids = surahAyahLists[i];
        if (ids.isEmpty) continue;
        _surahToAyahIds[surah] = ids;
        _surahRanges[surah] = AyahRange(ids.first, ids.last);
      }
    }

    if (_juzToAyahIds.isEmpty) {
      final juzAyahLists = await Future.wait(
        List.generate(
          30,
          (i) => PlannerDatabase().getCachedAyahIdsForJuz(i + 1),
        ),
      );
      for (int i = 0; i < 30; i++) {
        final juz = i + 1;
        final ids = juzAyahLists[i];
        if (ids.isEmpty) continue;
        _juzToAyahIds[juz] = ids;
        _juzRanges[juz] = AyahRange(ids.first, ids.last);
      }
    }

    if (_hizbToAyahIds.isEmpty) {
      final hizbAyahLists = await Future.wait(
        List.generate(
          60,
          (i) => PlannerDatabase().getCachedAyahIdsForHizb(i + 1),
        ),
      );
      for (int i = 0; i < 60; i++) {
        final hizb = i + 1;
        final ids = hizbAyahLists[i];
        if (ids.isEmpty) continue;
        _hizbToAyahIds[hizb] = ids;
        _hizbRanges[hizb] = AyahRange(ids.first, ids.last);
      }
    }

    if (_hizbSurahMap.isEmpty) {
      final hizbSurahLists = await Future.wait(
        List.generate(
          60,
          (i) => PlannerDatabase().getCachedSurahsInHizb(i + 1),
        ),
      );
      for (int i = 0; i < 60; i++) {
        _hizbSurahMap[i + 1] = hizbSurahLists[i];
      }
    }
  }

  Future<void> _loadData({bool showFullLoading = true}) async {
    if (_isDataRefreshRunning) {
      _refreshQueued = true;
      return;
    }

    _isDataRefreshRunning = true;
    if (showFullLoading && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      await _ensureStaticProgressCaches();

      final basicFutures = await Future.wait([
        PlannerDatabase().getMemorizedPercentage(type: _selectedHeaderMetric),
        PlannerDatabase().getAllSurahProgress(),
        QuranDatabase().getAllSurahs(),
        PlannerDatabase().getCompletionStats(days: _selectedStatRange),
        PlannerDatabase().getStats(),
        PlannerDatabase().getActiveTasks(),
      ]);

      final coverageFuture = PlannerDatabase().getGlobalPageCoverage();
      final ayahsFuture = PlannerDatabase().getGlobalCoveredAyahs();
      final statsFuture = PlannerDatabase().getAyahProgressMap();
      final notesFuture = PlannerDatabase().getAllNotesWithTasks();

      final coverage = await coverageFuture;
      final coveredAyahs = await ayahsFuture;
      final ayahStats = await statsFuture;
      final allNotes = await notesFuture;

      final sNotes = <int, List<TaskNote>>{};
      final jNotes = <int, List<TaskNote>>{};
      final hNotes = <int, List<TaskNote>>{};

      final noteAyahIds = allNotes
          .map((row) => row['ayahId'])
          .whereType<int>()
          .toSet()
          .toList();
      final noteMetaByAyahId = <int, Map<String, int>>{};

      if (noteAyahIds.isNotEmpty) {
        final metas = await Future.wait(
          noteAyahIds.map((id) => PlannerDatabase().getCachedAyahMeta(id)),
        );
        for (int i = 0; i < noteAyahIds.length; i++) {
          noteMetaByAyahId[noteAyahIds[i]] = metas[i];
        }
      }

      for (final row in allNotes) {
        final note = TaskNote.fromMap(row);
        if (note.type == NoteType.correct) continue;

        if (note.ayahId != null) {
          final m = noteMetaByAyahId[note.ayahId!] ?? const <String, int>{};
          if (m.isNotEmpty) {
            final surah = m['surahNumber'];
            final juz = m['juzNumber'];
            final hizb = m['hizbNumber'];

            if (surah != null) sNotes.putIfAbsent(surah, () => []).add(note);
            if (juz != null) jNotes.putIfAbsent(juz, () => []).add(note);
            if (hizb != null) hNotes.putIfAbsent(hizb, () => []).add(note);
          }
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

      final granularProgress = <int, double>{};
      for (final entry in _surahToAyahIds.entries) {
        final ids = entry.value;
        final total = ids.length;
        final soFar = ids.where((id) => coveredAyahs.contains(id)).length;
        granularProgress[entry.key] = total == 0 ? 0.0 : soFar / total;
      }

      final activeTasks = basicFutures[5] as List<PlanTask>;
      final activeTaskIds = activeTasks
          .where((t) => t.id != null)
          .map((t) => t.id!)
          .toSet();
      final updatedTaskRanges = Map<int, AyahRange>.from(_taskRanges)
        ..removeWhere((id, _) => !activeTaskIds.contains(id));

      final tasksNeedingRange = activeTasks.where((task) {
        final id = task.id;
        return id != null && !updatedTaskRanges.containsKey(id);
      }).toList();

      if (tasksNeedingRange.isNotEmpty) {
        final resolvedRanges = await Future.wait(
          tasksNeedingRange.map((task) async {
            final range = await QuranDatabase().getAyahRangeForPlanUnit(
              unitType: task.unitType,
              unitId: task.unitId,
              endUnitId: task.endUnitId,
              startAyah: task.startAyah,
              endAyah: task.endAyah,
            );
            return (taskId: task.id!, range: range);
          }),
        );

        for (final resolved in resolvedRanges) {
          final range = resolved.range;
          if ((range['min'] ?? 0) > 0) {
            updatedTaskRanges[resolved.taskId] = AyahRange(
              range['min']!,
              range['max']!,
            );
          }
        }
      }

      final surahActiveCounts = <int, int>{};
      for (int s = 1; s <= 114; s++) {
        final sRange = _surahRanges[s];
        var count = 0;
        for (final task in activeTasks) {
          if (task.id == null) continue;
          final tRange = updatedTaskRanges[task.id!];
          if (sRange != null && tRange != null) {
            if (_doesOverlap(tRange, sRange)) count++;
          } else if (task.unitType == PlanUnitType.surah && task.unitId == s) {
            count++;
          }
        }
        if (count > 0) {
          surahActiveCounts[s] = count;
        }
      }

      final juzActiveCounts = <int, int>{};
      for (int j = 1; j <= 30; j++) {
        final jRange = _juzRanges[j];
        var count = 0;
        for (final task in activeTasks) {
          if (task.id == null) continue;
          final tRange = updatedTaskRanges[task.id!];
          if (jRange != null && tRange != null) {
            if (_doesOverlap(tRange, jRange)) count++;
          } else if ((task.unitType == PlanUnitType.juz && task.unitId == j) ||
              (task.unitType == PlanUnitType.surah &&
                  _juzSurahMap[j]?.contains(task.unitId) == true)) {
            count++;
          }
        }
        if (count > 0) {
          juzActiveCounts[j] = count;
        }
      }

      final hizbActiveCounts = <int, int>{};
      for (int h = 1; h <= 60; h++) {
        final hRange = _hizbRanges[h];
        var count = 0;
        final hizbText = 'hizb $h';
        for (final task in activeTasks) {
          if (task.id == null) continue;
          final tRange = updatedTaskRanges[task.id!];
          if (hRange != null && tRange != null) {
            if (_doesOverlap(tRange, hRange)) count++;
          } else {
            final sub = task.subtitle?.toLowerCase() ?? '';
            if (sub.contains(hizbText)) count++;
          }
        }
        if (count > 0) {
          hizbActiveCounts[h] = count;
        }
      }

      if (mounted) {
        setState(() {
          _memPercentage = basicFutures[0] as Map<String, int>;
          _surahProgress = (basicFutures[1] as List<Map<String, dynamic>>)
              .map((m) => QuranProgress.fromMap(m))
              .toList();
          _surahProgressById = {
            for (final progress in _surahProgress) progress.unitId: progress,
          };
          _surahs = basicFutures[2] as List<Surah>;
          _chartData = ProgressChartHelper.normalizeChartData(
            basicFutures[3] as List<Map<String, dynamic>>,
            _selectedStatRange,
          );
          _overallStats = basicFutures[4] as Map<String, int>;
          _pageCoverage = coverage;
          _surahExactProgress = granularProgress;
          _surahNotes = sNotes;
          _juzNotes = jNotes;
          _hizbNotes = hNotes;
          _globalAyahStats = ayahStats;
          _taskRanges = updatedTaskRanges;
          _surahActiveCounts = surahActiveCounts;
          _juzActiveCounts = juzActiveCounts;
          _hizbActiveCounts = hizbActiveCounts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading progress: $e");
      if (mounted) setState(() => _isLoading = false);
    } finally {
      _isDataRefreshRunning = false;
      if (_refreshQueued && mounted) {
        _refreshQueued = false;
        Future.microtask(() => _loadData(showFullLoading: false));
      }
    }
  }

  double _calculateSurahProgress(int surahNum) {
    return _surahExactProgress[surahNum] ?? 0.0;
  }

  bool _doesOverlap(AyahRange r1, AyahRange r2) {
    return r1.min <= r2.max && r1.max >= r2.min;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark
            ? AppColors.backgroundDark
            : AppColors.backgroundLight,
        body: DecoratedBox(
          decoration: AppBackground.pageDecoration(theme),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: isDark
            ? AppColors.backgroundDark
            : AppColors.backgroundLight,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        title: Text(
          AppLocalizations.of(context)!.progress,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.primaryNavy,
            fontSize: 22,
            letterSpacing: -0.3,
          ),
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : AppColors.primaryNavy,
        ),
        elevation: 0,
        actions: [
          _buildAppBarActionButton(
            icon: Icons.refresh_rounded,
            isDark: isDark,
            onPressed: () => _loadData(showFullLoading: false),
          ),
          const ThemeToggleButton(),
          const SizedBox(width: 12),
        ],
      ),
      body: DecoratedBox(
        decoration: AppBackground.pageDecoration(theme),
        child: RefreshIndicator(
          color: AppColors.accentOrange,
          backgroundColor: isDark
              ? AppColors.surfaceDark
              : AppColors.surfaceLight,
          onRefresh: () async {
            await _loadData(showFullLoading: false);
          },
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SlideFadeReveal(
                          index: 0,
                          child: ProgressHeaderCard(
                            memPercentage: _memPercentage,
                            overallStats: _overallStats,
                            selectedMetric: _selectedHeaderMetric,
                            onMetricChanged: (val) => _updateHeaderMetric(val),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _SlideFadeReveal(
                          index: 1,
                          child: ActivityChart(
                            chartData: _chartData,
                            selectedStatRange: _selectedStatRange,
                            onRangeChanged: (val) => _updateChartRange(val),
                            isDark: isDark,
                          ),
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
                      labelColor: isDark ? Colors.white : AppColors.primaryNavy,
                      unselectedLabelColor: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      indicatorColor: isDark
                          ? Colors.white
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
        ),
      ),
    );
  }

  Widget _buildAppBarActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 6),
      child: IconButton(
        onPressed: onPressed,
        icon: SizedBox(
          width: 38,
          height: 38,
          child: LiquidGlass(
            padding: EdgeInsets.zero,
            borderRadius: BorderRadius.circular(12),
            blur: 12,
            tint: isDark
                ? Colors.white.withValues(alpha: 0.09)
                : Colors.white.withValues(alpha: 0.52),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.22)
                  : AppColors.primaryNavy.withValues(alpha: 0.16),
            ),
            child: Center(child: Icon(icon, size: 20)),
          ),
        ),
      ),
    );
  }

  Future<void> _updateChartRange(int days) async {
    setState(() => _selectedStatRange = days);
    final raw = await PlannerDatabase().getCompletionStats(days: days);
    if (mounted) {
      setState(() {
        _chartData = ProgressChartHelper.normalizeChartData(raw, days);
      });
    }
  }

  Future<void> _updateHeaderMetric(int type) async {
    setState(() => _selectedHeaderMetric = type);
    final pct = await PlannerDatabase().getMemorizedPercentage(type: type);
    if (mounted) {
      setState(() {
        _memPercentage = pct;
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
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      itemBuilder: (context, index) {
        final surah = _surahs[index];
        final surahProgressFraction = _calculateSurahProgress(surah.number);
        final progress =
            _surahProgressById[surah.number] ??
            QuranProgress(
              unitId: surah.number,
              isMemorized: false,
              revisionCount: 0,
            );
        final activeCount = _surahActiveCounts[surah.number] ?? 0;
        final hasActive = activeCount > 0;

        return _SlideFadeReveal(
          index: index,
          child: UnitProgressListItem(
            number: surah.number,
            title: surah.englishName,
            subtitle: hasActive ? null : surah.name,
            progress: surahProgressFraction,
            isCompleted: progress.isMemorized || surahProgressFraction >= 0.999,
            activeTaskCount: activeCount,
            revisionCount: progress.revisionCount,
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
        );
      },
    );
  }

  Widget _buildJuzList(bool isDark) {
    return ListView.builder(
      itemCount: 30,
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      itemBuilder: (context, index) {
        final juzNum = index + 1;
        final activeCount = _juzActiveCounts[juzNum] ?? 0;

        // Determine Juz Progress from Page Coverage
        final range = _juzPageRanges[juzNum];
        double estimatedProg = 0.0;
        bool isFullyMemorized = false;

        if (range != null && _pageCoverage.isNotEmpty) {
          int start = range['startPage']!;
          int end = range['endPage']!;
          int total = end - start + 1;
          int coveredCount = 0;

          if (total > 0 && start > 0 && end < _pageCoverage.length) {
            for (int p = start; p <= end; p++) {
              if (_pageCoverage[p]) coveredCount++;
            }
            estimatedProg = coveredCount / total;
            isFullyMemorized = estimatedProg >= 0.99;
          }
        }

        // Calculate Revision Stats (Min revisions across all ayahs in Juz)
        final jAyahs = _juzToAyahIds[juzNum] ?? [];
        int juzRevisions = 0;

        if (jAyahs.isNotEmpty) {
          int? minRev;
          for (final aid in jAyahs) {
            final r = (_globalAyahStats[aid]?['revisions'] as int?) ?? 0;
            if (minRev == null || r < minRev) {
              minRev = r;
            }
            if (minRev == 0) break;
          }
          juzRevisions = minRev ?? 0;
        }

        return _SlideFadeReveal(
          index: index,
          child: UnitProgressListItem(
            number: juzNum,
            title: "${AppLocalizations.of(context)!.juz} $juzNum",
            progress: estimatedProg,
            isCompleted: isFullyMemorized,
            activeTaskCount: activeCount,
            revisionCount: juzRevisions,
            onTap: () {
              _showUnitDetails(
                context,
                PlanUnitType.juz,
                juzNum,
                "${AppLocalizations.of(context)!.juz} $juzNum",
                preloadedNotes: _juzNotes[juzNum],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHizbList(bool isDark) {
    return ListView.builder(
      itemCount: 60,
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      itemBuilder: (context, index) {
        final hizbNum = index + 1;
        final activeCount = _hizbActiveCounts[hizbNum] ?? 0;

        final parentJuz = ((hizbNum - 1) ~/ 2) + 1;
        // With overlap logic, we don't need separate parentJuzTasks logic
        // because a Full Juz task will overlap the Hizb range automatically.

        final hasActive = activeCount > 0;

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

        // Calculate Revision Stats (Min revisions across all ayahs in Hizb)
        final hAyahs = _hizbToAyahIds[hizbNum] ?? [];
        int hizbRevisions = 0;

        if (hAyahs.isNotEmpty) {
          int? minRev;
          for (final aid in hAyahs) {
            final r = (_globalAyahStats[aid]?['revisions'] as int?) ?? 0;
            if (minRev == null || r < minRev) {
              minRev = r;
            }
            if (minRev == 0) break;
          }
          hizbRevisions = minRev ?? 0;
        }

        // final surahsInHizb = _hizbSurahMap[hizbNum] ?? []; // Unused

        return _SlideFadeReveal(
          index: index,
          child: UnitProgressListItem(
            number: hizbNum,
            title:
                "${AppLocalizations.of(context)!.hizb} $hizbNum (${AppLocalizations.of(context)!.juz} $parentJuz)",
            subtitle: hasActive
                ? "${AppLocalizations.of(context)!.coveredByJuz} $parentJuz"
                : null,
            progress: hizbProg,
            isCompleted: isFullyMemorized,
            activeTaskCount: activeCount,
            revisionCount: hizbRevisions,
            onTap: () {
              _showUnitDetails(
                context,
                PlanUnitType.hizb,
                hizbNum,
                "${AppLocalizations.of(context)!.hizb} $hizbNum",
                preloadedNotes: _hizbNotes[hizbNum],
              );
            },
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: LiquidGlass(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        borderRadius: BorderRadius.circular(14),
        blur: 16,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [AppColors.surfaceDark, const Color(0xFF22395C)]
              : [Colors.white, const Color(0xFFF1F6FF)],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : AppColors.dividerLight,
        ),
        child: _tabBar,
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return oldDelegate.isDark != isDark || oldDelegate._tabBar != _tabBar;
  }
}

class AyahRange {
  final int min;
  final int max;
  const AyahRange(this.min, this.max);
}

class _SlideFadeReveal extends StatelessWidget {
  final int index;
  final Widget child;

  const _SlideFadeReveal({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final reduceMotion = mediaQuery?.disableAnimations ?? false;
    final androidPhone =
        defaultTargetPlatform == TargetPlatform.android &&
        !kIsWeb &&
        (mediaQuery?.size.shortestSide ?? 1000) < 600;

    if (reduceMotion || androidPhone) {
      return child;
    }

    final clampedIndex = index.clamp(0, 10);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + (clampedIndex * 35)),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 14),
            child: child,
          ),
        );
      },
    );
  }
}
