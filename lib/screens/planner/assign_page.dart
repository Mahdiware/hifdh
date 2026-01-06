import 'package:flutter/material.dart';
import '../../models/surah.dart';
import '../../models/plan_task.dart';
import '../../services/database_helper.dart';
import '../../services/planner_database_helper.dart';
import '../../theme/app_colors.dart';
import '../quiz/surah_selection_dialog.dart';

class AssignPage extends StatefulWidget {
  const AssignPage({super.key});

  @override
  State<AssignPage> createState() => _AssignPageState();
}

class _AssignPageState extends State<AssignPage> {
  // Navigation / Tabs
  int _selectedUnitIndex = 0; // 0: Surah, 1: Juz, 2: Page

  // Common Form State
  bool _isRevision = false;
  DateTime? _targetDate;

  // Surah Mode
  Surah? _selectedSurah;
  int? _startAyah;
  int? _endAyah;
  int? _maxAyah;

  // Juz Mode
  int _selectedJuz = 1;
  String _juzSubdivision = "Full Juz";
  final List<String> _juzSubdivisions = [
    "Full Juz",
    "Hizb 1",
    "Hizb 2",
    "Nisf Hizb 1",
    "Nisf Hizb 2",
    "Nisf Hizb 3",
    "Nisf Hizb 4",
    "Rubuc 1",
    "Rubuc 2",
    "Rubuc 3",
    "Rubuc 4",
    "Rubuc 5",
    "Rubuc 6",
    "Rubuc 7",
    "Rubuc 8",
  ];

  // Page Mode
  final TextEditingController _pageStartController = TextEditingController();
  final TextEditingController _pageEndController = TextEditingController();

  // Surah Mode Controllers
  final TextEditingController _startAyahController = TextEditingController();
  final TextEditingController _endAyahController = TextEditingController();

  // Data
  List<Surah> _allSurahs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _pageStartController.dispose();
    _pageEndController.dispose();
    _startAyahController.dispose();
    _endAyahController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final surahs = await DatabaseHelper().getAllSurahs();
    setState(() {
      _allSurahs = surahs;
      _isLoading = false;
    });
  }

  Future<void> _selectSurah() async {
    if (_allSurahs.isEmpty) return;

    final result = await showDialog<List<Surah>>(
      context: context,
      builder: (context) => SurahSelectionDialog(
        initialSelectedSurahs: _selectedSurah != null ? [_selectedSurah!] : [],
        availableSurahs: _allSurahs,
        isSingleSelection: true,
      ),
    );

    if (result != null && result.isNotEmpty) {
      final selected = result.first;
      final max = await DatabaseHelper().getSurahAyahCount(selected.number);
      setState(() {
        _selectedSurah = selected;
        _maxAyah = max;
        _startAyah = 1;
        _endAyah = max;
        _startAyahController.text = "1";
        _endAyahController.text = max.toString();
      });

      _checkSurahMemorization(selected);
    }
  }

  Future<void> _checkSurahMemorization(Surah surah) async {
    final isMemorized = await PlannerDatabaseHelper().isSurahFullyMemorized(
      surah.number,
    );
    if (isMemorized && !_isRevision) {
      setState(() {
        _isRevision = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "${surah.englishName} is already memorized. Switched to Revision.",
            ),
            backgroundColor: AppColors.primaryNavy,
          ),
        );
      }
    }
  }

  Future<void> _checkJuzMemorization(int juz) async {
    final isMemorized = await PlannerDatabaseHelper().isJuzFullyMemorized(juz);
    if (isMemorized && !_isRevision) {
      setState(() {
        _isRevision = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "This Juz is already memorized. Switched to Revision.",
            ),
            backgroundColor: AppColors.primaryNavy,
          ),
        );
      }
    }
  }

  void _checkPageSelection() {
    final start = int.tryParse(_pageStartController.text);
    final end = int.tryParse(_pageEndController.text);

    if (start != null && end != null && start <= end) {
      _checkPageMemorization(start, end);
    }
  }

  Future<void> _checkPageMemorization(int start, int end) async {
    final isMemorized = await PlannerDatabaseHelper().isPageRangeFullyMemorized(
      start,
      end,
    );

    if (isMemorized && !_isRevision) {
      setState(() {
        _isRevision = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "These pages are already memorized. Switched to Revision.",
            ),
            backgroundColor: AppColors.primaryNavy,
          ),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() {
        _targetDate = picked;
      });
    }
  }

  void _onUnitChanged(int index) {
    setState(() {
      _selectedUnitIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          "Create New Plan",
          style: TextStyle(
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(
          color: isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimaryLight,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Plan Type Selector (Memorize vs Revision)
            Row(
              children: [
                Expanded(
                  child: _buildTypeButton(
                    "Memorize",
                    !_isRevision,
                    () => setState(() => _isRevision = false),
                    isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTypeButton(
                    "Revision",
                    _isRevision,
                    () => setState(() => _isRevision = true),
                    isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Unit Tabs (Surah / Juz / Page)
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceDark
                    : AppColors.dividerLight.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _buildTab("Surah", 0, isDark),
                  _buildTab("Juz", 1, isDark),
                  _buildTab("Page", 2, isDark),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // DYNAMIC CONTENT BASED ON SELECTION
            if (_selectedUnitIndex == 0) _buildSurahSelector(),
            if (_selectedUnitIndex == 1) _buildJuzSelector(),
            if (_selectedUnitIndex == 2) _buildPageSelector(),

            const SizedBox(height: 24),

            // Deadline
            InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isDark ? Colors.transparent : AppColors.dividerLight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: isDark
                      ? AppColors.surfaceDark
                      : AppColors.surfaceLight,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _targetDate == null
                          ? "Select Deadline"
                          : "${_targetDate!.day}/${_targetDate!.month}/${_targetDate!.year}",
                      style: TextStyle(
                        fontSize: 16,
                        color: _targetDate == null
                            ? (isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight)
                            : (isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _savePlan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentOrange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  "Create Plan",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String title, int index, bool isDark) {
    final isSelected = _selectedUnitIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onUnitChanged(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.accentOrange : AppColors.surfaceLight)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? (isDark ? Colors.white : AppColors.primaryNavy)
                  : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSurahSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        InkWell(
          onTap: _selectSurah,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? Colors.transparent : AppColors.dividerLight,
              ),
              borderRadius: BorderRadius.circular(12),
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.menu_book,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                const SizedBox(width: 12),
                Text(
                  _selectedSurah?.englishName ?? "Select Surah",
                  style: TextStyle(
                    fontSize: 16,
                    color: _selectedSurah == null
                        ? (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight)
                        : (isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildNumberInput(
                "Start Ayah",
                (val) => _startAyah = val,
                helperText: _maxAyah != null ? "Max: $_maxAyah" : null,
                controller: _startAyahController,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildNumberInput(
                "End Ayah",
                (val) => _endAyah = val,
                helperText: _maxAyah != null ? "Max: $_maxAyah" : null,
                controller: _endAyahController,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildJuzSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Select Juz", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            border: Border.all(
              color: isDark ? Colors.transparent : AppColors.dividerLight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButton<int>(
            value: _selectedJuz,
            isExpanded: true,
            underline: Container(),
            dropdownColor: isDark
                ? AppColors.surfaceDark
                : AppColors.surfaceLight,
            style: Theme.of(context).textTheme.bodyLarge,
            items: List.generate(30, (i) => i + 1).map((idx) {
              return DropdownMenuItem(value: idx, child: Text("Juz $idx"));
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedJuz = val);
                _checkJuzMemorization(val);
              }
            },
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "Subdivision",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            border: Border.all(
              color: isDark ? Colors.transparent : AppColors.dividerLight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButton<String>(
            value: _juzSubdivision,
            isExpanded: true,
            underline: Container(),
            dropdownColor: isDark
                ? AppColors.surfaceDark
                : AppColors.surfaceLight,
            style: Theme.of(context).textTheme.bodyLarge,
            items: _juzSubdivisions.map((s) {
              return DropdownMenuItem(value: s, child: Text(s));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _juzSubdivision = val);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPageSelector() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _pageStartController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Start Page"),
            onChanged: (_) => _checkPageSelection(),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextField(
            controller: _pageEndController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "End Page"),
            onChanged: (_) => _checkPageSelection(),
          ),
        ),
      ],
    );
  }

  Future<void> _savePlan() async {
    if (_targetDate == null) {
      _showError("Please select a deadline");
      return;
    }

    PlanTask newTask;
    final type = _isRevision ? TaskType.revision : TaskType.memorize;
    final created = DateTime.now();

    if (_selectedUnitIndex == 0) {
      // SURAH
      if (_selectedSurah == null) {
        _showError("Please select a Surah");
        return;
      }

      final start = _startAyah ?? 1;
      final end = _endAyah ?? _maxAyah ?? 1;

      if (_maxAyah != null) {
        if (start < 1 || start > _maxAyah!) {
          _showError("Start Ayah must be between 1 and $_maxAyah");
          return;
        }
        if (end < 1 || end > _maxAyah!) {
          _showError("End Ayah must be between 1 and $_maxAyah");
          return;
        }
      }

      if (start > end) {
        _showError("Start Ayah cannot be after End Ayah");
        return;
      }

      newTask = PlanTask(
        unitType: PlanUnitType.surah,
        unitId: _selectedSurah!.number,
        title: _selectedSurah!.englishName,
        startAyah: start,
        endAyah: end,
        type: type,
        deadline: _targetDate!,
        createdAt: created,
        subtitle: "Ayah $start - $end",
      );
    } else if (_selectedUnitIndex == 1) {
      // JUZ
      // Calculate Rubuc Range for Granular Juz Tasks
      // 1 Juz = 8 Rubucs. Rubuc ID in DB is global (1-240).
      int startRub = 0;
      int endRub = 0;
      final base = (_selectedJuz - 1) * 8;

      if (_juzSubdivision == "Hizb 1") {
        startRub = base + 1;
        endRub = base + 4;
      } else if (_juzSubdivision == "Hizb 2") {
        startRub = base + 5;
        endRub = base + 8;
      } else if (_juzSubdivision.startsWith("Nisf Hizb")) {
        // Nisf Hizb 1..4
        // Nisf 1 = Rub 1-2, Nisf 2 = Rub 3-4, etc.
        final n = int.parse(_juzSubdivision.split(" ").last);
        startRub = base + (n - 1) * 2 + 1;
        endRub = startRub + 1;
      } else if (_juzSubdivision.startsWith("Rubuc")) {
        // Rubuc 1..8
        final n = int.parse(_juzSubdivision.split(" ").last);
        startRub = base + n;
        endRub = base + n;
      }

      newTask = PlanTask(
        unitType: PlanUnitType.juz,
        unitId: _selectedJuz,
        title: "Juz $_selectedJuz",
        subtitle: _juzSubdivision,
        type: type,
        deadline: _targetDate!,
        createdAt: created,
        // We use startAyah/endAyah fields to act as Global Rubuc Start/End for Juz tasks
        startAyah: startRub > 0 ? startRub : null,
        endAyah: endRub > 0 ? endRub : null,
      );
    } else {
      // PAGE
      final start = int.tryParse(_pageStartController.text);
      final end = int.tryParse(_pageEndController.text);
      if (start == null || end == null) {
        _showError("Please enter valid pages");
        return;
      }
      newTask = PlanTask(
        unitType: PlanUnitType.page,
        unitId: start,
        endUnitId: end,
        title: "Page $start - $end",
        type: type,
        deadline: _targetDate!,
        createdAt: created,
      );
    }

    await PlannerDatabaseHelper().insertTask(newTask);

    if (mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Plan Created Successfully!")),
      );
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _buildTypeButton(
    String title,
    bool isSelected,
    VoidCallback onTap,
    bool isDark,
  ) {
    if (isSelected) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
          ],
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.accentOrange : AppColors.primaryNavy,
          ),
        ),
      );
    } else {
      return InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildNumberInput(
    String label,
    Function(int?) onChanged, {
    String? helperText,
    TextEditingController? controller,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      onChanged: (val) => onChanged(int.tryParse(val)),
    );
  }
}
