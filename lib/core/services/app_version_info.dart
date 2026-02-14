import 'package:package_info_plus/package_info_plus.dart';

class AppVersionInfo {
  static final AppVersionInfo _instance = AppVersionInfo._internal();

  factory AppVersionInfo() => _instance;

  AppVersionInfo._internal();

  PackageInfo? _packageInfo;

  Future<void> init() async {
    _packageInfo = await PackageInfo.fromPlatform();
  }

  String get version => _packageInfo?.version ?? '';
  int get buildNumber => int.tryParse(_packageInfo?.buildNumber ?? '') ?? 0;

  List<int> get _semVer {
    final v = _packageInfo?.version ?? '';
    if (v.isEmpty) return [0, 0, 0];

    // Strip build metadata (+...) and pre-release suffix (-...)
    final core = v.split('+').first.split('-').first;
    final parts = core.split('.');

    return [
      parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0,
      parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0,
    ];
  }

  int get versionMajor => _semVer[0];
  int get versionMinor => _semVer[1];
  int get versionPatch => _semVer[2];
}
