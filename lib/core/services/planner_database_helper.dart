import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:hifdh/shared/models/plan_task.dart';
import 'database_helper.dart';

class PlannerDatabaseHelper {
  // Singleton Pattern
  static final PlannerDatabaseHelper _instance =
      PlannerDatabaseHelper._internal();
  static Database? _database;

  // Cache Versioning: Increments on every write (insert/update/delete)
  int _dbVersion = 0;

  // UI Notifier to trigger rebuilds
  final ValueNotifier<int> dataUpdateNotifier = ValueNotifier(0);

  // --- Optimized In-Memory Indices (Low RAM Friendly) ---
  // Replaces heavy Map objects with typed arrays for O(1) access.
  bool _staticDataLoaded = false;
  // Memoizer for concurrent loading requests
  Future<void>? _staticLoadFuture;

  // Max Ayah ID is 6236. Uint16 holds up to 65535.
  static const int _totalAyahs = 6236;

  // Metadata Arrays (Indexed by [AyahID - 1])
  Uint16List? _metaPageNum;
  Uint16List? _metaSurahNum;
  Uint16List? _metaJuzNum;

  // Reverse Indices for Traversals
  // Uses List<List<int>> which is efficient enough for this scale.
  List<List<int>>? _pageToAyahIds; // Index 0..604
  List<List<int>>? _surahToAyahIds; // Index 0..114
  List<List<int>>? _juzToAyahIds; // Index 0..30

  // Flattened Ranges (Index 0 unused to match 1-based IDs)
  Uint16List? _surahStartPage;
  Uint16List? _surahEndPage;
  Uint16List? _juzStartPage;
  Uint16List? _juzEndPage;

  // Dynamic Result Caches (Invalidated when _dbVersion changes)
  int _cachedCoverageVersion = -1;
  List<bool>? _cachedPageCoverage; // Size 605
  Set<int>? _cachedCoveredAyahs;

  factory PlannerDatabaseHelper() {
    return _instance;
  }

  PlannerDatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  void _notifyDataChanged() {
    _dbVersion++;
    dataUpdateNotifier.value = _dbVersion;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'hifdh_planner.db');

    return await openDatabase(
      path,
      version: 3,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add ayahId to task_notes if upgrading from v1
          try {
            await db.execute(
              'ALTER TABLE task_notes ADD COLUMN ayahId INTEGER',
            );
          } catch (_) {
            // Ignore if column exists (dev/debug scenarios)
          }
        }
        if (oldVersion < 3) {
          // Create quran_progress table if missing (Fix for v2 upgraders)
          await db.execute('''
            CREATE TABLE IF NOT EXISTS quran_progress(
              unitId INTEGER PRIMARY KEY,
              isMemorized INTEGER DEFAULT 0,
              revisionCount INTEGER DEFAULT 0,
              lastRevisedAt TEXT
            )
          ''');

          // Check if empty and populate
          final count =
              Sqflite.firstIntValue(
                await db.rawQuery('SELECT COUNT(*) FROM quran_progress'),
              ) ??
              0;

          if (count == 0) {
            final batch = db.batch();
            for (int i = 1; i <= 114; i++) {
              batch.insert('quran_progress', {
                'unitId': i,
                'isMemorized': 0,
                'revisionCount': 0,
              });
            }
            await batch.commit(noResult: true);
          }
        }
      },
      onCreate: (db, version) async {
        // Tasks Table
        await db.execute('''
          CREATE TABLE tasks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            unitType INTEGER,
            unitId INTEGER,
            endUnitId INTEGER,
            title TEXT,
            subtitle TEXT,
            startAyah INTEGER,
            endAyah INTEGER,
            type INTEGER,
            deadline TEXT,
            createdAt TEXT,
            completedAt TEXT,
            status INTEGER,
            note TEXT
          )
        ''');

        // Indices
        await db.execute(
          'CREATE INDEX idx_tasks_status_type ON tasks(status, type)',
        );
        await db.execute(
          'CREATE INDEX idx_tasks_unit ON tasks(unitType, unitId)',
        );

        // Notes Table
        await db.execute('''
          CREATE TABLE task_notes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            taskId INTEGER,
            content TEXT,
            type INTEGER,
            ayahId INTEGER,
            createdAt TEXT,
            FOREIGN KEY(taskId) REFERENCES tasks(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('CREATE INDEX idx_notes_task ON task_notes(taskId)');

        // Quran Progress Table
        await db.execute('''
          CREATE TABLE quran_progress(
            unitId INTEGER PRIMARY KEY,
            isMemorized INTEGER DEFAULT 0,
            revisionCount INTEGER DEFAULT 0,
            lastRevisedAt TEXT
          )
        ''');

        // Batch Insert 114 Surahs
        final batch = db.batch();
        for (int i = 1; i <= 114; i++) {
          batch.insert('quran_progress', {
            'unitId': i,
            'isMemorized': 0,
            'revisionCount': 0,
          });
        }
        await batch.commit(noResult: true);
      },
    );
  }

  // --- Optimized Static Data Loader ---
  // Converts heavy List<Map> into TypedData arrays and valid indices.
  // Runs once safely across isolates/concurrency.
  Future<void> _ensureStaticDataLoaded() async {
    // 1. Fast path: already loaded
    if (_staticDataLoaded) return;

    // 2. Concurrency handling: piggyback on existing future if loading
    if (_staticLoadFuture != null) {
      return _staticLoadFuture;
    }

    _staticLoadFuture = _performStaticLoad();

    try {
      await _staticLoadFuture;
      _staticDataLoaded = true;
    } catch (e, stack) {
      debugPrint("Error loading static Quran data: $e\n$stack");
      _staticLoadFuture = null; // Clear so we can retry later
      rethrow;
    }
  }

  Future<void> _performStaticLoad() async {
    // 1. Fetch Heavy Data (Only kept alive during this function)
    final rawMeta = await DatabaseHelper().getAllQuranMeta();
    if (rawMeta.isEmpty) return; // Guard against empty DB

    // 2. Initialize Typed Arrays (Fixed Size)
    _metaPageNum = Uint16List(_totalAyahs);
    _metaSurahNum = Uint16List(_totalAyahs);
    _metaJuzNum = Uint16List(_totalAyahs);

    // Using growable false for inner lists might save a tiny bit but
    // makes appending harder. Default is fine.
    _pageToAyahIds = List.generate(605, (_) => <int>[]); // 1-604
    _surahToAyahIds = List.generate(115, (_) => <int>[]); // 1-114
    _juzToAyahIds = List.generate(31, (_) => <int>[]); // 1-30

    // 3. Populate Arrays - ONE PASS Loop
    for (final m in rawMeta) {
      final id = m['id'] as int;
      final offset = id - 1;

      // Safety check for array bounds
      if (offset < 0 || offset >= _totalAyahs) continue;

      final p = m['pageNumber'] as int;
      final s = m['surahNumber'] as int;
      final j = m['juzNumber'] as int;

      _metaPageNum![offset] = p;
      _metaSurahNum![offset] = s;
      _metaJuzNum![offset] = j;

      if (p <= 604) _pageToAyahIds![p].add(id);
      if (s <= 114) _surahToAyahIds![s].add(id);
      if (j <= 30) _juzToAyahIds![j].add(id);
    }

    // 4. Transform Ranges to Typed Arrays
    final rawSurahRanges = await DatabaseHelper().getAllSurahPageRanges();
    _surahStartPage = Uint16List(115);
    _surahEndPage = Uint16List(115);

    for (final r in rawSurahRanges) {
      final s = r['surahNumber']!;
      if (s <= 114) {
        _surahStartPage![s] = r['startPage']!;
        _surahEndPage![s] = r['endPage']!;
      }
    }

    // Juz Ranges
    _juzStartPage = Uint16List(31);
    _juzEndPage = Uint16List(31);

    for (int j = 1; j <= 30; j++) {
      final r = await DatabaseHelper().getJuzPageRange(j);
      _juzStartPage![j] = r['startPage']!;
      _juzEndPage![j] = r['endPage']!;
    }

    // Note: _staticDataLoaded is set by verify wrapper
  }

  // --- Tasks CRUD ---

  Future<int> insertTask(PlanTask task) async {
    final db = await database;
    final id = await db.insert('tasks', task.toMap());
    _notifyDataChanged();
    return id;
  }

  Future<int> updateTaskStatus(int id, TaskStatus status) async {
    final db = await database;
    final count = await db.update(
      'tasks',
      {'status': status.index},
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyDataChanged();
    return count;
  }

  Future<int> deleteTask(int id) async {
    final db = await database;
    final count = await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
    _notifyDataChanged();
    return count;
  }

  Future<int> updateTaskNote(int id, String note) async {
    final db = await database;
    final count = await db.update(
      'tasks',
      {'note': note},
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyDataChanged();
    return count;
  }

  Future<void> resetAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('tasks');
      await txn.delete('task_notes');
      await txn.rawUpdate(
        'UPDATE quran_progress SET isMemorized = 0, revisionCount = 0, lastRevisedAt = NULL',
      );
    });
    _notifyDataChanged();
  }

  // --- Task Queries ---

  Future<List<PlanTask>> getActiveTasks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      where: 'status != ?',
      whereArgs: [TaskStatus.completed.index],
      orderBy: "status ASC, deadline ASC",
    );
    return maps.map((m) => PlanTask.fromMap(m)).toList();
  }

  Future<List<PlanTask>> getCompletedTasks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      where: 'status = ?',
      whereArgs: [TaskStatus.completed.index],
      orderBy: "completedAt DESC",
    );
    return maps.map((m) => PlanTask.fromMap(m)).toList();
  }

  // --- Task Completion Logic ---

  Future<void> completeTask(int taskId, DateTime completedDate) async {
    final db = await database;
    final maps = await db.query('tasks', where: 'id = ?', whereArgs: [taskId]);
    if (maps.isEmpty) return;
    final task = PlanTask.fromMap(maps.first);

    await db.transaction((txn) async {
      await txn.update(
        'tasks',
        {
          'status': TaskStatus.completed.index,
          'completedAt': completedDate.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [taskId],
      );

      await _ensureStaticDataLoaded();

      if (task.type == TaskType.memorize) {
        await _runGlobalMemorizationCheck(txn);
      } else {
        // Revision Logic
        if (task.unitType == PlanUnitType.surah) {
          await _updateSurahProgress(txn, task.unitId, task.type);
        } else if (task.unitType == PlanUnitType.juz) {
          final surahs = await DatabaseHelper().getSurahsInJuz(task.unitId);
          for (final s in surahs) {
            await _updateSurahProgress(txn, s, task.type);
          }
        } else if (task.unitType == PlanUnitType.page) {
          await _runLocalRevisionCheck(
            txn,
            task.unitId,
            task.endUnitId ?? task.unitId,
          );
        }
      }
    });

    _notifyDataChanged();
  }

  // --- Optimized Internal Progress Logic ---

  Future<void> _runGlobalMemorizationCheck(DatabaseExecutor db) async {
    // 1. Calculate Page Coverage (No DB writes yet)
    // Only fetching relevant memorization tasks
    final tasks = await db.rawQuery(
      "SELECT unitType, unitId, endUnitId, startAyah, endAyah FROM tasks WHERE status = ? AND type = ?",
      [TaskStatus.completed.index, TaskType.memorize.index],
    );

    final List<bool> coveredPages = List.filled(605, false);

    for (final row in tasks) {
      final uType = PlanUnitType.values[row['unitType'] as int];
      final uId = row['unitId'] as int;
      final endUId = row['endUnitId'] as int?;

      if (uType == PlanUnitType.page) {
        final start = uId;
        final end = endUId ?? uId;
        for (int p = start; p <= end; p++) {
          if (p <= 604) coveredPages[p] = true;
        }
      } else if (uType == PlanUnitType.surah) {
        final start = _surahStartPage![uId];
        final end = _surahEndPage![uId];
        if (start > 0) {
          for (int p = start; p <= end; p++) {
            if (p <= 604) coveredPages[p] = true;
          }
        }
      } else if (uType == PlanUnitType.juz) {
        final start = _juzStartPage![uId];
        final end = _juzEndPage![uId];
        if (start > 0) {
          for (int p = start; p <= end; p++) {
            if (p <= 604) coveredPages[p] = true;
          }
        }
      }
    }

    // 2. Batch Update Surah Progress (Correctly Recalculate ALL)
    // We must reset Surahs that are NO LONGER memorized effectively
    // while keeping revision counts intact.
    // Optimization: We check "current" state in memory vs DB state if possible,
    // but here we just blindly update `isMemorized` flag.

    final batch = db.batch();

    // Loop through all 114 Surahs
    for (int sId = 1; sId <= 114; sId++) {
      final start = _surahStartPage![sId];
      final end = _surahEndPage![sId];
      if (start == 0) continue;

      bool isFullyCovered = true;
      for (int p = start; p <= end; p++) {
        if (!coveredPages[p]) {
          isFullyCovered = false;
          break;
        }
      }

      // Update logic: Set isMemorized = 1 if covered, else 0
      batch.update(
        'quran_progress',
        {'isMemorized': isFullyCovered ? 1 : 0},
        where: 'unitId = ?',
        whereArgs: [sId],
      );
    }

    await batch.commit(noResult: true);
  }

  Future<void> _updateSurahProgress(
    DatabaseExecutor db,
    int surahId,
    TaskType type,
  ) async {
    if (type == TaskType.revision) {
      await db.rawUpdate(
        'UPDATE quran_progress SET revisionCount = revisionCount + 1, lastRevisedAt = ? WHERE unitId = ?',
        [DateTime.now().toIso8601String(), surahId],
      );
    } else {
      await db.rawUpdate(
        'UPDATE quran_progress SET isMemorized = 1 WHERE unitId = ?',
        [surahId],
      );
    }
  }

  Future<void> _runLocalRevisionCheck(
    DatabaseExecutor db,
    int startPage,
    int endPage,
  ) async {
    // Determine which Surahs are touched by this page range
    await _ensureStaticDataLoaded();
    final surahsToUpdate = <int>[];

    for (int sId = 1; sId <= 114; sId++) {
      final sStart = _surahStartPage![sId];
      final sEnd = _surahEndPage![sId];
      // Check intersection
      if (sStart >= startPage && sEnd <= endPage) {
        surahsToUpdate.add(sId);
      }
    }

    if (surahsToUpdate.isNotEmpty) {
      final batch = db.batch();
      final now = DateTime.now().toIso8601String();
      for (final sId in surahsToUpdate) {
        batch.rawUpdate(
          'UPDATE quran_progress SET revisionCount = revisionCount + 1, lastRevisedAt = ? WHERE unitId = ?',
          [now, sId],
        );
      }
      await batch.commit(noResult: true);
    }
  }

  // --- Optimized Reads (Caching + Typed Arrays) ---

  Future<Set<int>> getGlobalCoveredAyahs() async {
    if (_cachedCoveredAyahs != null && _cachedCoverageVersion == _dbVersion) {
      return _cachedCoveredAyahs!;
    }

    await _ensureStaticDataLoaded();
    final db = await database;

    final tasks = await db.rawQuery(
      "SELECT unitType, unitId, endUnitId, startAyah, endAyah FROM tasks WHERE status = ? AND type = ?",
      [TaskStatus.completed.index, TaskType.memorize.index],
    );

    final Set<int> coveredAyahIds = {};
    for (final row in tasks) {
      final uType = PlanUnitType.values[row['unitType'] as int];
      final uId = row['unitId'] as int;
      final endUId = row['endUnitId'] as int?;

      if (uType == PlanUnitType.page) {
        final start = uId;
        final end = endUId ?? uId;
        for (int p = start; p <= end; p++) {
          final ids = _pageToAyahIds![p];
          if (ids.isNotEmpty) coveredAyahIds.addAll(ids);
        }
      } else if (uType == PlanUnitType.surah) {
        // O(1) Access to surah's Ayahs via pre-calculated list
        final ids = _surahToAyahIds![uId];
        if (ids.isNotEmpty) coveredAyahIds.addAll(ids);
      } else if (uType == PlanUnitType.juz) {
        final ids = _juzToAyahIds![uId];
        if (ids.isNotEmpty) coveredAyahIds.addAll(ids);
      }
    }

    _cachedCoveredAyahs = coveredAyahIds;
    _cachedCoverageVersion = _dbVersion;
    return coveredAyahIds;
  }

  Future<List<bool>> getGlobalPageCoverage() async {
    if (_cachedPageCoverage != null && _cachedCoverageVersion == _dbVersion) {
      return _cachedPageCoverage!;
    }

    await _ensureStaticDataLoaded();
    final coveredAyahIds = await getGlobalCoveredAyahs();
    final List<bool> covered = List.filled(605, false);

    for (int p = 1; p <= 604; p++) {
      final ids = _pageToAyahIds![p];
      if (ids.isNotEmpty) {
        bool pageDone = true;
        for (final id in ids) {
          if (!coveredAyahIds.contains(id)) {
            pageDone = false;
            break;
          }
        }
        if (pageDone) covered[p] = true;
      }
    }

    _cachedPageCoverage = covered;
    return covered;
  }

  // --- Notes History ---

  Future<int> addNote(
    int taskId,
    String content,
    NoteType type, {
    int? ayahId,
  }) async {
    final db = await database;
    await db.update(
      'tasks',
      {'note': content},
      where: 'id = ?',
      whereArgs: [taskId],
    );
    final id = await db.insert('task_notes', {
      'taskId': taskId,
      'content': content,
      'type': type.index,
      'ayahId': ayahId,
      'createdAt': DateTime.now().toIso8601String(),
    });
    _notifyDataChanged();
    return id;
  }

  Future<List<TaskNote>> getTaskNotes(int taskId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'task_notes',
      where: 'taskId = ?',
      whereArgs: [taskId],
      orderBy: "createdAt DESC",
    );
    return maps.map((m) => TaskNote.fromMap(m)).toList();
  }

  Future<List<TaskNote>> getNotesForUnit(
    PlanUnitType unitType,
    int unitId,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT tn.* FROM task_notes tn
      JOIN tasks t ON tn.taskId = t.id
      WHERE t.unitType = ? AND t.unitId = ?
      ORDER BY tn.createdAt DESC
    ''',
      [unitType.index, unitId],
    );
    return maps.map((m) => TaskNote.fromMap(m)).toList();
  }

  Future<List<Map<String, dynamic>>> getAllNotesWithTasks() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT tn.*, t.unitType, t.unitId
      FROM task_notes tn
      JOIN tasks t ON tn.taskId = t.id
      ORDER BY tn.createdAt DESC
    ''');
  }

  // --- Stats & Progress ---

  Future<Map<String, int>> getStats() async {
    final db = await database;
    final total =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM tasks'),
        ) ??
        0;
    final completed =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM tasks WHERE status = ?', [
            TaskStatus.completed.index,
          ]),
        ) ??
        0;

    return {
      'total': total,
      'completed': completed,
      'pending': total - completed,
    };
  }

  Future<List<Map<String, dynamic>>> getCompletionStats({int days = 7}) async {
    final db = await database;
    return await db.rawQuery('''
          SELECT strftime('%Y-%m-%d', completedAt) as date, COUNT(*) as count
          FROM tasks
          WHERE status = 2 AND completedAt >= date('now', '-$days days')
          GROUP BY date
          ORDER BY date ASC
      ''');
  }

  Future<List<QuranProgress>> getAllSurahProgress() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'quran_progress',
      orderBy: 'unitId ASC',
    );
    return maps.map((m) => QuranProgress.fromMap(m)).toList();
  }

  Future<double> getMemorizedPercentage({int type = 2}) async {
    switch (type) {
      case 1: // Ayah-based
        final coveredAyahs = await getGlobalCoveredAyahs();
        if (coveredAyahs.isEmpty) return 0.0;
        return (coveredAyahs.length / 6236.0) * 100;

      case 2: // Page-based
        final coveredPages = await getGlobalPageCoverage();
        int memorizedPages = 0;
        for (int p = 1; p <= 604; p++) {
          if (coveredPages[p]) memorizedPages++;
        }
        return (memorizedPages / 604.0) * 100;

      case 3: // Surah-based
        final db = await database;
        final count =
            Sqflite.firstIntValue(
              await db.rawQuery(
                'SELECT COUNT(*) FROM quran_progress WHERE isMemorized = 1',
              ),
            ) ??
            0;
        return (count / 114.0) * 100;

      default:
        return 0.0;
    }
  }

  /// Check if a Juz is fully memorized using cached Ayah coverage
  Future<bool> isJuzFullyMemorized(int juzNumber) async {
    await _ensureStaticDataLoaded();
    final coveredAyahIds = await getGlobalCoveredAyahs();

    // Fast lookup via indexed array
    final juzAyahIds = _juzToAyahIds![juzNumber];
    if (juzAyahIds.isEmpty) return false;

    return juzAyahIds.every((id) => coveredAyahIds.contains(id));
  }

  /// Check if a page range is fully memorized using cached Page coverage
  Future<bool> isPageRangeFullyMemorized(int startPage, int endPage) async {
    // Basic validation
    if (startPage < 1 || endPage > 604 || startPage > endPage) return false;

    final coveredPages = await getGlobalPageCoverage();

    for (int p = startPage; p <= endPage; p++) {
      if (!coveredPages[p]) return false;
    }
    return true;
  }

  Future<bool> isSurahFullyMemorized(int surahNumber) async {
    // Use DB state for quick check (updated in batch jobs)
    final db = await database;
    final result = await db.query(
      'quran_progress',
      columns: ['isMemorized'],
      where: 'unitId = ?',
      whereArgs: [surahNumber],
    );

    if (result.isNotEmpty && result.first['isMemorized'] == 1) {
      return true;
    }
    return false;
  }

  Future<void> closeAndReset() async {
    _staticDataLoaded = false;
    _metaPageNum = null;
    _metaSurahNum = null;
    _metaJuzNum = null;
    // Release caches
    _pageToAyahIds = null;
    _cachedCoveredAyahs = null;

    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
