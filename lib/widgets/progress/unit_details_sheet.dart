import 'package:flutter/material.dart';
import '../../models/plan_task.dart';
import '../../services/planner_database_helper.dart';
import '../../theme/app_colors.dart';
import '../collapsible_note_card.dart';

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
                        child: const Text("Close"),
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
}
