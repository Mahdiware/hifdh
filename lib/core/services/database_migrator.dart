import 'package:flutter/foundation.dart';
import 'package:hifdh/globals.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseMigrator {
  static const String _migrationsTable = 'schema_migrations';

  static Future<void> upgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    debugPrint("DB Upgrade: v$oldVersion → v$newVersion");

    if (newVersion <= Globals.dbBaselineVersion) {
      debugPrint(
        'Migration skipped: target version is baseline or lower (v$oldVersion → v$newVersion).',
      );
      return;
    }

    if (oldVersion < Globals.dbBaselineVersion) {
      debugPrint(
        'Legacy migration path (v1/v2) is disabled. Baseline reset should be handled by PlannerDatabase before calling migrator.',
      );
      return;
    }

    await _ensureMigrationHistoryTable(db);

    // Run migrations sequentially from V4+ only.
    final startVersion = (oldVersion + 1) > (Globals.dbBaselineVersion + 1)
        ? (oldVersion + 1)
        : (Globals.dbBaselineVersion + 1);
    for (int v = startVersion; v <= newVersion; v++) {
      if (await _isMigrationRecorded(db, v)) {
        debugPrint('Migration v$v already recorded, skipping.');
        continue;
      }

      debugPrint('Running migration v$v...');
      final handled = await _runMigration(db, v);
      if (!handled) {
        throw UnsupportedError(
          'Missing migration handler for version $v. Add _migrateToV$v before bumping dbVersion.',
        );
      }
      await _recordAppliedMigration(db, v);
    }
  }

  static Future<bool> _runMigration(Database db, int version) async {
    switch (version) {
      // Future versions only (V4+)
      // case 4:
      //   await _migrateToV4(db);
      //   return true;

      default:
        debugPrint('No migration handler for version $version');
        return false;
    }
  }

  // ==========================================================
  // HELPERS
  // ==========================================================
  static Future<void> _ensureMigrationHistoryTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_migrationsTable (
        version INTEGER PRIMARY KEY,
        applied_at INTEGER NOT NULL
      )
    ''');
  }

  static Future<void> _recordAppliedMigration(
    DatabaseExecutor db,
    int version,
  ) async {
    await db.insert(_migrationsTable, {
      'version': version,
      'applied_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<bool> _isMigrationRecorded(
    DatabaseExecutor db,
    int version,
  ) async {
    final rows = await db.query(
      _migrationsTable,
      columns: ['version'],
      where: 'version = ?',
      whereArgs: [version],
      limit: 1,
    );
    return rows.isNotEmpty;
  }
}
