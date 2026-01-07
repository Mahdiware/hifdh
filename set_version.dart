// ignore_for_file: avoid_print

import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    print('Usage: dart set_version.dart <versionName> (e.g., 1.0.1)');
    exit(1);
  }

  final versionName = args[0]; // e.g., 1.0.1
  final parts = versionName.split('.').map(int.parse).toList();

  if (parts.length != 3) {
    print('Version must be in format X.Y.Z');
    exit(1);
  }

  final versionCode = parts[0] * 100 + parts[1] * 10 + parts[2];

  // Update pubspec.yaml
  final file = File('pubspec.yaml');
  var content = file.readAsStringSync();

  final newContent = content.replaceAll(
    RegExp(r'version: .*'),
    'version: $versionName+$versionCode',
  );

  file.writeAsStringSync(newContent);

  print('Updated version to $versionName+$versionCode');
}
