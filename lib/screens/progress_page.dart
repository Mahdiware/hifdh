import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/planner_database_helper.dart';
import '../models/plan_task.dart';
import '../models/surah.dart';
import '../services/database_helper.dart';
import '../theme/app_colors.dart';

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
  final List<int> _chartRanges = [7, 30, 90, 180, 365];
  final Map<int, String> _chartRangeLabels = {
    7: "7 Days",
    30: "30 Days",
    90: "3 Months",
    180: "6 Months",
    365: "1 Year",
  };

  // Cache for Juz -> Surahs mapping
  Map<int, List<int>> _juzSurahMap = {};

  // Page Coverage for granular calculation
  List<bool> _pageCoverage = [];
  Map<int, double> _surahExactProgress =
      {}; // Computed granular progress per Surah

  // Cache for Juz Page Ranges
  Map<int, Map<String, int>> _juzPageRanges = {};
  // Cache for Surah Page Ranges
  Map<int, Map<String, int>> _surahPageRanges = {};

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
          _chartData = _normalizeChartData(
            basicFutures[3] as List<Map<String, dynamic>>,
          );
          _overallStats = basicFutures[4] as Map<String, int>;
          _activeTasks = basicFutures[5] as List<PlanTask>;
          _pageCoverage = coverage;
          _surahExactProgress = granularProgress;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading progress: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _normalizeChartData(
    List<Map<String, dynamic>> raw,
  ) {
    if (_selectedStatRange <= 7) {
      return _generateDailyData(raw, _selectedStatRange);
    } else if (_selectedStatRange <= 90) {
      // Weekly aggregation for 30 and 90 days
      return _generateWeeklyData(raw, _selectedStatRange);
    } else {
      // Monthly aggregation for 6 months and 1 year
      return _generateMonthlyData(raw, _selectedStatRange);
    }
  }

  List<Map<String, dynamic>> _generateDailyData(
    List<Map<String, dynamic>> raw,
    int days,
  ) {
    final List<Map<String, dynamic>> result = [];
    final now = DateTime.now();
    for (int i = days - 1; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(d);

      final hit = raw.firstWhere(
        (element) => element['date'] == key,
        orElse: () => {'date': key, 'count': 0},
      );
      result.add({
        'day': DateFormat('E').format(d)[0], // M, T, W...
        'fullDate': DateFormat('MMM d').format(d),
        'count': hit['count'],
      });
    }
    return result;
  }

  List<Map<String, dynamic>> _generateWeeklyData(
    List<Map<String, dynamic>> raw,
    int days,
  ) {
    // Group by Week (Week Ending Date)
    final List<Map<String, dynamic>> result = [];
    final now = DateTime.now();

    // Align to weeks? Or just raw chunks of 7 days?
    // Let's do raw chunks back from today
    int weeks = (days / 7).ceil();
    for (int i = weeks - 1; i >= 0; i--) {
      final weekEnd = now.subtract(Duration(days: i * 7));
      final weekStart = weekEnd.subtract(const Duration(days: 6));

      int count = 0;
      for (var item in raw) {
        final date = DateTime.parse(item['date']);
        if (date.isAfter(weekStart.subtract(const Duration(seconds: 1))) &&
            date.isBefore(weekEnd.add(const Duration(seconds: 1)))) {
          count += (item['count'] as int);
        }
      }

      result.add({
        'day': "${weekStart.day}-${weekEnd.day}", // 12-19
        'fullDate':
            "${DateFormat('MMM d').format(weekStart)} - ${DateFormat('MMM d').format(weekEnd)}",
        'count': count,
      });
    }
    return result;
  }

  List<Map<String, dynamic>> _generateMonthlyData(
    List<Map<String, dynamic>> raw,
    int days,
  ) {
    final List<Map<String, dynamic>> result = [];
    final now = DateTime.now();
    int months = (days / 30).ceil(); // Approx

    for (int i = months - 1; i >= 0; i--) {
      // This is rough monthly calculation (30 days blocks)
      // Better to use actual months?
      // Let's use 30 day blocks for simplicity consistent with "days"
      // Or actual calendar months? Calendar months is more user friendly "Jan, Feb".
      // Let's try Calendar months.
      final targetMonth = DateTime(now.year, now.month - i, 1);

      int count = 0;
      for (var item in raw) {
        final date = DateTime.parse(item['date']);
        if (date.year == targetMonth.year && date.month == targetMonth.month) {
          count += (item['count'] as int);
        }
      }

      result.add({
        'day': DateFormat('MMM').format(targetMonth), // Jan, Feb
        'fullDate': DateFormat('MMMM yyyy').format(targetMonth),
        'count': count,
      });
    }
    return result;
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
                    _buildHeaderCard(isDark),
                    const SizedBox(height: 16),
                    _buildWeeklyChart(isDark),
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
                  tabs: const [
                    Tab(text: "Surah"),
                    Tab(text: "Juz"),
                    Tab(text: "Hizb"),
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

  Widget _buildHeaderCard(bool isDark) {
    final memCount = _overallStats['completed'] ?? 0;
    final pendingCount = _overallStats['pending'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppColors.surfaceDark, Colors.black]
              : [AppColors.primaryNavy, AppColors.surfaceDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryNavy.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Circular Diagram
          SizedBox(
            height: 100,
            width: 100,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: _memPercentage / 100,
                  strokeWidth: 8,
                  valueColor: const AlwaysStoppedAnimation(
                    AppColors.successGreen,
                  ), // Green
                  backgroundColor: Colors.white10,
                ),
                Center(
                  child: Text(
                    "${_memPercentage.toStringAsFixed(1)}%",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Stats Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Hifdh Performance",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatItem(
                      "Completed",
                      "$memCount",
                      Icons.check_circle,
                      AppColors.successGreen,
                    ),
                    _buildStatItem(
                      "Pending",
                      "$pendingCount",
                      Icons.timelapse,
                      AppColors.accentOrange,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String val, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              val,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _updateChartRange(int days) async {
    setState(() => _selectedStatRange = days);
    final raw = await PlannerDatabaseHelper().getCompletionStats(days: days);
    if (mounted) {
      setState(() {
        _chartData = _normalizeChartData(raw);
      });
    }
  }

  Widget _buildWeeklyChart(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20), // More rounded
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.grey.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Activity",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 16),
          // Range Selector Checkbox/Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _chartRanges.map((r) {
                final isSelected = _selectedStatRange == r;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => _updateChartRange(r),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark
                                  ? AppColors.accentOrange
                                  : AppColors.primaryNavy)
                            : (isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.grey[100]),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? Colors.transparent
                              : (isDark ? Colors.white10 : Colors.grey[300]!),
                        ),
                      ),
                      child: Text(
                        _chartRangeLabels[r]!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.grey : Colors.grey[600]),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
          if (_chartData.every((d) => d['count'] == 0))
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  "No activity in this period",
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ),
            )
          else
            SizedBox(
              height: 150, // Increased to prevent overflow
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _chartData.map((d) {
                  final count = d['count'] as int;
                  // Max Scaling
                  final max = _chartData
                      .map((e) => e['count'] as int)
                      .reduce((a, b) => a > b ? a : b);
                  final scaleMax = max > 0 ? max : 1;
                  final normalizedHeight =
                      (count / scaleMax) * 80; // Max bar 80px

                  // Colors
                  final barColor = isDark
                      ? AppColors.accentOrange
                      : AppColors.primaryNavy; // Navy looks cleaner on light
                  final emptyColor = isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey[100];

                  final barWidth = _chartData.length > 15 ? 8.0 : 14.0;
                  final bool rotateLabels = _chartData.length > 8;

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (count > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            "$count",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.grey
                                  : AppColors.primaryNavy,
                            ),
                          ),
                        ),
                      Container(
                        width: barWidth, // Wider bars
                        height: 80, // Full height track
                        alignment: Alignment.bottomCenter,
                        decoration: BoxDecoration(
                          color: emptyColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: count > 0
                            ? Container(
                                width: barWidth,
                                height: normalizedHeight > barWidth
                                    ? normalizedHeight.toDouble()
                                    : barWidth, // Minimum height circle
                                decoration: BoxDecoration(
                                  color: barColor,
                                  borderRadius: BorderRadius.circular(4),
                                  gradient: isDark
                                      ? null
                                      : LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            AppColors.primaryNavy,
                                            AppColors.primaryNavy.withOpacity(
                                              0.8,
                                            ),
                                          ],
                                        ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 8),
                      // Label
                      if (rotateLabels)
                        RotatedBox(
                          quarterTurns: 3, // 270 degrees
                          child: Text(
                            d['day'],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey : Colors.grey[600],
                            ),
                          ),
                        )
                      else
                        Text(
                          d['day'],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey : Colors.grey[600],
                          ),
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSurahList(bool isDark) {
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
                  : AppColors.dividerLight.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: ListTile(
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
                              : Colors.grey.withOpacity(0.1),
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
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                        const Text(
                          "In Progress",
                          style: TextStyle(
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
                      color: AppColors.accentOrange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${progress.revisionCount} Revs",
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
                "Surah ${surah.englishName}",
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildJuzList(bool isDark) {
    // 30 Juz
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
                  : AppColors.dividerLight.withOpacity(0.5),
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
                "Juz $juzNum",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: displayTasks.isNotEmpty
                  ? Text(
                      "${displayTasks.length} Active Tasks",
                      style: const TextStyle(color: AppColors.accentOrange),
                    )
                  : Text(
                      "${(estimatedProg * 100).toInt()}% Memorized",
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
                  title: const Text(
                    "View Juz History & Notes",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 16),
                  dense: true,
                  onTap: () => _showUnitDetails(
                    context,
                    PlanUnitType.juz,
                    juzNum,
                    "Juz $juzNum",
                  ),
                ),
                if (displayTasks.isNotEmpty) const Divider(),
                ...displayTasks.map((task) {
                  return ListTile(
                    title: Text(task.title),
                    subtitle: Text(
                      task.subtitle ??
                          (task.unitType == PlanUnitType.surah
                              ? "Surah Task"
                              : "Juz Task"),
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
                        );
                      } else {
                        _showUnitDetails(
                          context,
                          PlanUnitType.juz,
                          task.unitId,
                          task.title,
                        );
                      }
                    },
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHizbList(bool isDark) {
    // 60 Hizbs
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
                  : AppColors.dividerLight.withOpacity(0.5),
            ),
          ),
          child: ListTile(
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
            title: Text("Hizb $hizbNum (Juz $parentJuz)"),
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
                              ? "Active Task"
                              : "Covered by Juz ${parentJuz}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.accentOrange,
                          ),
                        ),
                      ],
                    ),
                  )
                : Text(
                    "${(hizbProg * 100).toInt()}% Memorized",
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
                "Hizb $hizbNum (Juz $parentJuz)",
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
    String title,
  ) {
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
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return FutureBuilder<List<TaskNote>>(
              future: PlannerDatabaseHelper().getNotesForUnit(type, unitId),
              builder: (context, snapshot) {
                return SingleChildScrollView(
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
                        title,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${type.displayName} Progress & Notes",
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
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
                            "Notes History",
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

                      if (!snapshot.hasData)
                        const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (snapshot.data!.isEmpty)
                        _buildEmptyNotesState(isDark)
                      else
                        ...snapshot.data!.map(
                          (note) => _buildNoteItem(note, isDark),
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
                          child: const Text("Close"),
                        ),
                      ),
                      SizedBox(
                        height: MediaQuery.of(context).viewInsets.bottom,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyNotesState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
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
            color: AppColors.textSecondaryLight.withOpacity(0.5),
          ),
          const SizedBox(height: 8),
          Text(
            "No notes recorded yet",
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
  }

  Widget _buildNoteItem(TaskNote note, bool isDark) {
    IconData icon;
    Color color;
    String typeLabel;

    switch (note.type) {
      case NoteType.doubt:
        icon = Icons.help_outline;
        color = AppColors.accentOrange;
        typeLabel = "Doubt";
        break;
      case NoteType.mistake:
        icon = Icons.error_outline;
        color = AppColors.errorRed;
        typeLabel = "Mistake";
        break;
      case NoteType.note:
        icon = Icons.edit_note;
        color = AppColors.primaryNavy;
        typeLabel = "Note";
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      typeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      DateFormat('MMM d').format(note.createdAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  note.content,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
