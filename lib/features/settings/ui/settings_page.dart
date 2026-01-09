import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/theme_provider.dart';
import 'package:hifdh/core/services/planner_database_helper.dart';
import 'package:hifdh/core/services/backup_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reset All Data?"),
        content: const Text(
          "This will delete all your tasks, notes, and progress history. This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Reset Everything"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await PlannerDatabaseHelper().resetAllData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("All data has been reset.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        ListTile(
          title: const Text('Theme'),
          subtitle: Text(
            themeProvider.themeMode == ThemeMode.system
                ? 'System Default'
                : themeProvider.themeMode == ThemeMode.dark
                ? 'Dark Mode'
                : 'Light Mode',
          ),
          leading: Icon(
            themeProvider.themeMode == ThemeMode.dark
                ? Icons.dark_mode
                : Icons.light_mode,
          ),
          trailing: DropdownButton<ThemeMode>(
            value: themeProvider.themeMode,
            onChanged: (ThemeMode? newValue) {
              if (newValue != null) {
                themeProvider.setThemeMode(newValue);
              }
            },
            items: const [
              DropdownMenuItem(
                value: ThemeMode.system,
                child: Text('System Default'),
              ),
              DropdownMenuItem(
                value: ThemeMode.light,
                child: Text('Light Mode'),
              ),
              DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark Mode')),
            ],
          ),
        ),
        const Divider(),
        ListTile(
          title: const Text('Backup Data'),
          subtitle: const Text('Backup your planner data to a file'),
          leading: const Icon(Icons.download_rounded),
          onTap: () async {
            try {
              await BackupService().backup();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Backup saved successfully")),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("Backup failed: $e")));
              }
            }
          },
        ),
        ListTile(
          title: const Text('Restore Data'),
          subtitle: const Text('Restore from a backup file'),
          leading: const Icon(Icons.restore_page_rounded),
          onTap: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text("Restore Data?"),
                content: const Text(
                  "This will replace all your current data with the backup. Current data will be lost.",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text("Cancel"),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text("Restore"),
                  ),
                ],
              ),
            );

            if (confirm == true) {
              try {
                final success = await BackupService().restore();
                if (context.mounted) {
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Data restored successfully"),
                      ),
                    );
                    // Trigger UI update across the app
                    PlannerDatabaseHelper().dataUpdateNotifier.value++;
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text("Restore failed: $e")));
                }
              }
            }
          },
        ),
        const Divider(),
        ListTile(
          title: const Text(
            'Reset Planner Data',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          subtitle: const Text('Clear all tasks and progress'),
          leading: const Icon(Icons.delete_forever, color: Colors.red),
          onTap: () => _confirmReset(context),
        ),
      ],
    );
  }
}
