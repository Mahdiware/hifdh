import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:hifdh/shared/models/surah.dart';
import 'package:hifdh/shared/models/plan_task.dart';
import 'package:hifdh/core/services/quran_database.dart';
import 'package:hifdh/core/services/planner_database.dart';
import 'package:hifdh/core/theme/app_colors.dart';
import 'package:hifdh/features/quiz/ui/surah_selection_dialog.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';
import 'package:hifdh/shared/widgets/selection_card.dart';

class AssignPage extends StatefulWidget {
  final PlanTask? taskToEdit;

  const AssignPage({super.key, this.taskToEdit});

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
  static const List<String> _juzSubdivisions = [
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
  bool _isSaving = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _pageStartController.dispose();
    _pageEndController.dispose();
    _startAyahController.dispose();
    _endAyahController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final surahs = await QuranDatabase().getAllSurahs();
    if (mounted) {
      setState(() {
        _allSurahs = surahs;
        _isLoading = false;
      });
      if (widget.taskToEdit != null) {
        await _populateForEdit();
      }
    }
  }

  Future<void> _populateForEdit() async {
    final t = widget.taskToEdit!;
    _isRevision = t.type == TaskType.revision;
    _targetDate = t.deadline;

    // Unit Type
    if (t.unitType == PlanUnitType.surah) {
      _selectedUnitIndex = 0;
      // Find surah
      try {
        _selectedSurah = _allSurahs.firstWhere((s) => s.number == t.unitId);
        _maxAyah = await QuranDatabase().getSurahAyahCount(
          _selectedSurah!.number,
        );
        _startAyah = t.startAyah;
        _endAyah = t.endAyah;
        _startAyahController.text = _startAyah?.toString() ?? "";
        _endAyahController.text = _endAyah?.toString() ?? "";
      } catch (_) {}
    } else if (t.unitType == PlanUnitType.juz) {
      _selectedUnitIndex = 1;
      _selectedJuz = t.unitId;
      if (t.subtitle != null) {
        // Try to match subdivision
        if (_juzSubdivisions.contains(t.subtitle)) {
          _juzSubdivision = t.subtitle!;
        }
      }
    } else if (t.unitType == PlanUnitType.page) {
      _selectedUnitIndex = 2;
      _pageStartController.text = t.unitId.toString();
      _pageEndController.text = (t.endUnitId ?? t.unitId).toString();
    }
    setState(() {});
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
      final max = await QuranDatabase().getSurahAyahCount(selected.number);
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
    final isMemorized = await PlannerDatabase().isSurahFullyMemorized(
      surah.number,
    );

    _checkIsMemorized(isMemorized, "This", surah.englishName);
  }

  Future<void> _checkJuzMemorization(int juz) async {
    final isMemorized = await PlannerDatabase().isJuzFullyMemorized(juz);
    _checkIsMemorized(isMemorized, "This", "Juz");
  }

  void _checkPageSelection() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1000), () async {
      final start = int.tryParse(_pageStartController.text);
      final end = int.tryParse(_pageEndController.text);

      if (start != null && end != null && start <= end) {
        final isMemorized = await PlannerDatabase().isPageRangeFullyMemorized(
          start,
          end,
        );

        if (mounted) {
          _checkIsMemorized(isMemorized, "These", "pages");
        }
      }
    });
  }

  void _checkIsMemorized(bool isMemorized, String prefix, String type) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isMemorized && !_isRevision) {
      setState(() {
        _isRevision = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.contentMemorizedSwitch,
              style: TextStyle(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            backgroundColor: AppColors.primaryNavy,
          ),
        );
      }
      return;
    }

    if (!isMemorized && _isRevision) {
      setState(() {
        _isRevision = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.contentNotMemorizedSwitch,
              style: TextStyle(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            backgroundColor: AppColors.primaryNavy,
          ),
        );
      }
      return;
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        setState(() {
          _targetDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      } else {
        setState(() {
          _targetDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            23,
            59,
          );
        });
      }
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
          AppLocalizations.of(context)!.createNewPlan,
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
                    AppLocalizations.of(context)!.memorize,
                    !_isRevision,
                    () => setState(() => _isRevision = false),
                    isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTypeButton(
                    AppLocalizations.of(context)!.revision,
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
                    : AppColors.dividerLight.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _buildTab(AppLocalizations.of(context)!.surah, 0, isDark),
                  _buildTab(AppLocalizations.of(context)!.juz, 1, isDark),
                  _buildTab(AppLocalizations.of(context)!.page, 2, isDark),
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
            SelectionCard(
              title: _targetDate == null
                  ? AppLocalizations.of(context)!.selectDeadline
                  : DateFormat(
                      'EEE, MMM d, yyyy - h:mm a',
                    ).format(_targetDate!),
              icon: Icons.calendar_today,
              onTap: _selectDate,
              isSelected: _targetDate != null,
            ),

            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _savePlan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentOrange,
                  disabledBackgroundColor: AppColors.accentOrange.withValues(
                    alpha: 0.6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        widget.taskToEdit != null
                            ? AppLocalizations.of(context)!.edit
                            : AppLocalizations.of(context)!.createPlan,
                        style: const TextStyle(
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
                      color: Colors.black.withValues(alpha: 0.1),
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
    return Column(
      children: [
        SelectionCard(
          title:
              _selectedSurah?.englishName ??
              AppLocalizations.of(context)!.selectSurah,
          icon: Icons.menu_book,
          onTap: _selectSurah,
          isSelected: _selectedSurah != null,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildNumberInput(
                AppLocalizations.of(context)!.startAyah,
                (val) => _startAyah = val,
                helperText: _maxAyah != null ? "Max: $_maxAyah" : null,
                controller: _startAyahController,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildNumberInput(
                AppLocalizations.of(context)!.endAyah,
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
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.selectJuz,
          style: const TextStyle(fontWeight: FontWeight.bold),
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
          child: DropdownButton<int>(
            value: _selectedJuz,
            isExpanded: true,
            underline: Container(),
            dropdownColor: isDark
                ? AppColors.surfaceDark
                : AppColors.surfaceLight,
            style: Theme.of(context).textTheme.bodyLarge,
            items: List.generate(30, (i) => i + 1).map((idx) {
              return DropdownMenuItem(
                value: idx,
                child: Text("${l10n.juz} $idx"),
              );
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
        Text(
          l10n.subdivision,
          style: const TextStyle(fontWeight: FontWeight.bold),
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
              String label = s;
              if (s == 'Full Juz') {
                label = l10n.fullJuz;
              } else if (s.startsWith('Hizb')) {
                // "Hizb 1"
                final parts = s.split(' ');
                if (parts.length == 2) label = "${l10n.hizb} ${parts[1]}";
              } else if (s.startsWith('Nisf Hizb')) {
                // "Nisf Hizb 1"
                final parts = s.split(' ');
                if (parts.length == 3) label = "${l10n.nisfHizb} ${parts[2]}";
              } else if (s.startsWith('Rubuc')) {
                // "Rubuc 1"
                final parts = s.split(' ');
                if (parts.length == 2) label = "${l10n.rubuc} ${parts[1]}";
              }
              return DropdownMenuItem(value: s, child: Text(label));
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
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.startPage,
            ),
            onChanged: (_) => _checkPageSelection(),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextField(
            controller: _pageEndController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.endPage,
            ),
            onChanged: (_) => _checkPageSelection(),
          ),
        ),
      ],
    );
  }

  Future<void> _savePlan() async {
    if (_isSaving) return;

    if (_targetDate == null) {
      _showError(AppLocalizations.of(context)!.pleaseSelectDeadline);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      PlanTask newTask;
      var type = _isRevision ? TaskType.revision : TaskType.memorize;
      final created = DateTime.now();

      if (_selectedUnitIndex == 0) {
        // SURAH
        if (_selectedSurah == null) {
          _showError(AppLocalizations.of(context)!.pleaseSelectSurah);
          setState(() {
            _isSaving = false;
          });
          return;
        }

        // Check Memorization Status (Surah)
        final isMemorized = await PlannerDatabase().isSurahFullyMemorized(
          _selectedSurah!.number,
        );
        if (!mounted) {
          setState(() => _isSaving = false);
          return;
        }

        if (isMemorized && !_isRevision) {
          type = TaskType.revision;
          if (mounted) {
            _showError(AppLocalizations.of(context)!.contentMemorizedSwitch);
          }
        } else if (!isMemorized && _isRevision) {
          type = TaskType.memorize;
          if (mounted) {
            _showError(AppLocalizations.of(context)!.contentNotMemorizedSwitch);
          }
        }

        final start = _startAyah ?? 1;
        final end = _endAyah ?? _maxAyah ?? 1;

        if (_maxAyah != null) {
          if (start < 1 || start > _maxAyah!) {
            _showError(
              AppLocalizations.of(context)!.startAyahErrorRange(_maxAyah!),
            );
            if (mounted) setState(() => _isSaving = false);
            return;
          }
          if (end < 1 || end > _maxAyah!) {
            _showError(
              AppLocalizations.of(context)!.endAyahErrorRange(_maxAyah!),
            );
            if (mounted) setState(() => _isSaving = false);
            return;
          }
        }

        if (start > end) {
          _showError(AppLocalizations.of(context)!.startAyahErrorOrder);
          if (mounted) setState(() => _isSaving = false);
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
          subtitle: "${AppLocalizations.of(context)!.ayah} $start - $end",
        );
      } else if (_selectedUnitIndex == 1) {
        // Check Memorization Status (Juz)
        // We start logically with Full Juz check.
        final isJuzMemorized = await PlannerDatabase().isJuzFullyMemorized(
          _selectedJuz,
        );
        if (!mounted) return;

        // If whole Juz is memorized, any part is revision
        if (isJuzMemorized && !_isRevision) {
          type = TaskType.revision;
          if (mounted) {
            _showError(AppLocalizations.of(context)!.contentMemorizedSwitch);
          }
        } else if (!isJuzMemorized &&
            _isRevision &&
            _juzSubdivision == "Full Juz") {
          // Only force Memorize if selecting whole Juz and it's not done
          type = TaskType.memorize;
          if (mounted) {
            _showError(AppLocalizations.of(context)!.contentNotMemorizedSwitch);
          }
        }

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

        // Localize Title only if creating new task
        final l10n = AppLocalizations.of(context)!;

        String title = "${l10n.juz} $_selectedJuz";
        if (_juzSubdivision != "Full Juz") {
          String subLabel = _juzSubdivision;
          if (_juzSubdivision.startsWith('Hizb')) {
            final parts = _juzSubdivision.split(' ');
            if (parts.length == 2) subLabel = "${l10n.hizb} ${parts[1]}";
          } else if (_juzSubdivision.startsWith('Nisf Hizb')) {
            final parts = _juzSubdivision.split(' ');
            if (parts.length == 3) subLabel = "${l10n.nisfHizb} ${parts[2]}";
          } else if (_juzSubdivision.startsWith('Rubuc')) {
            final parts = _juzSubdivision.split(' ');
            if (parts.length == 2) subLabel = "${l10n.rubuc} ${parts[1]}";
          }
          title = "$title - $subLabel";
        }

        newTask = PlanTask(
          unitType: PlanUnitType.juz,
          unitId: _selectedJuz,
          title: title,
          subtitle:
              _juzSubdivision, // Logic uses English string for identification, but display should be localized. DB stores English.
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
          _showError(AppLocalizations.of(context)!.pleaseEnterValidPages);
          if (mounted) setState(() => _isSaving = false);
          return;
        }

        // Check Memorization Status (Pages)
        final isMemorized = await PlannerDatabase().isPageRangeFullyMemorized(
          start,
          end,
        );
        if (!mounted) return;

        if (isMemorized && !_isRevision) {
          type = TaskType.revision;
          if (mounted) {
            _showError(AppLocalizations.of(context)!.contentMemorizedSwitch);
          }
        } else if (!isMemorized && _isRevision) {
          type = TaskType.memorize;
          if (mounted) {
            _showError(AppLocalizations.of(context)!.contentNotMemorizedSwitch);
          }
        }

        final l10n = AppLocalizations.of(context)!;
        newTask = PlanTask(
          unitType: PlanUnitType.page,
          unitId: start,
          endUnitId: end,
          title: "${l10n.page} $start - $end",
          type: type,
          deadline: _targetDate!,
          createdAt: created,
        );
      }

      if (widget.taskToEdit != null) {
        // Update
        newTask = newTask.copyWith(
          id: widget.taskToEdit!.id!,
          title: newTask.title,
          status: widget.taskToEdit!.status,
          completedAt: widget.taskToEdit!.completedAt,
          note: widget.taskToEdit!.note,
        );
        await PlannerDatabase().updateTask(newTask);
      } else {
        await PlannerDatabase().insertTask(newTask);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.taskToEdit != null
                  ? AppLocalizations.of(context)!
                        .planCreatedSuccess // Reuse success msg or add Edit success
                  : AppLocalizations.of(context)!.planCreatedSuccess,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error saving plan: $e");
      if (mounted) {
        setState(() => _isSaving = false);
        _showError(e.toString());
      }
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
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
            ),
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
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
