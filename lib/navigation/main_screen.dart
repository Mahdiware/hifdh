import 'package:flutter/material.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';
import 'package:hifdh/shared/widgets/theme_toggle_button.dart';
import 'package:hifdh/features/dashboard/ui/dashboard_page.dart';
import 'package:hifdh/features/quiz/ui/quiz_page.dart';
import 'package:hifdh/features/progress/ui/progress_page.dart';
import 'package:hifdh/features/history/ui/history_page.dart';
import 'package:hifdh/features/settings/ui/settings_page.dart';
import 'package:hifdh/core/theme/app_background.dart';
import 'package:hifdh/core/theme/app_colors.dart';
import 'package:hifdh/core/services/planner_database.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const DashboardPage(),
    const QuizPage(),
    const ProgressPage(),
    const HistoryPage(),
    const SettingsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  String _getAppBarTitle(BuildContext context, int index) {
    final l10n = AppLocalizations.of(context)!;
    switch (index) {
      case 1:
        return l10n.quizSetup;
      case 2:
        return l10n.progress;
      case 3:
        return l10n.history;
      case 4:
        return l10n.settings;
      default:
        return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dashboard, Progress, and History provide their own app bars.
    // Quiz and Settings use the parent shell app bar.
    final showMainAppBar = _selectedIndex == 1 || _selectedIndex == 4;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return ValueListenableBuilder<bool>(
      valueListenable: PlannerDatabase().isUpgrading,
      builder: (context, upgrading, child) {
        if (upgrading) {
          return Scaffold(
            backgroundColor: isDark
                ? AppColors.backgroundDark
                : AppColors.backgroundLight,
            body: DecoratedBox(
              decoration: AppBackground.pageDecoration(theme),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    Text(
                      "Upgrading Database...",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Please wait while we update your data.",
                      style: TextStyle(
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: showMainAppBar
              ? AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  centerTitle: false,
                  titleSpacing: 20,
                  flexibleSpace: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDark
                            ? [
                                const Color(0xFF152B4C),
                                AppColors.backgroundDark,
                              ]
                            : [
                                const Color(0xFFEAF1FF),
                                AppColors.backgroundLight,
                              ],
                      ),
                    ),
                  ),
                  iconTheme: IconThemeData(
                    color: isDark ? Colors.white : AppColors.primaryNavy,
                  ),
                  title: Text(
                    _getAppBarTitle(context, _selectedIndex),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.primaryNavy,
                      fontSize: 22,
                      letterSpacing: -0.3,
                    ),
                  ),
                  actions: const [ThemeToggleButton(), SizedBox(width: 12)],
                )
              : null,
          body: SafeArea(
            top: false,
            child: IndexedStack(index: _selectedIndex, children: _pages),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [AppColors.surfaceDark, const Color(0xFF233A5C)]
                        : [Colors.white, const Color(0xFFF1F6FF)],
                  ),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : AppColors.dividerLight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.22 : 0.1,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: NavigationBar(
                  height: 68,
                  backgroundColor: Colors.transparent,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onItemTapped,
                  labelBehavior:
                      NavigationDestinationLabelBehavior.onlyShowSelected,
                  indicatorColor: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : AppColors.primaryNavy.withValues(alpha: 0.13),
                  destinations: [
                    NavigationDestination(
                      icon: const Icon(Icons.home_outlined),
                      selectedIcon: const Icon(Icons.home_filled),
                      label: l10n.dashboard,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.quiz_outlined),
                      selectedIcon: const Icon(Icons.quiz),
                      label: l10n.quiz,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.donut_large_outlined),
                      selectedIcon: const Icon(Icons.donut_large),
                      label: l10n.progress,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.history_outlined),
                      selectedIcon: const Icon(Icons.history),
                      label: l10n.history,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.settings_outlined),
                      selectedIcon: const Icon(Icons.settings),
                      label: l10n.settings,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
