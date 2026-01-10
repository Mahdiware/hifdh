import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hifdh/shared/models/plan_task.dart';
import 'package:hifdh/core/services/database_helper.dart';
import 'package:hifdh/core/theme/app_colors.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';

class CollapsibleNoteCard extends StatefulWidget {
  final TaskNote note;
  final String? ayahLabel; // e.g. "2:200" or just "200"

  const CollapsibleNoteCard({super.key, required this.note, this.ayahLabel});

  @override
  State<CollapsibleNoteCard> createState() => _CollapsibleNoteCardState();
}

class _CollapsibleNoteCardState extends State<CollapsibleNoteCard> {
  bool _isExpanded = false;
  Map<String, dynamic>? _ayahInfo;

  @override
  void initState() {
    super.initState();
    _loadAyahDetails();
  }

  Future<void> _loadAyahDetails() async {
    if (widget.note.ayahId != null) {
      final info = await DatabaseHelper().getAyahInfoById(widget.note.ayahId!);
      if (info != null && mounted) {
        setState(() {
          _ayahInfo = info;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    Color color;
    IconData icon;
    switch (widget.note.type) {
      case NoteType.note:
        color = isDark ? Colors.blue.shade200 : Colors.blue;
        icon = Icons.note;
        break;
      case NoteType.doubt:
        color = isDark ? AppColors.accentOrange : Colors.orange.shade800;
        icon = Icons.help_outline;
        break;
      case NoteType.mistake:
        color = isDark ? AppColors.errorRed : Colors.red.shade800;
        icon = Icons.warning_amber_rounded;
        break;
    }

    final hasContent = widget.note.content.isNotEmpty;

    String labelText;
    if (_ayahInfo != null) {
      labelText =
          "${l10n.ayah} ${_ayahInfo!['surahName']}:${_ayahInfo!['ayahNumber']}";
    } else {
      labelText = widget.ayahLabel ?? l10n.generalNote;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.1)
            : color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? color.withValues(alpha: 0.3)
              : color.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: hasContent
                ? () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  }
                : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          labelText,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: color,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          DateFormat(
                            'MMM d, h:mm a',
                          ).format(widget.note.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: color.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasContent)
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: color.withValues(alpha: 0.5),
                    ),
                ],
              ),
            ),
          ),
          if (_isExpanded && hasContent)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(height: 1, color: color.withValues(alpha: 0.1)),
                  const SizedBox(height: 8),
                  Text(
                    widget.note.content,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${widget.note.createdAt.day}/${widget.note.createdAt.month} ${widget.note.createdAt.hour}:${widget.note.createdAt.minute.toString().padLeft(2, '0')}",
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
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
