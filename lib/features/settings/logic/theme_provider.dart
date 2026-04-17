import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String systemFontOption = 'system';
  static const String robotoFontOption = 'roboto';
  static const String serifFontOption = 'serif';
  static const String monoFontOption = 'mono';

  static const List<String> availableFontOptions = [
    systemFontOption,
    robotoFontOption,
    serifFontOption,
    monoFontOption,
  ];

  static const double defaultTextScale = 1.0;

  static const List<double> availableTextScaleOptions = [
    0.7,
    0.8,
    0.9,
    1.0,
    1.1,
    1.2,
    1.3,
  ];

  ThemeMode _themeMode = ThemeMode.system;
  String _fontOption = systemFontOption;
  double _textScaleFactor = defaultTextScale;
  bool _initialized = false;

  ThemeMode get themeMode => _themeMode;
  String get fontOption => _fontOption;
  double get textScaleFactor => _textScaleFactor;

  String? get selectedFontFamily {
    switch (_fontOption) {
      case robotoFontOption:
        return 'Roboto';
      case serifFontOption:
        return 'Times New Roman';
      case monoFontOption:
        return 'Courier New';
      case systemFontOption:
      default:
        return null;
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('theme_mode');
    final storedFontOption = prefs.getString('app_font_option');
    final storedTextScale = prefs.getDouble('app_text_scale');

    if (themeIndex != null &&
        themeIndex >= 0 &&
        themeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[themeIndex];
    }

    if (storedFontOption != null &&
        availableFontOptions.contains(storedFontOption)) {
      _fontOption = storedFontOption;
    }

    if (storedTextScale != null) {
      _textScaleFactor = _normalizeTextScale(storedTextScale);
    }

    notifyListeners();
  }

  void toggleTheme(bool isDark) {
    final mode = isDark ? ThemeMode.dark : ThemeMode.light;
    setThemeMode(mode);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
  }

  Future<void> setFontOption(String option) async {
    if (!availableFontOptions.contains(option)) return;
    if (_fontOption == option) return;

    _fontOption = option;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_font_option', option);
  }

  Future<void> setTextScaleFactor(double scale) async {
    final normalized = _normalizeTextScale(scale);
    if (_textScaleFactor == normalized) return;

    _textScaleFactor = normalized;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('app_text_scale', normalized);
  }

  double _normalizeTextScale(double scale) {
    return availableTextScaleOptions.reduce((closest, candidate) {
      final closestDiff = (scale - closest).abs();
      final candidateDiff = (scale - candidate).abs();
      return candidateDiff < closestDiff ? candidate : closest;
    });
  }

  ThemeData applyFont(ThemeData baseTheme) {
    final family = selectedFontFamily;
    if (family == null) return baseTheme;

    return baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: family),
      primaryTextTheme: baseTheme.primaryTextTheme.apply(fontFamily: family),
      appBarTheme: baseTheme.appBarTheme.copyWith(
        titleTextStyle: baseTheme.appBarTheme.titleTextStyle?.copyWith(
          fontFamily: family,
        ),
        toolbarTextStyle: baseTheme.appBarTheme.toolbarTextStyle?.copyWith(
          fontFamily: family,
        ),
      ),
    );
  }
}
