import 'package:flutter/material.dart';
import '../widgets/theme_toggle_button.dart';
import 'dashboard_page.dart';
import 'quiz/quiz_page.dart';
import 'progress_page.dart';
import 'history_page.dart';
import 'settings_page.dart';
import '../theme/app_colors.dart';

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

  String _getAppBarTitle(int index) {
    switch (index) {
      case 1:
        return "Quiz Setup";
      case 2:
        return "Progress";
      case 3:
        return "History";
      case 4:
        return "Settings";
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

    return Scaffold(
      appBar: showMainAppBar
          ? AppBar(
              backgroundColor: isDark
                  ? AppColors.backgroundDark
                  : AppColors.primaryNavy,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Text(
                _getAppBarTitle(_selectedIndex),
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: "Dashboard",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.quiz_outlined),
            label: "Quiz",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.donut_large),
            label: "Progress",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: "More"),
        ],
      ),
    );
  }
}
