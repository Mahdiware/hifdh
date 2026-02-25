import 'package:flutter/material.dart';
import 'package:hifdh/core/theme/app_colors.dart';
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
    final isDark = theme.brightness == Brightness.dark;

    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      elevation: 0,
      title: Text(
        l10n.dashboard,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black,
          fontSize: 20,
        ),
      ),
      iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),

      actions: [
        IconButton(
          icon: Icon(
            Icons.refresh,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: onRefresh,
        ),
        Consumer<LocaleProvider>(
          builder: (context, localeProvider, child) {
            return PopupMenuButton<Locale>(
              icon: Icon(
                Icons.language,
                color: isDark ? Colors.white : Colors.black              ),
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
