import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';
import 'package:hifdh/features/settings/logic/locale_provider.dart';
import 'package:hifdh/shared/widgets/theme_toggle_button.dart';

class DashboardAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onRefresh;

  const DashboardAppBar({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: theme.appBarTheme.backgroundColor,
      elevation: 0,
      title: Text(l10n.dashboard, style: theme.appBarTheme.titleTextStyle),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh, color: theme.appBarTheme.iconTheme?.color),
          onPressed: onRefresh,
        ),
        Consumer<LocaleProvider>(
          builder: (context, localeProvider, child) {
            return PopupMenuButton<Locale>(
              icon: Icon(
                Icons.language,
                color: theme.appBarTheme.iconTheme?.color,
              ),
              onSelected: (Locale locale) {
                localeProvider.setLocale(locale);
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<Locale>>[
                PopupMenuItem<Locale>(
                  value: Locale('en'),
                  child: Text(l10n.languageEnglish),
                ),
                PopupMenuItem<Locale>(
                  value: Locale('ar'),
                  child: Text(l10n.languageArabic),
                ),
                PopupMenuItem<Locale>(
                  value: Locale('so'),
                  child: Text(l10n.languageSomali),
                ),
              ],
            );
          },
        ),
        const ThemeToggleButton(),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
