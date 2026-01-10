import 'package:flutter/material.dart';
import 'package:hifdh/shared/models/plan_task.dart';
import 'package:hifdh/core/services/database_helper.dart';
import 'package:hifdh/core/services/planner_database_helper.dart';
import 'package:hifdh/shared/widgets/collapsible_note_card.dart';
import 'package:hifdh/features/dashboard/widgets/ayah_search_dialog.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';

class NotesSheet extends StatefulWidget {
  final PlanTask task;
  const NotesSheet({super.key, required this.task});

  @override
  State<NotesSheet> createState() => _NotesSheetState();
}

class _NotesSheetState extends State<NotesSheet> {
  final TextEditingController _noteController = TextEditingController();
  NoteType _selectedType = NoteType.note;
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
    final notes = await PlannerDatabaseHelper().getTaskNotes(widget.task.id!);
    if (mounted) {
      setState(() {
        _notes = notes;
        _loading = false;
      });
    }
  }

  Future<void> _loadAvailableAyahs() async {
    final rows = await DatabaseHelper().getAyahsForPlanUnit(
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
    if (_selectedAyahId == null)
      return AppLocalizations.of(context)!.selectSearchAyah;
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

    await PlannerDatabaseHelper().addNote(
      widget.task.id!,
      _noteController.text.trim(),
      _selectedType,
      ayahId: _selectedAyahId,
    );
    _noteController.clear();
    _loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      height:
          MediaQuery.of(context).size.height * 0.85, // Taller for more inputs
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "${l10n.notes}: ${widget.task.title}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _notes.isEmpty
                ? Center(child: Text(l10n.noNotesYet))
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
                        child: CollapsibleNoteCard(note: note),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Type Selector
                Row(
                  children: [
                    _buildTypeChip(l10n.note, NoteType.note, Colors.blue),
                    const SizedBox(width: 8),
                    _buildTypeChip(l10n.doubt, NoteType.doubt, Colors.orange),
                    const SizedBox(width: 8),
                    _buildTypeChip(l10n.mistake, NoteType.mistake, Colors.red),
                  ],
                ),
                const SizedBox(height: 12),

                // 2. Ayah Selector (Searchable)
                if (_availableAyahs.isNotEmpty)
                  InkWell(
                    onTap: _showAyahSearchDialog,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white10
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).dividerColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search,
                            size: 18,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _getSelectedAyahLabel(context),
                              style: TextStyle(
                                fontSize: 16,
                                fontFamily: 'QuranFont',
                                color: _selectedAyahId == null
                                    ? Colors.grey
                                    : (Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.white
                                          : Colors.black87),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      "Loading Ayahs...",
                      style: TextStyle(
                        fontFamily: 'QuranFont',
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                // 3. Input & Send
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _noteController,
                        decoration: InputDecoration(
                          hintText: l10n.descriptionOptional,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 0,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.blue),
                      onPressed: _addNote,
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

  Widget _buildTypeChip(String label, NoteType type, Color color) {
    final isSelected = _selectedType == type;
    return InkWell(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
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
