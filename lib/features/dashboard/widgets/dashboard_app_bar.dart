import 'package:flutter/material.dart';
import 'package:hifdh/core/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';
import 'package:hifdh/features/settings/logic/locale_provider.dart';
import 'package:hifdh/shared/widgets/theme_toggle_button.dart';

class DashboardAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onRefresh;
  final VoidCallback? onOpenRevisionQueue;

  const DashboardAppBar({
    super.key,
    required this.onRefresh,
    this.onOpenRevisionQueue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final iconColor = isDark ? Colors.white : AppColors.primaryNavy;

    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 20,
      title: Text(
        l10n.dashboard,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: titleColor,
          fontSize: 24,
          letterSpacing: -0.4,
        ),
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF13284A), AppColors.backgroundDark]
                : [const Color(0xFFE9F1FF), AppColors.backgroundLight],
          ),
        ),
      ),
      iconTheme: IconThemeData(color: iconColor),

      actions: [
        if (onOpenRevisionQueue != null)
          _ActionIconButton(
            icon: Icons.auto_graph_rounded,
            iconColor: iconColor,
            isDark: isDark,
            tooltip: l10n.revisionQueueTitle,
            onPressed: onOpenRevisionQueue,
          ),
        _ActionIconButton(
          icon: Icons.refresh_rounded,
          iconColor: iconColor,
          isDark: isDark,
          tooltip: MaterialLocalizations.of(
            context,
          ).refreshIndicatorSemanticLabel,
          onPressed: onRefresh,
        ),
        Consumer<LocaleProvider>(
          builder: (context, localeProvider, child) {
            return PopupMenuButton<Locale>(
              tooltip: l10n.language,
              color: isDark ? AppColors.surfaceDark : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              icon: _ActionIconSurface(
                isDark: isDark,
                iconColor: iconColor,
                child: const Icon(Icons.language_rounded),
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
        const SizedBox(width: 12),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isDark;
  final Color iconColor;

  const _ActionIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.isDark,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4),
      child: Tooltip(
        message: tooltip,
        child: IconButton(
          onPressed: onPressed,
          icon: _ActionIconSurface(
            isDark: isDark,
            iconColor: iconColor,
            child: Icon(icon),
          ),
        ),
      ),
    );
  }
}

class _ActionIconSurface extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final Color iconColor;

  const _ActionIconSurface({
    required this.child,
    required this.isDark,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.12)
            : AppColors.primaryNavy.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.22)
              : AppColors.primaryNavy.withValues(alpha: 0.16),
        ),
      ),
      alignment: Alignment.center,
      child: IconTheme(
        data: IconThemeData(color: iconColor, size: 20),
        child: child,
      ),
    );
  }
}
