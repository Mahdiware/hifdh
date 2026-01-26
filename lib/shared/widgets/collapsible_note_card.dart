import 'package:flutter/material.dart';
import 'package:hifdh/core/utils/open_quran.dart';
import 'package:intl/intl.dart';
import 'package:hifdh/shared/models/plan_task.dart';
import 'package:hifdh/core/services/database_helper.dart';
import 'package:hifdh/core/theme/app_colors.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';

class CollapsibleNoteCard extends StatefulWidget {
  final TaskNote note;
  final String? ayahLabel; // e.g. "2:200" or just "200"
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const CollapsibleNoteCard({
    super.key,
    required this.note,
    this.ayahLabel,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<CollapsibleNoteCard> createState() => _CollapsibleNoteCardState();
}

class _CollapsibleNoteCardState extends State<CollapsibleNoteCard> {
  // State Variables
  bool _isExpanded = false;
  Map<String, dynamic>? _ayahInfo;

  // Convenience Getters
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  AppLocalizations get _l10n => AppLocalizations.of(context)!;
  bool get _hasContent => widget.note.content.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadAyahDetails();
  }

  @override
  void didUpdateWidget(CollapsibleNoteCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.note.ayahId != oldWidget.note.ayahId ||
        widget.note.id != oldWidget.note.id) {
      _ayahInfo = null;
      _loadAyahDetails();
    }
  }

  Future<void> _loadAyahDetails() async {
    if (widget.note.ayahId == null) return;

    // Skip loading for transient notes
    if (widget.note.id != null && widget.note.id! < 0) return;

    final info = await DatabaseHelper().getAyahInfoById(widget.note.ayahId!);
    if (info != null && mounted) {
      setState(() => _ayahInfo = info);
    }
  }

  // --- Helper Methods ---
  (Color, IconData) _getStyle() {
    switch (widget.note.type) {
      case NoteType.correct:
        return (
          _isDark ? Colors.green.shade200 : AppColors.successGreen,
          Icons.check_circle_outline,
        );
      case NoteType.doubt:
        return (
          _isDark ? AppColors.accentOrange : Colors.orange.shade800,
          Icons.help_outline,
        );
      case NoteType.mistake:
        return (
          _isDark ? AppColors.errorRed : Colors.red.shade800,
          Icons.cancel_outlined,
        );
    }
  }

  String _getLabel() {
    if (_ayahInfo != null) {
      return "${_l10n.ayah} ${_ayahInfo!['surahName']}:${_ayahInfo!['ayahNumber']}";
    }
    return widget.ayahLabel ?? _l10n.generalNote;
  }

  // --- Widget Builders ---

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _getStyle();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _isDark
            ? color.withValues(alpha: 0.1)
            : color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isDark
              ? color.withValues(alpha: 0.3)
              : color.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: _hasContent
                ? () => setState(() => _isExpanded = !_isExpanded)
                : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: _buildHeaderInfo(color)),
                  _buildActionMenu(color),
                  if (_hasContent) ...[
                    const SizedBox(width: 4),
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: color.withValues(alpha: 0.5),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_isExpanded && _hasContent) _buildExpandedContent(color),
        ],
      ),
    );
  }

  Widget _buildHeaderInfo(Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getLabel(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 16,
          ),
        ),
        Text(
          DateFormat('MMM d, h:mm a').format(widget.note.createdAt),
          style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.7)),
        ),
      ],
    );
  }

  Widget _buildActionMenu(Color color) {
    if (widget.onEdit == null && widget.onDelete == null) {
      // Even if no edit/delete, show the menu for "Open in Quran app" if we have ayah info
      if (_ayahInfo == null) return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: color),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == 'edit') widget.onEdit?.call();
        if (value == 'delete') widget.onDelete?.call();

        final surah = _ayahInfo!['surahNumber'] as int;
        final ayah = _ayahInfo!['ayahNumber'] as int;
        if (value == 'open_quran') openQuranLink(surah, ayah);
      },
      itemBuilder: (context) => [
        if (widget.onEdit != null)
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                const Icon(Icons.edit, size: 20),
                const SizedBox(width: 12),
                Text(_l10n.edit),
              ],
            ),
          ),
        if (_ayahInfo != null)
          const PopupMenuItem(
            value: 'open_quran',
            child: Row(
              children: [
                Icon(Icons.menu_book_rounded, size: 20),
                SizedBox(width: 12),
                Text('Open in Quran app'),
              ],
            ),
          ),
        if (widget.onDelete != null)
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline, color: AppColors.errorRed, size: 20),
                const SizedBox(width: 12),
                Text(_l10n.delete, style: TextStyle(color: AppColors.errorRed)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildExpandedContent(Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 1, color: color.withValues(alpha: 0.1)),
          const SizedBox(height: 12),
          Text(
            widget.note.content,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: _isDark ? Colors.grey[300] : Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
}
