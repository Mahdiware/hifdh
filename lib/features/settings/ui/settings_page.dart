import 'package:flutter/material.dart';
import 'package:hifdh/core/services/app_version_info.dart';
import 'package:provider/provider.dart';
import '../logic/theme_provider.dart';
import '../logic/locale_provider.dart';
import '../logic/preferences_provider.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';
import 'package:hifdh/core/services/planner_database.dart';
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
      await PlannerDatabase().resetAllData();
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
        _buildLanguageSelector(localeProvider, l10n),
        const Divider(),
        _buildThemeSelector(themeProvider, l10n),
        const Divider(),
        _buildReadModeToggle(context, l10n),
        const Divider(),
        _buildBackupSection(context, l10n),
        _buildRestoreSection(context, l10n),
        const Divider(),
        _buildResetSection(context, l10n),
        const Divider(),
        _buildVersionInfo(context),
      ],
    );
  }

  Widget _buildVersionInfo(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.6,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "App Version",
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "${AppVersionInfo().version} (${AppVersionInfo().buildNumber})",
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelector(
    LocaleProvider provider,
    AppLocalizations l10n,
  ) {
    return ListTile(
      title: Text(l10n.language),
      leading: const Icon(Icons.language),
      trailing: DropdownButton<String>(
        value: provider.locale.languageCode,
        onChanged: (String? newValue) {
          if (newValue != null) {
            provider.setLocale(Locale(newValue));
          }
        },
        items: ['en', 'ar', 'so'].map((String code) {
          return DropdownMenuItem<String>(
            value: code,
            child: Text(_getLanguageName(code)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildThemeSelector(ThemeProvider provider, AppLocalizations l10n) {
    return ListTile(
      title: Text(l10n.theme),
      subtitle: Text(_getThemeText(provider.themeMode, l10n)),
      leading: Icon(
        provider.themeMode == ThemeMode.dark
            ? Icons.dark_mode
            : Icons.light_mode,
      ),
      trailing: DropdownButton<ThemeMode>(
        value: provider.themeMode,
        onChanged: (ThemeMode? newValue) {
          if (newValue != null) {
            provider.setThemeMode(newValue);
          }
        },
        items: [ThemeMode.system, ThemeMode.light, ThemeMode.dark].map((mode) {
          return DropdownMenuItem(
            value: mode,
            child: Text(_getThemeText(mode, l10n)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReadModeToggle(BuildContext context, AppLocalizations l10n) {
    return Consumer<PreferencesProvider>(
      builder: (context, prefs, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final isEnabled = prefs.defaultToReadMode;

        final activeColor = isDark
            ? const Color(0xFF64B5F6)
            : Theme.of(context).primaryColor;

        final iconColor = isEnabled
            ? activeColor
            : (isDark ? Colors.grey[400] : Colors.grey[600]);

        return SwitchListTile.adaptive(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 8,
          ),
          title: Text(
            l10n.defaultToReadMode,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l10n.defaultToReadModeDesc,
              style: TextStyle(
                fontSize: 13,
                height: 1.3,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          secondary: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (iconColor ?? Colors.blue).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isEnabled ? Icons.menu_book_rounded : Icons.touch_app_rounded,
              color: iconColor,
              size: 24,
            ),
          ),
          value: isEnabled,
          onChanged: (val) => prefs.toggleDefaultReadMode(val),
        );
      },
    );
  }

  Widget _buildBackupSection(BuildContext context, AppLocalizations l10n) {
    return ListTile(
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
    );
  }

  Widget _buildRestoreSection(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      title: Text(l10n.restoreBackup),
      subtitle: Text(l10n.restoreFromFile),
      leading: const Icon(Icons.restore_page_rounded),
      onTap: () async {
        try {
          final success = await BackupService().restore();
          if (context.mounted && success) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.backupRestored)));
            PlannerDatabase().dataUpdateNotifier.value++;
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.restoreFailed(e.toString()))),
            );
          }
        }
      },
    );
  }

  Widget _buildResetSection(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      title: Text(
        l10n.resetData,
        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(l10n.clearAllData),
      leading: const Icon(Icons.delete_forever, color: Colors.red),
      onTap: () => _confirmReset(context),
    );
  }
}
