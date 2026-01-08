import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../models/plan_task.dart';

import 'database_helper.dart';

class PlannerDatabaseHelper {
  static final PlannerDatabaseHelper _instance =
      PlannerDatabaseHelper._internal();
  static Database? _database;

  // Notifier for data changes to sync UI across tabs
  final ValueNotifier<int> dataUpdateNotifier = ValueNotifier(0);

  factory PlannerDatabaseHelper() {
    return _instance;
  }

  PlannerDatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Method to close and reset database connection (useful for restore)
  Future<void> closeAndReset() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'hifdh_planner.db');

    return await openDatabase(
      path,
      version: 2,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE task_notes ADD COLUMN ayahId INTEGER');
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

        // Notes Table with Type
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

        // Quran Progress Table (Per Surah)
        await db.execute('''
          CREATE TABLE quran_progress(
            unitId INTEGER PRIMARY KEY,
            isMemorized INTEGER DEFAULT 0,
            revisionCount INTEGER DEFAULT 0,
            lastRevisedAt TEXT
          )
        ''');

        // Initialize explicit progress for all 114 Surahs
        final batch = db.batch();
        for (int i = 1; i <= 114; i++) {
          batch.insert('quran_progress', {
            'unitId': i,
            'isMemorized': 0,
            'revisionCount': 0,
          });
        }
        await batch.commit();
      },
    );
  }

  // --- Tasks ---

  Future<int> insertTask(PlanTask task) async {
    final db = await database;
    final id = await db.insert('tasks', task.toMap());
    dataUpdateNotifier.value++;
    return id;
  }

  Future<void> resetAllData() async {
    final db = await database;
    await db.delete('tasks');
    await db.delete('task_notes');

    // Reset progress instead of full delete to keep 114 rows
    final batch = db.batch();
    for (int i = 1; i <= 114; i++) {
      batch.update(
        'quran_progress',
        {'isMemorized': 0, 'revisionCount': 0, 'lastRevisedAt': null},
        where: 'unitId = ?',
        whereArgs: [i],
      );
    }
    await batch.commit();

    dataUpdateNotifier.value++;
  }

  // Only return active tasks for Dashboard
  Future<List<PlanTask>> getActiveTasks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      where: 'status != ?',
      whereArgs: [TaskStatus.completed.index],
      orderBy: "status ASC, deadline ASC",
    );
    return List.generate(maps.length, (i) {
      return PlanTask.fromMap(maps[i]);
    });
  }

  Future<List<PlanTask>> getCompletedTasks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      where: 'status = ?',
      whereArgs: [TaskStatus.completed.index],
      orderBy: "completedAt DESC",
    );
    return List.generate(maps.length, (i) {
      return PlanTask.fromMap(maps[i]);
    });
  }

  // Mark task as complete and update Quran Progress
  Future<void> completeTask(int taskId, DateTime completedDate) async {
    final db = await database;

    // 1. Get the task
    final List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [taskId],
    );
    if (maps.isEmpty) return;
    final task = PlanTask.fromMap(maps.first);

    // 2. Mark as completed in tasks table
    await db.update(
      'tasks',
      {
        'status': TaskStatus.completed.index,
        'completedAt': completedDate.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [taskId],
    );

    // 3. Update Quran Progress Table
    // If task is Surah type, update that Surah directly.
    // If task is Juz, update all Surahs in that Juz?? (Complex, approximate for now)
    // Simpler approach: If unitType == surah, update that surah.

    // 3. Update Quran Progress
    if (task.type == TaskType.memorize) {
      // Global recalculation for memorization to handle gaps/overlaps
      await _runGlobalMemorizationCheck(db);
    } else {
      // Revision: Local update based on what was just done
      if (task.unitType == PlanUnitType.surah) {
        await _updateSurahProgress(db, task.unitId, task.type);
      } else if (task.unitType == PlanUnitType.juz) {
        // Update all Surahs touching this Juz (Loose/Traditional definition)
        final surahs = await DatabaseHelper().getSurahsInJuz(task.unitId);
        for (final s in surahs) {
          await _updateSurahProgress(db, s, task.type);
        }
      } else if (task.unitType == PlanUnitType.page) {
        // Update Surahs fully contained in the page range
        await _runLocalRevisionCheck(
          db,
          task.unitId,
          task.endUnitId ?? task.unitId,
        );
      }
    }

    dataUpdateNotifier.value++;
  }

  // Check if a Surah is fully memorized based on Ayah coverage
  Future<bool> isSurahFullyMemorized(int surahNumber) async {
    final coveredIds = await getGlobalCoveredAyahs();
    _cachedMeta ??= await DatabaseHelper().getAllQuranMeta();

    final surahAyahs = _cachedMeta!
        .where((m) => m['surahNumber'] == surahNumber)
        .map((m) => m['id'] as int);

    if (surahAyahs.isEmpty) return false;

    // Must have all ayahs covered
    return surahAyahs.every((id) => coveredIds.contains(id));
  }

  // Check if a Juz is fully memorized based on Ayah coverage
  Future<bool> isJuzFullyMemorized(int juzNumber) async {
    final coveredIds = await getGlobalCoveredAyahs();
    _cachedMeta ??= await DatabaseHelper().getAllQuranMeta();

    final juzAyahs = _cachedMeta!
        .where((m) => m['juzNumber'] == juzNumber)
        .map((m) => m['id'] as int);

    if (juzAyahs.isEmpty) return false;

    return juzAyahs.every((id) => coveredIds.contains(id));
  }

  // Check if a page range is fully memorized
  Future<bool> isPageRangeFullyMemorized(int startPage, int endPage) async {
    final covered = await getGlobalPageCoverage();
    if (startPage < 1 || endPage > 604 || startPage > endPage) return false;

    for (int p = startPage; p <= endPage; p++) {
      if (!covered[p]) return false;
    }
    return true;
  }

  // Cache for Quran Meta to avoid repeated fetching
  List<Map<String, dynamic>>? _cachedMeta;

  Future<Set<int>> getGlobalCoveredAyahs() async {
    final db = await database;

    // 1. Fetch Meta if not cached
    _cachedMeta ??= await DatabaseHelper().getAllQuranMeta();
    final allMeta = _cachedMeta!;

    // 2. Fetch ALL Completed Memorization Tasks
    final tasks = await db.rawQuery(
      "SELECT unitType, unitId, endUnitId, startAyah, endAyah FROM tasks WHERE status = ? AND type = ?",
      [TaskStatus.completed.index, TaskType.memorize.index],
    );

    // 3. Collect Covered Ayah Unique IDs (Assuming 'id' in quran_meta is unique PK)
    final Set<int> coveredAyahIds = {};

    for (final row in tasks) {
      final uType = PlanUnitType.values[row['unitType'] as int];
      final uId = row['unitId'] as int;
      final endUId = row['endUnitId'] as int?;
      final startAyah =
          row['startAyah'] as int?; // Acts as startRub for Juz tasks
      final endAyah = row['endAyah'] as int?; // Acts as endRub for Juz tasks

      if (uType == PlanUnitType.page) {
        final start = uId;
        final end = endUId ?? uId;
        final matching = allMeta.where(
          (m) =>
              (m['pageNumber'] as int) >= start &&
              (m['pageNumber'] as int) <= end,
        );
        coveredAyahIds.addAll(matching.map((m) => m['id'] as int));
      } else if (uType == PlanUnitType.juz) {
        if (startAyah != null && endAyah != null) {
          // Partial Juz (Rubuc/Hizb mode) - startAyah stores startRub
          final matching = allMeta.where(
            (m) =>
                (m['rubNumber'] as int) >= startAyah &&
                (m['rubNumber'] as int) <= endAyah,
          );
          coveredAyahIds.addAll(matching.map((m) => m['id'] as int));
        } else {
          // Full Juz
          final matching = allMeta.where((m) => m['juzNumber'] == uId);
          coveredAyahIds.addAll(matching.map((m) => m['id'] as int));
        }
      } else if (uType == PlanUnitType.surah) {
        if (startAyah != null && endAyah != null) {
          // Partial Surah
          final matching = allMeta.where(
            (m) =>
                m['surahNumber'] == uId &&
                (m['ayahNumber'] as int) >= startAyah &&
                (m['ayahNumber'] as int) <= endAyah,
          );
          coveredAyahIds.addAll(matching.map((m) => m['id'] as int));
        } else {
          // Full Surah
          final matching = allMeta.where((m) => m['surahNumber'] == uId);
          coveredAyahIds.addAll(matching.map((m) => m['id'] as int));
        }
      }
    }
    return coveredAyahIds;
  }

  // Expose coverage for UI progress calculation
  // Refactored to be granular (Ayah-level precision) to handle Partial Pages correctly
  Future<List<bool>> getGlobalPageCoverage() async {
    // 1. Get Covered Ayahs
    final coveredAyahIds = await getGlobalCoveredAyahs();
    _cachedMeta ??= await DatabaseHelper().getAllQuranMeta();
    final allMeta = _cachedMeta!;

    // 4. Determine Page Coverage
    // A page is covered only if ALL its Ayahs are in the coveredAyahIds set
    final List<bool> covered = List.filled(605, false);

    // Group Meta by Page
    // Map<int, List<int>> pageToAyahIds
    final Map<int, List<int>> pageAyahs = {};
    for (final m in allMeta) {
      final p = m['pageNumber'] as int;
      if (p > 604) continue;
      pageAyahs.putIfAbsent(p, () => []).add(m['id'] as int);
    }

    // Check each page
    for (int p = 1; p <= 604; p++) {
      if (!pageAyahs.containsKey(p)) continue;
      final ids = pageAyahs[p]!;
      // If all IDs on this page are in covered set
      if (ids.every((id) => coveredAyahIds.contains(id))) {
        covered[p] = true;
      }
    }
    return covered;
  }

  Future<void> _runLocalRevisionCheck(
    DatabaseExecutor db,
    int startPage,
    int endPage,
  ) async {
    final ranges = await DatabaseHelper().getAllSurahPageRanges();
    for (final range in ranges) {
      if (range['startPage']! >= startPage && range['endPage']! <= endPage) {
        await _updateSurahProgress(
          db,
          range['surahNumber']!,
          TaskType.revision,
        );
      }
    }
  }

  Future<void> _runGlobalMemorizationCheck(DatabaseExecutor db) async {
    // 1. Build Coverage Bitmap (Pages 1-604)
    final List<bool> covered = List.filled(605, false);

    // Cache ranges to avoid repeated DB calls
    final allSurahRanges = await DatabaseHelper().getAllSurahPageRanges();
    final surahRangeMap = {for (var r in allSurahRanges) r['surahNumber']!: r};

    // Cache Juz ranges
    final juzRanges = <int, Map<String, int>>{};
    for (int j = 1; j <= 30; j++) {
      juzRanges[j] = await DatabaseHelper().getJuzPageRange(j);
    }

    // 2. Fetch ALL Completed Memorization Tasks
    final tasks = await db.rawQuery(
      "SELECT unitType, unitId, endUnitId, startAyah, endAyah FROM tasks WHERE status = ? AND type = ?",
      [TaskStatus.completed.index, TaskType.memorize.index],
    );

    for (final row in tasks) {
      final uType = PlanUnitType.values[row['unitType'] as int];
      final uId = row['unitId'] as int;
      final endUId = row['endUnitId'] as int?;
      final startAyah = row['startAyah'] as int?;
      final endAyah = row['endAyah'] as int?;

      if (uType == PlanUnitType.page) {
        final start = uId;
        final end = endUId ?? uId;
        for (int p = start; p <= end; p++) {
          if (p <= 604) covered[p] = true;
        }
      } else if (uType == PlanUnitType.juz) {
        // Updated logic: Check for Partial Juz (Rubuc/Hizb mapped to Rub ID)
        if (startAyah != null && endAyah != null) {
          final pages = await DatabaseHelper().getPagesForRubRange(
            startAyah,
            endAyah,
          );
          for (final p in pages) {
            if (p <= 604) covered[p] = true;
          }
        } else {
          final range = juzRanges[uId];
          if (range != null) {
            final start = range['startPage']!;
            final end = range['endPage']!;
            if (start > 0) {
              for (int p = start; p <= end; p++) {
                if (p <= 604) covered[p] = true;
              }
            }
          }
        }
      } else if (uType == PlanUnitType.surah) {
        // Updated logic: Check for Partial Surah (Ayah Range)
        if (startAyah != null && endAyah != null) {
          final pages = await DatabaseHelper().getPagesForSurahAyahRange(
            uId,
            startAyah,
            endAyah,
          );
          for (final p in pages) {
            if (p <= 604) covered[p] = true;
          }
        } else {
          final sRange = surahRangeMap[uId];
          if (sRange != null && sRange['startPage']! > 0) {
            for (int p = sRange['startPage']!; p <= sRange['endPage']!; p++) {
              if (p <= 604) covered[p] = true;
            }
          }
        }
      }
    }

    // 3. Check All Surahs against Map
    for (final range in allSurahRanges) {
      final sNum = range['surahNumber']!;
      final sStart = range['startPage']!;
      final sEnd = range['endPage']!;

      bool isFullyCovered = true;
      for (int p = sStart; p <= sEnd; p++) {
        if (!covered[p]) {
          isFullyCovered = false;
          break;
        }
      }

      if (isFullyCovered) {
        await _updateSurahProgress(db, sNum, TaskType.memorize);
      }
    }
  }

  Future<void> _updateSurahProgress(
    DatabaseExecutor db,
    int surahId,
    TaskType type,
  ) async {
    // Fetch current
    final List<Map<String, dynamic>> rows = await db.query(
      'quran_progress',
      where: 'unitId = ?',
      whereArgs: [surahId],
    );
    if (rows.isEmpty) return;

    final current = rows.first;
    int revs = current['revisionCount'];
    bool mem = (current['isMemorized'] == 1);

    if (type == TaskType.memorize) {
      mem = true;
      // If already memorized, treated as revision? User intent implies initial memorization.
    } else {
      // Revision
      revs += 1;
    }

    await db.update(
      'quran_progress',
      {
        'isMemorized': mem ? 1 : 0,
        'revisionCount': revs,
        'lastRevisedAt': DateTime.now().toIso8601String(),
      },
      where: 'unitId = ?',
      whereArgs: [surahId],
    );
  }

  Future<int> updateTaskStatus(int id, TaskStatus status) async {
    final db = await database;
    // Note: Use completeTask for completion to trigger progress logic
    final count = await db.update(
      'tasks',
      {'status': status.index},
      where: 'id = ?',
      whereArgs: [id],
    );
    dataUpdateNotifier.value++;
    return count;
  }

  Future<int> deleteTask(int id) async {
    final db = await database;
    final count = await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
    dataUpdateNotifier.value++;
    return count;
  }

  Future<int> updateTaskNote(int id, String note) async {
    final db = await database;
    return await db.update(
      'tasks',
      {'note': note},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Notes History ---

  Future<int> addNote(
    int taskId,
    String content,
    NoteType type, {
    int? ayahId,
  }) async {
    final db = await database;
    // Update the main task's latest "note" field too for quick access
    await updateTaskNote(taskId, content);

    final id = await db.insert('task_notes', {
      'taskId': taskId,
      'content': content,
      'type': type.index,
      'ayahId': ayahId,
      'createdAt': DateTime.now().toIso8601String(),
    });
    dataUpdateNotifier.value++;
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
    return List.generate(maps.length, (i) {
      return TaskNote.fromMap(maps[i]);
    });
  }

  // Get all notes associated with a specific unit (e.g., Surah 2, Juz 1) regardless of task status
  Future<List<TaskNote>> getNotesForUnit(
    PlanUnitType unitType,
    int unitId,
  ) async {
    final db = await database;

    // Subquery to find tasks matching the unit
    final tasks = await db.query(
      'tasks',
      columns: ['id'],
      where: 'unitType = ? AND unitId = ?',
      whereArgs: [unitType.index, unitId],
    );

    if (tasks.isEmpty) return [];

    final taskIds = tasks.map((t) => t['id'] as int).toList();
    final placeholders = List.filled(taskIds.length, '?').join(',');

    final List<Map<String, dynamic>> maps = await db.query(
      'task_notes',
      where: 'taskId IN ($placeholders)',
      whereArgs: taskIds,
      orderBy: "createdAt DESC",
    );

    return List.generate(maps.length, (i) => TaskNote.fromMap(maps[i]));
  }

  // Fetch all notes with their parent task info to distribute them by unit
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
    final total = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM tasks'),
    );
    final completed = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM tasks WHERE status = ?', [
        TaskStatus.completed.index,
      ]),
    );

    return {
      'total': total ?? 0,
      'completed': completed ?? 0,
      'pending': (total ?? 0) - (completed ?? 0),
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

  // Get progress for all Surahs
  Future<List<QuranProgress>> getAllSurahProgress() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'quran_progress',
      orderBy: 'unitId ASC',
    );
    return List.generate(maps.length, (i) => QuranProgress.fromMap(maps[i]));
  }

  // Calculate Global Memorization Percentage (Page Based)
  Future<double> getMemorizedPercentage() async {
    final covered = await getGlobalPageCoverage();
    int count = 0;
    for (int i = 1; i <= 604; i++) {
      if (i < covered.length && covered[i]) {
        count++;
      }
    }
    return (count / 604.0) * 100;
  }
}
