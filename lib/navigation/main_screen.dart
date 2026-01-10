import 'package:flutter/material.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';
import 'package:hifdh/shared/widgets/theme_toggle_button.dart';
import 'package:hifdh/features/dashboard/ui/dashboard_page.dart';
import 'package:hifdh/features/quiz/ui/quiz_page.dart';
import 'package:hifdh/features/progress/ui/progress_page.dart';
import 'package:hifdh/features/history/ui/history_page.dart';
import 'package:hifdh/features/settings/ui/settings_page.dart';
import 'package:hifdh/core/theme/app_colors.dart';

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
    // Only show the parent AppBar if the current page doesn't have one.
    // DashboardPage (index 0) has its own AppBar.
    bool showMainAppBar = _selectedIndex != 0;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: showMainAppBar
          ? AppBar(
              backgroundColor: isDark
                  ? AppColors.backgroundDark
                  : AppColors.primaryNavy,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Text(
                _getAppBarTitle(context, _selectedIndex),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 20,
                ),
              ),
              actions: const [ThemeToggleButton(), SizedBox(width: 8)],
            )
          : null,
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_filled),
            label: l10n.dashboard,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.quiz_outlined),
            label: l10n.quiz,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.donut_large),
            label: l10n.progress,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.history),
            label: l10n.history,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: l10n.settings,
          ),
        ],
      ),
    );
  }
}
