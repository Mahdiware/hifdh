import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesProvider extends ChangeNotifier {
  bool _defaultToReadMode = false;
  int _revisionQueueDailyTarget = 25;
  bool _revisionQueueIncludeMastered = false;

  bool get defaultToReadMode => _defaultToReadMode;
  int get revisionQueueDailyTarget => _revisionQueueDailyTarget;
  bool get revisionQueueIncludeMastered => _revisionQueueIncludeMastered;

  PreferencesProvider();

  /// Call this before runApp to load async preferences
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _defaultToReadMode = prefs.getBool('default_ayah_read_mode') ?? false;
    _revisionQueueDailyTarget =
        prefs.getInt('revision_queue_daily_target') ?? 25;
    _revisionQueueIncludeMastered =
        prefs.getBool('revision_queue_include_mastered') ?? false;
    notifyListeners();
  }

  Future<void> toggleDefaultReadMode(bool value) async {
    _defaultToReadMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('default_ayah_read_mode', value);
    notifyListeners();
  }

  Future<void> setRevisionQueueDailyTarget(int value) async {
    final clamped = value.clamp(5, 100);
    _revisionQueueDailyTarget = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('revision_queue_daily_target', clamped);
    notifyListeners();
  }

  Future<void> toggleRevisionQueueIncludeMastered(bool value) async {
    _revisionQueueIncludeMastered = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('revision_queue_include_mastered', value);
    notifyListeners();
  }
}
