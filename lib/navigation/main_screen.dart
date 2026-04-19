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
import 'package:hifdh/shared/widgets/liquid_glass.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool? _configuredLowMemoryMode;

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

  String _compactNavLabel(String text) {
    const maxChars = 10;
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars - 1)}…';
  }

  bool _isLowMemoryDevice(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final smallPhone = mediaQuery.size.shortestSide <= 430;
    final lowDensity = mediaQuery.devicePixelRatio <= 2.75;

    return smallPhone && lowDensity;
  }

  @override
  Widget build(BuildContext context) {
    // Dashboard, Progress, and History provide their own app bars.
    // Quiz and Settings use the parent shell app bar.
    final showMainAppBar = _selectedIndex == 1 || _selectedIndex == 4;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final navTextScale = MediaQuery.textScalerOf(
      context,
    ).scale(1).clamp(0.85, 1.0);
    final navSelectedColor = isDark ? Colors.white : AppColors.primaryNavy;
    final navUnselectedColor = isDark
        ? Colors.white70
        : const Color(0xFF4D5C71);
    final navIndicatorColor = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : const Color(0xFFBCD0EE);
    final lowMemoryMode = _isLowMemoryDevice(context);

    if (_configuredLowMemoryMode != lowMemoryMode) {
      _configuredLowMemoryMode = lowMemoryMode;
      PlannerDatabase().configureMemoryMode(
        lowMemoryMode: lowMemoryMode,
        cacheIdleTtl: lowMemoryMode
            ? const Duration(seconds: 45)
            : const Duration(minutes: 3),
      );
    }

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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: LiquidGlass(
                    blur: 24,
                    borderRadius: BorderRadius.circular(28),
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
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
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
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
            child: lowMemoryMode
                ? KeyedSubtree(
                    key: ValueKey<int>(_selectedIndex),
                    child: _pages[_selectedIndex],
                  )
                : IndexedStack(index: _selectedIndex, children: _pages),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
              child: LiquidGlass(
                padding: EdgeInsets.zero,
                blur: 20,
                borderRadius: BorderRadius.circular(20),
                tint: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.7),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.16)
                      : Colors.white.withValues(alpha: 0.9),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 9),
                  ),
                ],
                child: MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(navTextScale)),
                  child: NavigationBarTheme(
                    data: NavigationBarThemeData(
                      iconTheme: WidgetStateProperty.resolveWith((states) {
                        final selected = states.contains(WidgetState.selected);
                        return IconThemeData(
                          color: selected
                              ? navSelectedColor
                              : navUnselectedColor,
                          size: selected ? 23 : 22,
                        );
                      }),
                      labelTextStyle: WidgetStateProperty.resolveWith((states) {
                        final selected = states.contains(WidgetState.selected);
                        return TextStyle(
                          fontSize: selected ? 11 : 10,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          letterSpacing: -0.1,
                          color: selected
                              ? navSelectedColor
                              : navUnselectedColor,
                        );
                      }),
                      indicatorShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: NavigationBar(
                      height: 68,
                      backgroundColor: Colors.transparent,
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: _onItemTapped,
                      labelBehavior:
                          NavigationDestinationLabelBehavior.alwaysShow,
                      indicatorColor: navIndicatorColor,
                      destinations: [
                        NavigationDestination(
                          icon: const Icon(Icons.home_outlined),
                          selectedIcon: const Icon(Icons.home_filled),
                          label: _compactNavLabel(l10n.dashboard),
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.quiz_outlined),
                          selectedIcon: const Icon(Icons.quiz),
                          label: _compactNavLabel(l10n.quiz),
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.donut_large_outlined),
                          selectedIcon: const Icon(Icons.donut_large),
                          label: _compactNavLabel(l10n.progress),
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.history_outlined),
                          selectedIcon: const Icon(Icons.history),
                          label: _compactNavLabel(l10n.history),
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.settings_outlined),
                          selectedIcon: const Icon(Icons.settings),
                          label: _compactNavLabel(l10n.settings),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
