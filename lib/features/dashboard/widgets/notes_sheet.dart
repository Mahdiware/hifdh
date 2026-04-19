import 'package:flutter/material.dart';
import 'package:hifdh/shared/models/plan_task.dart';
import 'package:hifdh/core/services/quran_database.dart';
import 'package:hifdh/core/services/planner_database.dart';
import 'package:hifdh/shared/widgets/collapsible_note_card.dart';
import 'package:hifdh/features/dashboard/widgets/ayah_search_dialog.dart';
import 'package:hifdh/core/theme/app_colors.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';
import 'package:hifdh/shared/widgets/liquid_glass.dart';

class NotesSheet extends StatefulWidget {
  final PlanTask task;
  const NotesSheet({super.key, required this.task});

  @override
  State<NotesSheet> createState() => _NotesSheetState();
}

class _NotesSheetState extends State<NotesSheet> {
  final TextEditingController _noteController = TextEditingController();
  NoteType _selectedType = NoteType.mistake;
  List<TaskNote> _notes = [];
  bool _loading = true;

  // Ayah Selection
  List<Map<String, dynamic>> _availableAyahs = [];
  int? _selectedAyahId;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _loadAvailableAyahs();
  }

  Future<void> _loadNotes() async {
    final notes = await PlannerDatabase().getTaskNotes(widget.task.id!);
    if (mounted) {
      setState(() {
        _notes = notes;
        _loading = false;
      });
    }
  }

  Future<void> _loadAvailableAyahs() async {
    final rows = await QuranDatabase().getAyahsForPlanUnit(
      unitType: widget.task.unitType,
      unitId: widget.task.unitId,
      endUnitId: widget.task.endUnitId,
      startAyah: widget.task.startAyah,
      endAyah: widget.task.endAyah,
    );

    if (mounted) {
      setState(() {
        _availableAyahs = rows;
        if (_availableAyahs.isNotEmpty) {
          _selectedAyahId = _availableAyahs.first['id'] as int;
        }
      });
    }
  }

  String _getSelectedAyahLabel(BuildContext context) {
    if (_selectedAyahId == null) {
      return AppLocalizations.of(context)!.selectSearchAyah;
    }
    final match = _availableAyahs.firstWhere(
      (e) => e['id'] == _selectedAyahId,
      orElse: () => {},
    );
    if (match.isEmpty) return AppLocalizations.of(context)!.unknownAyah;
    return "${match['surahNumber']}:${match['ayahNumber']} - ${match['text']}";
  }

  void _showAyahSearchDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AyahSearchDialog(
          ayahs: _availableAyahs,
          onSelected: (id) {
            setState(() => _selectedAyahId = id);
          },
        );
      },
    );
  }

  Future<void> _addNote() async {
    // Description is optional, but we need an ayah selected
    if (_selectedAyahId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseSelectAyah)),
      );
      return;
    }

    await PlannerDatabase().addNote(
      widget.task.id!,
      _noteController.text.trim(),
      _selectedType,
      ayahId: _selectedAyahId,
    );
    _noteController.clear();
    _loadNotes();
  }

  Future<void> _deleteNote(int id) async {
    await PlannerDatabase().deleteTaskNote(id);
    _loadNotes();
  }

  void _editNote(TaskNote note) {
    final controller = TextEditingController(text: note.content);
    NoteType selectedType = note.type;
    int? selectedAyahId = note.ayahId;

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final l10n = AppLocalizations.of(context)!;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            String ayahLabel = l10n.selectSearchAyah;
            if (selectedAyahId != null && _availableAyahs.isNotEmpty) {
              final match = _availableAyahs.firstWhere(
                (e) => e['id'] == selectedAyahId,
                orElse: () => {},
              );
              if (match.isNotEmpty) {
                ayahLabel =
                    "${match['surahNumber']}:${match['ayahNumber']} - ${match['text']}";
              } else {
                ayahLabel = l10n.unknownAyah;
              }
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LiquidGlass(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  borderRadius: BorderRadius.circular(20),
                  blur: 18,
                  tint: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.74),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black26,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.edit,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildDialogTypeChip(
                            l10n.doubt,
                            NoteType.doubt,
                            Colors.orange,
                            selectedType,
                            (t) => setDialogState(() => selectedType = t),
                          ),
                          _buildDialogTypeChip(
                            l10n.mistake,
                            NoteType.mistake,
                            Colors.red,
                            selectedType,
                            (t) => setDialogState(() => selectedType = t),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_availableAyahs.isNotEmpty) ...[
                        InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => AyahSearchDialog(
                                ayahs: _availableAyahs,
                                onSelected: (id) {
                                  setDialogState(() => selectedAyahId = id);
                                },
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: LiquidGlass(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            blur: 8,
                            tint: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.white.withValues(alpha: 0.76),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white10
                                  : AppColors.dividerLight,
                            ),
                            boxShadow: const [],
                            child: Row(
                              children: [
                                Icon(
                                  Icons.search,
                                  size: 18,
                                  color: isDark
                                      ? Colors.white70
                                      : AppColors.primaryNavy,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    ayahLabel,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark
                                          ? AppColors.textPrimaryDark
                                          : AppColors.textPrimaryLight,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  size: 20,
                                  color: isDark
                                      ? Colors.white60
                                      : AppColors.textSecondaryLight,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      LiquidGlass(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        borderRadius: BorderRadius.circular(12),
                        blur: 8,
                        tint: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.white.withValues(alpha: 0.76),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : AppColors.dividerLight,
                        ),
                        boxShadow: const [],
                        child: TextField(
                          controller: controller,
                          minLines: 1,
                          maxLines: 3,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: l10n.descriptionOptional,
                            hintStyle: TextStyle(
                              color: isDark
                                  ? Colors.white54
                                  : AppColors.textSecondaryLight,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            fillColor: Colors.transparent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(l10n.cancel),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () async {
                              final navigator = Navigator.of(context);
                              await PlannerDatabase().updateTaskNoteEntry(
                                note.id!,
                                controller.text.trim(),
                                selectedType,
                                ayahId: selectedAyahId,
                              );
                              if (mounted) {
                                navigator.pop();
                                _loadNotes();
                              }
                            },
                            child: Text(l10n.edit),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDialogTypeChip(
    String label,
    NoteType type,
    Color color,
    NoteType currentSelection,
    Function(NoteType) onSelect,
  ) {
    final isSelected = currentSelection == type;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => onSelect(type),
      child: LiquidGlass(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        borderRadius: BorderRadius.circular(20),
        blur: 8,
        tint: isSelected
            ? color.withValues(alpha: isDark ? 0.95 : 0.88)
            : color.withValues(alpha: isDark ? 0.2 : 0.12),
        border: Border.all(
          color: isSelected
              ? Colors.transparent
              : color.withValues(alpha: isDark ? 0.35 : 0.25),
        ),
        boxShadow: const [],
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: LiquidGlass(
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
            : const Color(0x66DCEBFF),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[350],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  children: [
                    Text(
                      widget.task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.notesHistory,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _notes.isEmpty
                    ? Center(
                        child: LiquidGlass(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          blur: 10,
                          tint: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.white.withValues(alpha: 0.72),
                          border: Border.all(
                            color: isDark
                                ? Colors.white10
                                : AppColors.dividerLight,
                          ),
                          child: Text(
                            l10n.noNotesYet,
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _notes.length,
                        itemBuilder: (context, index) {
                          final note = _notes[index];
                          // Use CollapsibleNoteCard directly
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: CollapsibleNoteCard(
                              note: note,
                              onEdit: () => _editNote(note),
                              onDelete: () => _deleteNote(note.id!),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: LiquidGlass(
                  padding: const EdgeInsets.all(12),
                  borderRadius: BorderRadius.circular(18),
                  blur: 14,
                  tint: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.72),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : AppColors.dividerLight,
                  ),
                  boxShadow: const [],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Type Selector
                      Row(
                        children: [
                          _buildTypeChip(
                            l10n.doubt,
                            NoteType.doubt,
                            Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          _buildTypeChip(
                            l10n.mistake,
                            NoteType.mistake,
                            Colors.red,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Ayah Selector (Searchable)
                      if (_availableAyahs.isNotEmpty)
                        InkWell(
                          onTap: _showAyahSearchDialog,
                          borderRadius: BorderRadius.circular(8),
                          child: LiquidGlass(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            blur: 8,
                            tint: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.white.withValues(alpha: 0.76),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).dividerColor.withValues(alpha: 0.2),
                            ),
                            boxShadow: const [],
                            child: Row(
                              children: [
                                Icon(
                                  Icons.search,
                                  size: 18,
                                  color: isDark
                                      ? Colors.white70
                                      : AppColors.primaryNavy,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _getSelectedAyahLabel(context),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontFamily: 'QuranFont',
                                      color: _selectedAyahId == null
                                          ? (isDark
                                                ? Colors.white60
                                                : AppColors.textSecondaryLight)
                                          : (isDark
                                                ? Colors.white
                                                : AppColors.textPrimaryLight),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  color: isDark ? Colors.white70 : Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            l10n.loadingAyahs,
                            style: TextStyle(
                              fontFamily: 'QuranFont',
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),

                      const SizedBox(height: 12),

                      // Input & Send
                      LiquidGlass(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        borderRadius: BorderRadius.circular(12),
                        blur: 8,
                        tint: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.white.withValues(alpha: 0.76),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : AppColors.dividerLight,
                        ),
                        boxShadow: const [],
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _noteController,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                decoration: InputDecoration(
                                  hintText: l10n.descriptionOptional,
                                  hintStyle: TextStyle(
                                    color: isDark
                                        ? Colors.white54
                                        : AppColors.textSecondaryLight,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: false,
                                  fillColor: Colors.transparent,
                                ),
                              ),
                            ),
                            LiquidGlass(
                              padding: EdgeInsets.zero,
                              borderRadius: BorderRadius.circular(999),
                              blur: 8,
                              tint: isDark
                                  ? const Color(
                                      0xFF5A7EA8,
                                    ).withValues(alpha: 0.35)
                                  : const Color(
                                      0xFF58779A,
                                    ).withValues(alpha: 0.22),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white12
                                    : AppColors.primaryNavy.withValues(
                                        alpha: 0.2,
                                      ),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: isDark
                                      ? const Color(0xFF5A7EA8)
                                      : const Color(0xFF58779A),
                                ),
                                onPressed: _addNote,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label, NoteType type, Color color) {
    final isSelected = _selectedType == type;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => setState(() => _selectedType = type),
      child: LiquidGlass(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        borderRadius: BorderRadius.circular(20),
        blur: 8,
        tint: isSelected
            ? color.withValues(alpha: isDark ? 0.95 : 0.88)
            : color.withValues(alpha: isDark ? 0.2 : 0.12),
        border: Border.all(
          color: isSelected
              ? Colors.transparent
              : color.withValues(alpha: isDark ? 0.35 : 0.25),
        ),
        boxShadow: const [],
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
