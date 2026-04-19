import 'package:flutter/material.dart';
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
  List<Surah> _surahs = [];
  List<Map<String, dynamic>> _chartData = [];
  Map<String, int> _overallStats = {'total': 0, 'completed': 0, 'pending': 0};

  // Active tasks to map to Juz/Hizb
  List<PlanTask> _activeTasks = [];

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
  Map<int, List<int>> _juzToAyahIds = {};
  Map<int, List<int>> _hizbToAyahIds = {};

  // Overlap Ranges
  Map<int, AyahRange> _taskRanges = {};
  Map<int, AyahRange> _surahRanges = {};
  Map<int, AyahRange> _juzRanges = {};
  Map<int, AyahRange> _hizbRanges = {};

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

  Future<void> _loadData({bool showFullLoading = true}) async {
    if (showFullLoading) setState(() => _isLoading = true);

    try {
      // Parallel fetch Basic Data
      final basicFutures = await Future.wait([
        PlannerDatabase().getMemorizedPercentage(type: _selectedHeaderMetric),
        PlannerDatabase().getAllSurahProgress(),
        QuranDatabase().getAllSurahs(),
        PlannerDatabase().getCompletionStats(
          days: _selectedStatRange,
        ), // Use selected range
        PlannerDatabase().getStats(),
        PlannerDatabase().getActiveTasks(),
      ]);

      // Fetch Juz Mappings (Parallel 30 queries)
      // Only if not loaded? Nah, load always for now to be safe or check cache.
      if (_juzSurahMap.isEmpty) {
        final juzFutures = await Future.wait(
          List.generate(30, (i) => QuranDatabase().getSurahsInJuz(i + 1)),
        );
        for (int i = 0; i < 30; i++) {
          _juzSurahMap[i + 1] = juzFutures[i];
        }
      }

      // Fetch Page Coverage and Juz/Surah Ranges
      final coverageFuture = PlannerDatabase().getGlobalPageCoverage();
      final ayahsFuture = PlannerDatabase().getGlobalCoveredAyahs();
      final statsFuture = PlannerDatabase().getAyahProgressMap();

      if (_juzPageRanges.isEmpty) {
        // Optimized: Use PlannerDatabase cache
        for (int i = 1; i <= 30; i++) {
          _juzPageRanges[i] = await PlannerDatabase().getCachedJuzPageRange(i);
        }
      }

      if (_surahPageRanges.isEmpty) {
        // Optimized: Use PlannerDatabase cache
        for (int i = 1; i <= 114; i++) {
          _surahPageRanges[i] = await PlannerDatabase().getCachedSurahPageRange(
            i,
          );
        }
      }

      final coverage = await coverageFuture;
      final coveredAyahs = await ayahsFuture;
      final ayahStats = await statsFuture;

      // Fetch and Map Notes
      final allNotes = await PlannerDatabase().getAllNotesWithTasks();

      final sNotes = <int, List<TaskNote>>{};
      final jNotes = <int, List<TaskNote>>{};
      final hNotes = <int, List<TaskNote>>{};

      for (var row in allNotes) {
        final note = TaskNote.fromMap(row);

        if (note.type == NoteType.correct) continue;

        if (note.ayahId != null) {
          final m = await PlannerDatabase().getCachedAyahMeta(note.ayahId!);

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

      // Compute Granular Progress per Surah
      final Map<int, double> granularProgress = {};
      final Map<int, List<int>> surahAyahIds = {};
      final Map<int, List<int>> juzAyahIds = {};
      final Map<int, List<int>> hizbAyahIds = {};

      // Optimized: Use PlannerDatabase cached ID lists
      for (int s = 1; s <= 114; s++) {
        final ids = await PlannerDatabase().getCachedAyahIdsForSurah(s);
        if (ids.isNotEmpty) surahAyahIds[s] = ids;
      }
      for (int j = 1; j <= 30; j++) {
        final ids = await PlannerDatabase().getCachedAyahIdsForJuz(j);
        if (ids.isNotEmpty) juzAyahIds[j] = ids;
      }
      for (int h = 1; h <= 60; h++) {
        final ids = await PlannerDatabase().getCachedAyahIdsForHizb(h);
        if (ids.isNotEmpty) hizbAyahIds[h] = ids;
      }

      // Map ranges for overlap detection
      final tRanges = <int, AyahRange>{};
      for (final t in (basicFutures[5] as List<PlanTask>)) {
        if (t.id == null) continue;
        final range = await QuranDatabase().getAyahRangeForPlanUnit(
          unitType: t.unitType,
          unitId: t.unitId,
          endUnitId: t.endUnitId,
          startAyah: t.startAyah,
          endAyah: t.endAyah,
        );
        if (range['min']! > 0) {
          tRanges[t.id!] = AyahRange(range['min']!, range['max']!);
        }
      }

      final sRanges = <int, AyahRange>{};
      final jRanges = <int, AyahRange>{};
      final hRanges = <int, AyahRange>{};

      for (final s in surahAyahIds.keys) {
        final ids = surahAyahIds[s]!;
        if (ids.isNotEmpty) {
          // IDs are already sorted in PlannerDatabase cache usually, but safe to assume range
          sRanges[s] = AyahRange(ids.first, ids.last);
        }
      }
      for (final j in juzAyahIds.keys) {
        final ids = juzAyahIds[j]!;
        if (ids.isNotEmpty) {
          jRanges[j] = AyahRange(ids.first, ids.last);
        }
      }
      for (final h in hizbAyahIds.keys) {
        final ids = hizbAyahIds[h]!;
        if (ids.isNotEmpty) {
          hRanges[h] = AyahRange(ids.first, ids.last);
        }
      }

      for (final s in surahAyahIds.keys) {
        final ids = surahAyahIds[s];
        if (ids == null) continue;
        final total = ids.length;
        final soFar = ids.where((id) => coveredAyahs.contains(id)).length;
        granularProgress[s] = total == 0 ? 0.0 : soFar / total;
      }

      // Load Hizb->Surah map efficiently
      final newHizbSurahMap = <int, List<int>>{};
      for (int h = 1; h <= 60; h++) {
        newHizbSurahMap[h] = await PlannerDatabase().getCachedSurahsInHizb(h);
      }

      if (mounted) {
        debugPrint(
          "ProgressPage: Loaded ${(basicFutures[5] as List<PlanTask>).length} active tasks",
        );
        setState(() {
          // Explicit clear for safety
          _surahProgress = [];
          _activeTasks = [];
          _chartData = [];

          _memPercentage = basicFutures[0] as Map<String, int>;
          _surahProgress = (basicFutures[1] as List<Map<String, dynamic>>)
              .map((m) => QuranProgress.fromMap(m))
              .toList();
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
          _globalAyahStats = ayahStats;
          _juzToAyahIds = juzAyahIds;
          _hizbToAyahIds = hizbAyahIds;
          _hizbSurahMap.clear();
          _hizbSurahMap.addAll(newHizbSurahMap);

          _taskRanges = tRanges;
          _surahRanges = sRanges;
          _juzRanges = jRanges;
          _hizbRanges = hRanges;

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
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [const Color(0xFF152C4E), AppColors.backgroundDark]
                  : [const Color(0xFFEAF1FF), AppColors.backgroundLight],
            ),
          ),
        ),
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
        final progress = _surahProgress.firstWhere(
          (p) => p.unitId == surah.number,
          orElse: () => QuranProgress(
            unitId: surah.number,
            isMemorized: false,
            revisionCount: 0,
          ),
        );

        // Find overlapping active tasks
        final sRange = _surahRanges[surah.number];
        final surahActiveTasks = _activeTasks.where((t) {
          if (t.id == null) return false;
          final tRange = _taskRanges[t.id!];
          if (sRange != null && tRange != null) {
            return _doesOverlap(tRange, sRange);
          }
          // Fallback to strict matching if ranges not ready (shouldn't happen usually)
          return t.unitType == PlanUnitType.surah && t.unitId == surah.number;
        }).toList();
        final hasActive = surahActiveTasks.isNotEmpty;

        return _SlideFadeReveal(
          index: index,
          child: UnitProgressListItem(
            number: surah.number,
            title: surah.englishName,
            subtitle: hasActive ? null : surah.name,
            progress: _calculateSurahProgress(surah.number),
            isCompleted:
                progress.isMemorized ||
                _calculateSurahProgress(surah.number) >= 0.999,
            activeTaskCount: surahActiveTasks.length,
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

        final jRange = _juzRanges[juzNum];
        final displayTasks = _activeTasks.where((t) {
          if (t.id == null) return false;
          final tRange = _taskRanges[t.id!];
          if (jRange != null && tRange != null) {
            return _doesOverlap(tRange, jRange);
          }
          // Fallback
          // We can keep the old comprehensive logic as fallback or just unit exact match
          return (t.unitType == PlanUnitType.juz && t.unitId == juzNum) ||
              (t.unitType == PlanUnitType.surah &&
                  _juzSurahMap[juzNum]?.contains(t.unitId) == true);
        }).toList();

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
            activeTaskCount: displayTasks.length,
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

        // Match active tasks for this Hizb
        final hRange = _hizbRanges[hizbNum];
        final relevant = _activeTasks.where((t) {
          if (t.id == null) return false;
          final tRange = _taskRanges[t.id!];
          if (hRange != null && tRange != null) {
            return _doesOverlap(tRange, hRange);
          }
          // Fallback
          // Try text based if range fails (unlikely)
          final sub = t.subtitle?.toLowerCase() ?? "";
          return sub.contains("hizb $hizbNum");
        }).toList();

        final parentJuz = ((hizbNum - 1) ~/ 2) + 1;
        // With overlap logic, we don't need separate parentJuzTasks logic
        // because a Full Juz task will overlap the Hizb range automatically.

        final hasActive = relevant.isNotEmpty;

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
            activeTaskCount: relevant.length,
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
    return true;
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
