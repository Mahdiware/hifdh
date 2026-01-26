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
}
