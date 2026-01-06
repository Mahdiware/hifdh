import 'package:flutter/material.dart';
import '../../models/surah.dart';

class SurahSelectionDialog extends StatefulWidget {
  final List<Surah> initialSelectedSurahs;
  final List<Surah> availableSurahs;
  final bool isSingleSelection;

  const SurahSelectionDialog({
    super.key,
    required this.initialSelectedSurahs,
    required this.availableSurahs,
    this.isSingleSelection = false,
  });

  @override
  State<SurahSelectionDialog> createState() => _SurahSelectionDialogState();
}

class _SurahSelectionDialogState extends State<SurahSelectionDialog> {
  late List<Surah> _selectedSurahs;
  late List<Surah> _filteredSurahs;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedSurahs = List.from(widget.initialSelectedSurahs);
    _filteredSurahs = widget.availableSurahs;
    _searchController.addListener(_filterSurahs);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterSurahs() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredSurahs = widget.availableSurahs;
      } else {
        _filteredSurahs = widget.availableSurahs.where((surah) {
          return surah.name.contains(query) ||
              surah.englishName.toLowerCase().contains(query) ||
              surah.number.toString().contains(query);
        }).toList();
      }
    });
  }

  void _toggleSurah(Surah surah) {
    setState(() {
      if (widget.isSingleSelection) {
        _selectedSurahs = [surah];
      } else {
        if (_selectedSurahs.contains(surah)) {
          _selectedSurahs.remove(surah);
        } else {
          _selectedSurahs.add(surah);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Select Surahs',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search Surah...',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredSurahs.length,
              itemBuilder: (context, index) {
                final surah = _filteredSurahs[index];
                final isSelected = _selectedSurahs.contains(surah);
                return CheckboxListTile(
                  title: Text(
                    surah.glyph,
                    style: const TextStyle(
                      fontFamily: 'SurahFont',
                      fontSize: 24,
                    ),
                  ),
                  subtitle: Text("${surah.number}. ${surah.englishName}"),
                  value: isSelected,
                  onChanged: (bool? value) {
                    _toggleSurah(surah);
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, _selectedSurahs),
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
