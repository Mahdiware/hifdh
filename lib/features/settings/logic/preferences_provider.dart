import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesProvider extends ChangeNotifier {
  bool _defaultToReadMode = false;

  bool get defaultToReadMode => _defaultToReadMode;

  PreferencesProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _defaultToReadMode = prefs.getBool('default_ayah_read_mode') ?? false;
    notifyListeners();
  }

  Future<void> toggleDefaultReadMode(bool value) async {
    _defaultToReadMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('default_ayah_read_mode', value);
    notifyListeners();
  }
}
