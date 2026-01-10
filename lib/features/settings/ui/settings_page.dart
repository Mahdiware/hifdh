import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/theme_provider.dart';
import '../logic/locale_provider.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';
import 'package:hifdh/core/services/planner_database_helper.dart';
import 'package:hifdh/core/services/backup_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _confirmReset(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.resetDataConfirmation),
        content: Text(l10n.resetDataWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.resetEverything),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await PlannerDatabaseHelper().resetAllData();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.dataResetSuccess)));
      }
    }
  }

  String _getThemeText(ThemeMode mode, AppLocalizations l10n) {
    switch (mode) {
      case ThemeMode.system:
        return l10n.systemTheme;
      case ThemeMode.light:
        return l10n.lightTheme;
      case ThemeMode.dark:
        return l10n.darkTheme;
    }
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'ar':
        return 'العربية';
      case 'so':
        return 'Soomaali';
      case 'en':
      default:
        return 'English';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Language Selector
        ListTile(
          title: Text(l10n.language),
          leading: const Icon(Icons.language),
          trailing: DropdownButton<String>(
            value: localeProvider.locale.languageCode,
            onChanged: (String? newValue) {
              if (newValue != null) {
                localeProvider.setLocale(Locale(newValue));
              }
            },
            items: ['en', 'ar', 'so'].map((String code) {
              return DropdownMenuItem<String>(
                value: code,
                child: Text(_getLanguageName(code)),
              );
            }).toList(),
          ),
        ),
        const Divider(),

        // Theme Selector
        ListTile(
          title: Text(l10n.theme),
          subtitle: Text(_getThemeText(themeProvider.themeMode, l10n)),
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
            items: [
              DropdownMenuItem(
                value: ThemeMode.system,
                child: Text(l10n.systemTheme),
              ),
              DropdownMenuItem(
                value: ThemeMode.light,
                child: Text(l10n.lightTheme),
              ),
              DropdownMenuItem(
                value: ThemeMode.dark,
                child: Text(l10n.darkTheme),
              ),
            ],
          ),
        ),
        const Divider(),

        // Backup
        ListTile(
          title: Text(l10n.createBackup),
          subtitle: Text(l10n.backupToFile),
          leading: const Icon(Icons.download_rounded),
          onTap: () async {
            try {
              await BackupService().backup();
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(l10n.backupCreated)));
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.backupFailed(e.toString()))),
                );
              }
            }
          },
        ),

        // Restore
        ListTile(
          title: Text(l10n.restoreBackup),
          subtitle: Text(l10n.restoreFromFile),
          leading: const Icon(Icons.restore_page_rounded),
          onTap: () async {
            // Re-using simplified restore flow for now, can localize confirmation similarly to reset if needed
            // For now assuming direct file pick
            try {
              final success = await BackupService().restore();
              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(l10n.backupRestored)));
                  // Trigger UI update across the app
                  PlannerDatabaseHelper().dataUpdateNotifier.value++;
                }
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.restoreFailed(e.toString()))),
                );
              }
            }
          },
        ),
        const Divider(),

        // Reset
        ListTile(
          title: Text(
            l10n.resetData,
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(l10n.clearAllData),
          leading: const Icon(Icons.delete_forever, color: Colors.red),
          onTap: () => _confirmReset(context),
        ),
      ],
    );
  }
}
