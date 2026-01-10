import 'package:flutter/material.dart';
import 'package:hifdh/shared/models/plan_task.dart';
import 'package:hifdh/core/services/planner_database_helper.dart';
import 'package:hifdh/core/theme/app_colors.dart';
import 'package:hifdh/shared/widgets/collapsible_note_card.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';

class UnitDetailsSheet extends StatelessWidget {
  final PlanUnitType type;
  final int unitId;
  final String title;
  final List<TaskNote>? preloadedNotes;

  const UnitDetailsSheet({
    super.key,
    required this.type,
    required this.unitId,
    required this.title,
    this.preloadedNotes,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    String typeName;
    switch (type) {
      case PlanUnitType.surah:
        typeName = l10n.surah;
        break;
      case PlanUnitType.juz:
        typeName = l10n.juz;
        break;
      case PlanUnitType.page:
        typeName = l10n.page;
        break;
      default:
        typeName = "Custom";
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        final notes = preloadedNotes;
        final future = notes != null
            ? Future.value(notes)
            : PlannerDatabaseHelper().getNotesForUnit(type, unitId);

        return FutureBuilder<List<TaskNote>>(
          future: future,
          builder: (context, snapshot) {
            return ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: SingleChildScrollView(
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
                      "$typeName ${l10n.progressAndNotes}",
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
                          l10n.notesHistory,
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

                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (!snapshot.hasData || snapshot.data!.isEmpty)
                      _buildEmptyNotesState(isDark)
                    else
                      ...snapshot.data!.map(
                        (note) => CollapsibleNoteCard(note: note),
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
                        child: Text(l10n.close),
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyNotesState(bool isDark) {
    // We need context here or pass l10n.
    // Since _buildEmptyNotesState is called inside builder, let's grab context or make it instance method.
    // Wait, context is available via closure but better pass it?
    // Actually this is a Stateless Widget method, context needs to be passed.
    // I'll grab it using Builder or just use stateless build context if available in scope.
    // Ah, `_buildEmptyNotesState(isDark)` is called. I'll modify the call site or use a Builder.
    // Easier: modify parameters to accept context.
    return Builder(
      builder: (context) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.backgroundDark
                : AppColors.backgroundLight,
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
                color: AppColors.textSecondaryLight.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.noNotesRecordedYet,
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
      },
    );
  }
}
