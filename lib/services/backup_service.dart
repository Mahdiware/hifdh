import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import 'planner_database_helper.dart';

class BackupService {
  static const String _dbName = 'hifdh_planner.db';

  Future<String> _getDbPath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, _dbName);
  }

  Future<void> backup() async {
    final dbPath = await _getDbPath();
    final dbFile = File(dbPath);

    if (!await dbFile.exists()) {
      throw Exception("Database not found");
    }

    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final fileName = 'hifdh_backup_$timestamp.db';

    // Read DB bytes. file_picker requires bytes to be passed to write to the file on Android/iOS.
    final bytes = await dbFile.readAsBytes();

    // Use saveFile for all platforms.
    await FilePicker.platform.saveFile(
      dialogTitle: 'Save Backup',
      fileName: fileName,
      type: FileType.any,
      bytes: bytes,
    );
  }

  Future<bool> restore() async {
    // 1. Pick File
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select Backup File',
      type: FileType.any,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return false;

    final pickedPath = result.files.single.path;
    if (pickedPath == null) return false;

    // 2. Close current DB
    await PlannerDatabaseHelper().closeAndReset();

    // 3. Overwrite DB
    final dbPath = await _getDbPath();

    // Ensure the db directory exists (it should, but good to be safe)
    await File(dbPath).parent.create(recursive: true);

    await File(pickedPath).copy(dbPath);

    // Force re-open to verify
    await PlannerDatabaseHelper().database;

    return true;
  }
}
