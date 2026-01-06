import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/surah.dart';
import '../../models/quiz_settings.dart';
import '../../services/database_helper.dart';
import 'surah_selection_dialog.dart';
import 'quiz_home_page.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  bool _isPageRangeExpanded = false;
  bool _isSurahRangeExpanded = false;
  List<Surah> _selectedSurahs = [];
  List<Surah> _allSurahs = [];

  final TextEditingController _fromPageController = TextEditingController();
  final TextEditingController _toPageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadSurahs();
  }

  Future<void> _loadSurahs() async {
    final surahs = await DatabaseHelper().getAllSurahs();
    setState(() {
      _allSurahs = surahs;
    });
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to 1-604 if not set
    int start = prefs.getInt('start_page') ?? 1;
    int end = prefs.getInt('end_page') ?? 604;

    setState(() {
      _fromPageController.text = start.toString();
      _toPageController.text = end.toString();
    });
  }

  Future<void> _savePreferences(int start, int end) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('start_page', start);
    await prefs.setInt('end_page', end);
  }

  void _togglePageRange() {
    setState(() {
      _isPageRangeExpanded = !_isPageRangeExpanded;
      if (_isPageRangeExpanded) {
        _isSurahRangeExpanded = false;
      }
    });
  }

  void _toggleSurahRange() {
    setState(() {
      _isSurahRangeExpanded = !_isSurahRangeExpanded;
      if (_isSurahRangeExpanded) {
        _isPageRangeExpanded = false;
      }
    });
  }

  Future<void> _showSurahSelectionDialog() async {
    if (_allSurahs.isEmpty) {
      await _loadSurahs();
    }

    if (!mounted) return;

    final result = await showDialog<List<Surah>>(
      context: context,
      builder: (context) => SurahSelectionDialog(
        initialSelectedSurahs: _selectedSurahs,
        availableSurahs: _allSurahs,
      ),
    );

    if (result != null) {
      setState(() {
        _selectedSurahs = result;
        // Sort by number
        _selectedSurahs.sort((a, b) => a.number.compareTo(b.number));
      });
    }
  }

  void _startTesting() {
    if (!_isPageRangeExpanded && !_isSurahRangeExpanded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select Type 'Page Range' or 'Surah Selection'"),
        ),
      );
      return;
    }

    if (_isSurahRangeExpanded) {
      if (_selectedSurahs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select at least one Surah")),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuizHomePage(
            settings: QuizSettings(
              surahNumbers: _selectedSurahs.map((s) => s.number).toList(),
            ),
          ),
        ),
      );
      return;
    }

    String startText = _fromPageController.text.trim();
    String endText = _toPageController.text.trim();

    if (startText.isEmpty || endText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter both start and end pages")),
      );
      return;
    }

    int? start = int.tryParse(startText);
    int? end = int.tryParse(endText);

    if (start == null || end == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Invalid number format")));
      return;
    }

    if (start < 1 || end < 1 || start > end || end > 604) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid page range (1-604)")),
      );
      return;
    }

    _savePreferences(start, end);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizHomePage(
          settings: QuizSettings(startPage: start, endPage: end),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // CONTENT
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Page Range Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text(
                          "Page Range",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        trailing: Icon(
                          _isPageRangeExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                        ),
                        onTap: _togglePageRange,
                      ),
                      if (_isPageRangeExpanded)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _fromPageController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: "From Page",
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextField(
                                  controller: _toPageController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: "To Page",
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Surah Selection Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text(
                          "Surah Selection",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        trailing: Icon(
                          _isSurahRangeExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                        ),
                        onTap: _toggleSurahRange,
                      ),
                      if (_isSurahRangeExpanded)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _showSurahSelectionDialog,
                                icon: const Icon(Icons.add),
                                label: const Text("Select Surahs"),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              if (_selectedSurahs.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  height: 250, // Defined size
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.withOpacity(0.3),
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ListView.separated(
                                    itemCount: _selectedSurahs.length,
                                    separatorBuilder: (context, index) =>
                                        const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final surah = _selectedSurahs[index];
                                      return ListTile(
                                        title: Text(
                                          surah.glyph,
                                          style: const TextStyle(
                                            fontFamily: 'SurahFont',
                                            fontSize: 24,
                                          ),
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _selectedSurahs.remove(surah);
                                            });
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Start Button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _startTesting,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: const Text(
                "Start Quiz",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
