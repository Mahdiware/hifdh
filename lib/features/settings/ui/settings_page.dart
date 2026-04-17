import 'package:flutter/material.dart';
import 'package:hifdh/core/services/app_version_info.dart';
import 'package:hifdh/core/services/backup_service.dart';
import 'package:hifdh/core/services/planner_database.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

import '../logic/locale_provider.dart';
import '../logic/preferences_provider.dart';
import '../logic/theme_provider.dart';

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

  String _getFontOptionText(String option) {
    switch (option) {
      case ThemeProvider.robotoFontOption:
        return 'Roboto';
      case ThemeProvider.serifFontOption:
        return 'Serif';
      case ThemeProvider.monoFontOption:
        return 'Monospace';
      case ThemeProvider.systemFontOption:
      default:
        return 'System';
    }
  }

  String _getFontScaleText(double scale) {
    final percent = (scale * 100).round();
    if (percent == 100) return 'Default (100%)';
    if (percent < 100) return 'Smaller ($percent%)';
    return 'Larger ($percent%)';
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
      padding: const EdgeInsets.all(16),
      children: [
        _buildSettingsHero(context, l10n),
        const SizedBox(height: 14),
        _buildSectionCard(
          context,
          icon: Icons.tune_rounded,
          title: l10n.settings,
          children: [
            _buildLanguageSelector(localeProvider, l10n),
            const Divider(height: 20),
            _buildThemeSelector(themeProvider, l10n),
            const Divider(height: 20),
            _buildFontSelector(themeProvider),
            const Divider(height: 20),
            _buildFontSizeSelector(context, themeProvider),
            const Divider(height: 20),
            _buildReadModeToggle(context, l10n),
          ],
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          context,
          icon: Icons.auto_graph_rounded,
          title: l10n.revisionQueueTitle,
          children: [_buildRevisionQueueSettings(context, l10n)],
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          context,
          icon: Icons.storage_rounded,
          title: '${l10n.createBackup} / ${l10n.restoreBackup}',
          children: [
            _buildBackupSection(context, l10n),
            const Divider(height: 20),
            _buildRestoreSection(context, l10n),
            const Divider(height: 20),
            _buildResetSection(context, l10n),
          ],
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          context,
          icon: Icons.info_outline_rounded,
          title: l10n.appVersion,
          children: [_buildVersionInfo(context, l10n)],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSettingsHero(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withValues(alpha: 0.18),
            colorScheme.tertiary.withValues(alpha: 0.18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.settings_rounded, color: colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.settings,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${l10n.language} • ${l10n.theme} • ${l10n.revisionQueueTitle}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildVersionInfo(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.appVersion,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${AppVersionInfo().version} (${AppVersionInfo().buildNumber})',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector(
    LocaleProvider provider,
    AppLocalizations l10n,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(l10n.language),
      leading: const Icon(Icons.language),
      trailing: DropdownButton<String>(
        value: provider.locale.languageCode,
        underline: const SizedBox.shrink(),
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
      contentPadding: EdgeInsets.zero,
      title: Text(l10n.theme),
      subtitle: Text(_getThemeText(provider.themeMode, l10n)),
      leading: Icon(
        provider.themeMode == ThemeMode.dark
            ? Icons.dark_mode
            : Icons.light_mode,
      ),
      trailing: DropdownButton<ThemeMode>(
        value: provider.themeMode,
        underline: const SizedBox.shrink(),
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

  Widget _buildFontSelector(ThemeProvider provider) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('App Font'),
      subtitle: Text(_getFontOptionText(provider.fontOption)),
      leading: const Icon(Icons.text_fields_rounded),
      trailing: DropdownButton<String>(
        value: provider.fontOption,
        underline: const SizedBox.shrink(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            provider.setFontOption(newValue);
          }
        },
        items: ThemeProvider.availableFontOptions.map((option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Text(_getFontOptionText(option)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFontSizeSelector(BuildContext context, ThemeProvider provider) {
    final minScale = ThemeProvider.availableTextScaleOptions.first;
    final maxScale = ThemeProvider.availableTextScaleOptions.last;
    final currentScale = provider.textScaleFactor.clamp(minScale, maxScale);
    final isDefault =
        (currentScale - ThemeProvider.defaultTextScale).abs() < 0.001;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.format_size_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Font Size'),
                  const SizedBox(height: 2),
                  Text(
                    _getFontScaleText(currentScale),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Text(
              '${(currentScale * 100).round()}%',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: isDefault
                  ? null
                  : () {
                      provider.setTextScaleFactor(
                        ThemeProvider.defaultTextScale,
                      );
                    },
              child: const Text('Center'),
            ),
          ],
        ),
        Slider(
          min: minScale,
          max: maxScale,
          divisions: ThemeProvider.availableTextScaleOptions.length - 1,
          value: currentScale,
          label: _getFontScaleText(currentScale),
          onChanged: (value) {
            provider.setTextScaleFactor(value);
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Text('A-', style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              Text('A', style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              Text('A+', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
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
          contentPadding: EdgeInsets.zero,
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
              color: (iconColor ?? Theme.of(context).colorScheme.primary)
                  .withValues(alpha: 0.15),
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

  Widget _buildRevisionQueueSettings(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<PreferencesProvider>(
      builder: (context, prefs, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.queueSettingsDescription,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.queueIncludeMastered),
              subtitle: Text(l10n.queueIncludeMasteredDescription),
              value: prefs.revisionQueueIncludeMastered,
              onChanged: (value) {
                prefs.toggleRevisionQueueIncludeMastered(value);
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                l10n.queueDailyTarget(prefs.revisionQueueDailyTarget),
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Slider(
              min: 5,
              max: 100,
              divisions: 19,
              value: prefs.revisionQueueDailyTarget.toDouble(),
              label: '${prefs.revisionQueueDailyTarget}',
              onChanged: (value) {
                prefs.setRevisionQueueDailyTarget(value.round());
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildBackupSection(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(l10n.createBackup),
      subtitle: Text(l10n.backupToFile),
      leading: const Icon(Icons.download_rounded),
      onTap: () async {
        try {
          await BackupService().backup(l10n);
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
      contentPadding: EdgeInsets.zero,
      title: Text(l10n.restoreBackup),
      subtitle: Text(l10n.restoreFromFile),
      leading: const Icon(Icons.restore_page_rounded),
      onTap: () async {
        try {
          final success = await BackupService().restore(l10n);
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
      contentPadding: EdgeInsets.zero,
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
