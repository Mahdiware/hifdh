import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
// Conditional import for web
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'
    if (dart.library.io) 'package:hifdh/core/services/stub_sqflite_web.dart';
import 'package:hifdh/globals.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';
import 'planner_database.dart';

class BackupService {
  static const String _dbName = Globals.dbName;

  Future<String> _getDbPath() async {
    // On web, we don't have a real file path, so we just use the db name as an identifier.
    if (kIsWeb) {
      return _dbName;
    }
    final dbPath = await getDatabasesPath();
    return join(dbPath, _dbName);
  }

  Future<void> backup(AppLocalizations l10n) async {
    // Ensure WAL changes are merged to main DB file before exporting.
    await PlannerDatabase().checkpointWal(truncate: true);

    Uint8List bytes;

    if (kIsWeb) {
      try {
        if (databaseFactory != databaseFactoryFfiWeb) {
          databaseFactory = databaseFactoryFfiWeb;
        }

        if (await databaseFactoryFfiWeb.databaseExists(_dbName)) {
          bytes = await databaseFactoryFfiWeb.readDatabaseBytes(_dbName);
        } else {
          await PlannerDatabase().database;
          bytes = await databaseFactoryFfiWeb.readDatabaseBytes(_dbName);
        }
      } catch (e) {
        try {
          // If we failed with VfsException(14), maybe the file is locked or path is wrong.
          // Let's try to close the DB connection to release locks.
          await PlannerDatabase().closeAndReset();

          // Now try reading again.
          bytes = await databaseFactoryFfiWeb.readDatabaseBytes(_dbName);

          // Re-open for app usage.
          await PlannerDatabase().database;
        } catch (retryError) {
          if (kDebugMode) {
            print('Failed to read database bytes for $_dbName - $retryError');
          }
          throw Exception(
            '${l10n.databaseNotFound} (Web: $_dbName) - $retryError',
          );
        }
      }
    } else {
      // Native platforms
      final dbPath = await _getDbPath();
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        throw Exception(l10n.databaseNotFound);
      }
      bytes = await dbFile.readAsBytes();
    }

    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final fileName = 'hifdh_backup_$timestamp.db';

    // Use saveFile for all platforms.
    final saved = await FilePicker.platform.saveFile(
      dialogTitle: l10n.saveBackupDialogTitle,
      fileName: fileName,
      type: FileType.any,
      bytes: bytes,
    );

    // User canceled save dialog.
    if (saved == null) {
      return;
    }
  }

  Future<bool> restore(AppLocalizations l10n) async {
    // Pick File
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: l10n.selectBackupFileDialogTitle,
      type: FileType.any,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return false;

    // Cross-Platform Retrieval of File Data
    // On web 'path' is null or fake, we must use 'bytes'.
    final pickedBytes = result.files.single.bytes;
    final pickedPath = result.files.single.path;

    // If we have no bytes and no path (shouldn't happen with file_picker), abort.
    if (pickedBytes == null && pickedPath == null) return false;

    // Close current DB
    await PlannerDatabase().closeAndReset();

    if (kIsWeb) {
      // Web Restore: Write bytes directly to virtual DB
      // We must prefer bytes here because `path` is not usable on web.
      if (pickedBytes != null) {
        await databaseFactory.writeDatabaseBytes(_dbName, pickedBytes);
      } else {
        // Fallback or error if for some reason bytes are null on web
        return false;
      }
    } else {
      // Native Restore
      final dbPath = await _getDbPath();

      // Ensure the db directory exists
      await File(dbPath).parent.create(recursive: true);

      // Clean up potential WAL/SHM files
      final walFile = File('$dbPath-wal');
      final shmFile = File('$dbPath-shm');
      final journalFile = File('$dbPath-journal');
      final targetDbFile = File(dbPath);

      // Delete old files
      if (await targetDbFile.exists()) await targetDbFile.delete();
      if (await walFile.exists()) await walFile.delete();
      if (await shmFile.exists()) await shmFile.delete();
      if (await journalFile.exists()) await journalFile.delete();

      // Write new DB
      if (pickedPath != null) {
        // If we have a real path (desktop/mobile), copy the file
        await File(pickedPath).copy(dbPath);
      } else if (pickedBytes != null) {
        // If we only have bytes (unlikely for native unless picked in memory), write them
        await targetDbFile.writeAsBytes(pickedBytes, flush: true);
      }
    }

    // Force re-open to verify
    await PlannerDatabase().database;

    // Notify app that data has changed entirely
    PlannerDatabase().notifyDataChanged();

    return true;
  }
}
