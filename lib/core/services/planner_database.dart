import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
// import 'package:hifdh/core/services/app_version_info.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:hifdh/globals.dart';
import 'package:hifdh/shared/models/plan_task.dart';
import 'quran_database.dart';

class PlannerDatabase {
  // Singleton Pattern
  static final PlannerDatabase _instance = PlannerDatabase._internal();
  static Database? _database;

  // Cache Versioning: Increments on every write (insert/update/delete)
  int _dbVersion = 0;

  // UI Notifier to trigger rebuilds
  final ValueNotifier<int> dataUpdateNotifier = ValueNotifier(0);

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
  Uint16List? _metaHizbNum; // Added for performance
  Uint16List? _metaAyahNum;

  // Reverse Indices for Traversals
  // Uses List<List<int>> which is efficient enough for this scale.
  List<List<int>>? _pageToAyahIds; // Index 0..604
  List<List<int>>? _surahToAyahIds; // Index 0..114
  List<List<int>>? _juzToAyahIds; // Index 0..30
  List<List<int>>? _hizbToAyahIds; // Index 0..60

  // Flattened Ranges (Index 0 unused to match 1-based IDs)
  Uint16List? _surahStartPage;
  Uint16List? _surahEndPage;
  Uint16List? _juzStartPage;
  Uint16List? _juzEndPage;

  // Dynamic Result Caches (Invalidated when _dbVersion changes)

  factory PlannerDatabase() {
    return _instance;
  }

  PlannerDatabase._internal();

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
    // V2 Database: Clean separation from V1.
    final path = join(dbPath, Globals.dbName);

    // Use a fixed schema version rather than AppVersion.
    // This prevents data loss when the app is updated but the schema hasn't changed.
    const int schemaVersion = Globals.dbVersion;
    debugPrint('Database V2 Initializing: Version $schemaVersion');

    return await openDatabase(
      path,
      version: schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      // Schema migrations should be handled here incrementally in the future
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < newVersion) {
          // Future migrations logic
          debugPrint("Migrating DB from $oldVersion to $newVersion");
        }
      },
      onCreate: (db, version) async {
        await _createDb(db);
      },
    );
  }

  Future<void> _createDb(DatabaseExecutor db) async {
    // =====================================================
    // AYAHS
    await db.execute('''
      CREATE TABLE ayahs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          surah INTEGER NOT NULL,
          ayah INTEGER NOT NULL,
          is_memorized INTEGER DEFAULT 0,
          UNIQUE(surah, ayah)
      )
    ''');

    // =====================================================
    // UNITS
    await db.execute('''
      CREATE TABLE units (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          unit_type TEXT NOT NULL CHECK (unit_type IN ('surah','juz','page','custom')),
          parent_unit INTEGER,
          part_label TEXT,
          title TEXT NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY(parent_unit) REFERENCES units(id) ON DELETE CASCADE
      )
    ''');

    // =====================================================
    // UNIT_AYAHS
    await db.execute('''
      CREATE TABLE unit_ayahs (
          unit_id INTEGER NOT NULL,
          ayah_id INTEGER NOT NULL,
          PRIMARY KEY (unit_id, ayah_id),
          FOREIGN KEY(unit_id) REFERENCES units(id) ON DELETE CASCADE,
          FOREIGN KEY(ayah_id) REFERENCES ayahs(id) ON DELETE CASCADE
      )
    ''');

    // =====================================================
    // TASKS
    await db.execute('''
      CREATE TABLE tasks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          subtitle TEXT,
          task_type TEXT NOT NULL CHECK (task_type IN ('memorize','revise')),
          unit_id INTEGER NOT NULL,
          start_ayah INTEGER,
          end_ayah INTEGER,
          deadline TEXT,
          created_at TEXT NOT NULL,
          completed_at TEXT,
          status INTEGER DEFAULT 0,
          note TEXT,
          FOREIGN KEY(unit_id) REFERENCES units(id) ON DELETE CASCADE
      )
    ''');

    // =====================================================
    // TASK NOTES
    await db.execute('''
      CREATE TABLE task_notes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          task_id INTEGER NOT NULL,
          ayah_id INTEGER,
          content TEXT NOT NULL,
          created_at TEXT NOT NULL,
          type INTEGER DEFAULT 0,
          FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE,
          FOREIGN KEY(ayah_id) REFERENCES ayahs(id)
      )
    ''');

    // =====================================================
    // AYAH PROGRESS
    await db.execute('''
      CREATE TABLE ayah_progress (
          ayah_id INTEGER PRIMARY KEY,
          last_revision_at TEXT,
          last_result TEXT CHECK (last_result IN ('correct','mistake','doubt')),
          correct_count INTEGER DEFAULT 0,
          mistake_count INTEGER DEFAULT 0,
          doubt_count INTEGER DEFAULT 0,
          is_memorized INTEGER DEFAULT 0,
          revisions INTEGER DEFAULT 0,
          note TEXT,
          FOREIGN KEY(ayah_id) REFERENCES ayahs(id) ON DELETE CASCADE
      )
    ''');

    // =====================================================
    // UNIT PROGRESS
    await db.execute('''
      CREATE TABLE unit_progress (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          unit_id INTEGER NOT NULL,
          total_ayahs INTEGER,
          memorized_ayahs INTEGER DEFAULT 0,
          last_updated_at TEXT,
          FOREIGN KEY(unit_id) REFERENCES units(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _ensureStaticDataLoaded() async {
    if (_staticDataLoaded) return;

    if (_staticLoadFuture != null) {
      return _staticLoadFuture;
    }

    _staticLoadFuture = _performStaticLoad();

    try {
      await _staticLoadFuture;
      _staticDataLoaded = true;
    } catch (e) {
      _staticLoadFuture = null;
      rethrow;
    }
  }

  Future<void> _performStaticLoad() async {
    final rawMeta = await QuranDatabase().getAllQuranMeta();
    if (rawMeta.isEmpty) return;

    _metaPageNum = Uint16List(_totalAyahs);
    _metaSurahNum = Uint16List(_totalAyahs);
    _metaJuzNum = Uint16List(_totalAyahs);
    _metaHizbNum = Uint16List(_totalAyahs);
    _metaAyahNum = Uint16List(_totalAyahs);

    _pageToAyahIds = List.generate(605, (_) => <int>[]);
    _surahToAyahIds = List.generate(115, (_) => <int>[]);
    _juzToAyahIds = List.generate(31, (_) => <int>[]);
    _hizbToAyahIds = List.generate(61, (_) => <int>[]);

    for (final m in rawMeta) {
      final id = m['id'] as int;
      final offset = id - 1;

      if (offset < 0 || offset >= _totalAyahs) continue;

      final p = m['pageNumber'] as int;
      final s = m['surahNumber'] as int;
      final j = m['juzNumber'] as int;
      final a = m['ayahNumber'] as int;
      final rub = (m['rubNumber'] as int?) ?? 1;
      final h = ((rub - 1) ~/ 4) + 1;

      _metaPageNum![offset] = p;
      _metaSurahNum![offset] = s;
      _metaJuzNum![offset] = j;
      _metaHizbNum![offset] = h;
      _metaAyahNum![offset] = a;

      if (p <= 604) _pageToAyahIds![p].add(id);
      if (s <= 114) _surahToAyahIds![s].add(id);
      if (j <= 30) _juzToAyahIds![j].add(id);
      if (h <= 60) _hizbToAyahIds![h].add(id);
    }

    final rawSurahRanges = await QuranDatabase().getAllSurahPageRanges();
    _surahStartPage = Uint16List(115);
    _surahEndPage = Uint16List(115);

    for (final r in rawSurahRanges) {
      final s = r['surahNumber']!;
      if (s <= 114) {
        _surahStartPage![s] = r['startPage']!;
        _surahEndPage![s] = r['endPage']!;
      }
    }

    _juzStartPage = Uint16List(31);
    _juzEndPage = Uint16List(31);

    for (int j = 1; j <= 30; j++) {
      final r = await QuranDatabase().getJuzPageRange(j);
      _juzStartPage![j] = r['startPage']!;
      _juzEndPage![j] = r['endPage']!;
    }
  }

  // --- Cached Data Accessors (Optimization) ---
  Future<List<int>> getCachedSurahsInJuz(int juz) async {
    await _ensureStaticDataLoaded();
    if (juz < 1 || juz > 30) return [];

    final ayahIds = _juzToAyahIds![juz];
    if (ayahIds.isEmpty) return [];

    // Use a Set to find unique surahs
    final surahs = <int>{};
    for (final id in ayahIds) {
      // id is 1-based, array is 0-based
      surahs.add(_metaSurahNum![id - 1]);
    }
    return surahs.toList()..sort();
  }

  Future<List<int>> getCachedSurahsInHizb(int hizb) async {
    await _ensureStaticDataLoaded();
    if (hizb < 1 || hizb > 60) return [];

    final ayahIds = _hizbToAyahIds![hizb];
    if (ayahIds.isEmpty) return [];

    final surahs = <int>{};
    for (final id in ayahIds) {
      surahs.add(_metaSurahNum![id - 1]);
    }
    return surahs.toList()..sort();
  }

  Future<Map<String, int>> getCachedJuzPageRange(int juz) async {
    await _ensureStaticDataLoaded();
    if (juz < 1 || juz > 30) return {'startPage': 0, 'endPage': 0};
    return {'startPage': _juzStartPage![juz], 'endPage': _juzEndPage![juz]};
  }

  Future<Map<String, int>> getCachedSurahPageRange(int surah) async {
    await _ensureStaticDataLoaded();
    if (surah < 1 || surah > 114) return {'startPage': 0, 'endPage': 0};
    return {
      'startPage': _surahStartPage![surah],
      'endPage': _surahEndPage![surah],
    };
  }

  Future<List<int>> getCachedAyahIdsForSurah(int surah) async {
    await _ensureStaticDataLoaded();
    if (surah < 1 || surah > 114) return [];
    return _surahToAyahIds![surah];
  }

  Future<List<int>> getCachedAyahIdsForJuz(int juz) async {
    await _ensureStaticDataLoaded();
    if (juz < 1 || juz > 30) return [];
    return _juzToAyahIds![juz];
  }

  Future<List<int>> getCachedAyahIdsForHizb(int hizb) async {
    await _ensureStaticDataLoaded();
    if (hizb < 1 || hizb > 60) return [];
    return _hizbToAyahIds![hizb];
  }

  // Directly retrieve cached meta for a specific Ayah ID
  Future<Map<String, int>> getCachedAyahMeta(int ayahId) async {
    await _ensureStaticDataLoaded();
    if (ayahId < 1 || ayahId > _totalAyahs) return {};
    return {
      'id': ayahId,
      'surahNumber': _metaSurahNum![ayahId - 1],
      'ayahNumber': _metaAyahNum![ayahId - 1],
      'juzNumber': _metaJuzNum![ayahId - 1],
      'hizbNumber': _metaHizbNum![ayahId - 1],
      'pageNumber': _metaPageNum![ayahId - 1],
    };
  }

  // --- Unit & Task Helpers ---

  Future<int> _getOrCreateUnit(DatabaseExecutor db, PlanTask task) async {
    final unitTypeStr = task.unitType.name;
    String unitIdStr = task.unitId.toString();

    // For Page or Custom types, if there is an endUnitId, compose a range string
    if ((task.unitType == PlanUnitType.page ||
            task.unitType == PlanUnitType.custom) &&
        task.endUnitId != null) {
      unitIdStr = '${task.unitId}-${task.endUnitId}';
    }

    final List<Map<String, dynamic>> existing = await db.query(
      'units',
      columns: ['id'],
      where: 'unit_type = ? AND part_label = ? AND title = ?',
      whereArgs: [unitTypeStr, unitIdStr, task.title],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      return existing.first['id'] as int;
    }

    final unitId = await db.insert('units', {
      'unit_type': unitTypeStr,
      'title': task.title,
      'part_label': unitIdStr,
      'created_at': DateTime.now().toIso8601String(),
    });

    try {
      final ayahIds = await QuranDatabase().getAyahIdsForPlanUnit(
        unitType: task.unitType,
        unitId: task.unitId,
        endUnitId: task.endUnitId,
        startAyah: task.startAyah,
        endAyah: task.endAyah,
      );

      await _ensureStaticDataLoaded();

      // OPTIMIZATION: Chunked inserts to prevent UI lag on large plans
      const int chunkSize = 100;

      for (var i = 0; i < ayahIds.length; i += chunkSize) {
        final end = (i + chunkSize < ayahIds.length)
            ? i + chunkSize
            : ayahIds.length;
        final chunk = ayahIds.sublist(i, end);

        final unitVals = <String>[];
        final unitArgs = <Object>[];

        final ayahVals = <String>[];
        final ayahArgs = <Object>[];

        for (final aid in chunk) {
          int s = 0;
          int a = 0;
          if (_staticDataLoaded && _metaSurahNum != null) {
            s = _metaSurahNum![aid - 1];
            a = _metaAyahNum![aid - 1];
          }

          // Buffer ayahs insert
          ayahVals.add('(?, ?, ?)');
          ayahArgs.add(aid);
          ayahArgs.add(s);
          ayahArgs.add(a);

          // Buffer unit_ayahs insert
          unitVals.add('(?, ?)');
          unitArgs.add(unitId);
          unitArgs.add(aid);
        }

        if (ayahVals.isNotEmpty) {
          await db.execute(
            'INSERT OR IGNORE INTO ayahs (id, surah, ayah) VALUES ${ayahVals.join(",")}',
            ayahArgs,
          );
        }

        if (unitVals.isNotEmpty) {
          await db.execute(
            'INSERT INTO unit_ayahs (unit_id, ayah_id) VALUES ${unitVals.join(",")}',
            unitArgs,
          );
        }

        // Yield to event loop to keep UI responsive
        await Future.delayed(Duration.zero);
      }
    } catch (e) {
      debugPrint("Error linking ayahs to unit: \$e");
    }

    return unitId;
  }

  // --- Tasks CRUD ---

  Future<int> insertTask(PlanTask task) async {
    final db = await database;

    return await db.transaction((txn) async {
      final unitId = await _getOrCreateUnit(txn, task);

      final id = await txn.insert('tasks', {
        'title': task.title,
        'subtitle': task.subtitle,
        'task_type': task.type == TaskType.memorize ? 'memorize' : 'revise',
        'unit_id': unitId,
        'start_ayah': task.startAyah,
        'end_ayah': task.endAyah,
        'deadline': task.deadline.toIso8601String(),
        'created_at': task.createdAt.toIso8601String(),
        'completed_at': task.completedAt?.toIso8601String(),
        'status': task.status.index,
        'note': task.note,
      });
      return id;
    });
  }

  Future<int> insertTaskWithNotify(PlanTask task) async {
    final id = await insertTask(task);
    _notifyDataChanged();
    return id;
  }

  Future<int> updateTask(PlanTask task) async {
    final db = await database;
    final count = await db.update(
      'tasks',
      {
        'deadline': task.deadline.toIso8601String(),
        'completed_at': task.completedAt?.toIso8601String(),
        'status': task.status.index,
        'note': task.note,
      },
      where: 'id = ?',
      whereArgs: [task.id],
    );
    _notifyDataChanged();
    return count;
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
      await txn.delete('unit_ayahs');
      await txn.delete('units');
      await txn.delete('ayahs');
      await txn.delete('ayah_progress');
      await txn.delete('unit_progress');
    });
    _notifyDataChanged();
  }

  // --- Task Queries Helper ---

  PlanTask _mapRowToPlanTask(Map<String, dynamic> row) {
    PlanUnitType unitType;
    switch (row['unit_type']) {
      case 'surah':
        unitType = PlanUnitType.surah;
        break;
      case 'juz':
        unitType = PlanUnitType.juz;
        break;
      case 'page':
        unitType = PlanUnitType.page;
        break;
      case 'custom':
        unitType = PlanUnitType.custom;
        break;
      default:
        unitType = PlanUnitType.custom;
    }

    final partLabel = row['part_label'] as String? ?? '0';
    int unitId = 0;
    int? endUnitId;

    if (partLabel.contains('-')) {
      final parts = partLabel.split('-');
      unitId = int.tryParse(parts[0]) ?? 0;
      if (parts.length > 1) {
        endUnitId = int.tryParse(parts[1]);
      }
    } else {
      unitId = int.tryParse(partLabel) ?? 0;
    }

    return PlanTask(
      id: row['id'] as int?,
      unitType: unitType,
      unitId: unitId,
      endUnitId: endUnitId,
      title: row['title'] as String,
      subtitle: row['subtitle'] as String?,
      startAyah: row['start_ayah'] as int?,
      endAyah: row['end_ayah'] as int?,
      type: (row['task_type'] == 'memorize')
          ? TaskType.memorize
          : TaskType.revision,
      deadline:
          DateTime.tryParse(row['deadline'] as String? ?? '') ?? DateTime.now(),
      createdAt:
          DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
      completedAt: row['completed_at'] != null
          ? DateTime.tryParse(row['completed_at'] as String)
          : null,
      status: TaskStatus.values[row['status'] as int? ?? 0],
      note: row['note'] as String?,
    );
  }

  // --- Task Queries ---

  Future<List<PlanTask>> getActiveTasks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT t.*, u.unit_type, u.part_label, u.title as unit_title
      FROM tasks t
      JOIN units u ON t.unit_id = u.id
      WHERE t.status != ?
      ORDER BY t.status ASC, t.deadline ASC
    ''',
      [TaskStatus.completed.index],
    );

    return maps.map((m) => _mapRowToPlanTask(m)).toList();
  }

  Future<List<PlanTask>> getCompletedTasks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT t.*, u.unit_type, u.part_label, u.title as unit_title
      FROM tasks t
      JOIN units u ON t.unit_id = u.id
      WHERE t.status = ?
      ORDER BY t.completed_at DESC
    ''',
      [TaskStatus.completed.index],
    );

    return maps.map((m) => _mapRowToPlanTask(m)).toList();
  }

  // --- Task Completion Logic ---

  Future<void> completeTask(int taskId, DateTime completedDate) async {
    final db = await database;

    // Get Task details first
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT t.*, u.unit_type, u.part_label
      FROM tasks t
      JOIN units u ON t.unit_id = u.id
      WHERE t.id = ?
    ''',
      [taskId],
    );

    if (maps.isEmpty) return;
    final row = maps.first;
    final task = _mapRowToPlanTask(row);

    await db.transaction((txn) async {
      await txn.update(
        'tasks',
        {
          'status': TaskStatus.completed.index,
          'completed_at': completedDate.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [taskId],
      );

      await _ensureStaticDataLoaded();

      // Auto-mark ayah progress
      try {
        final targetAyahIds = await QuranDatabase().getAyahIdsForPlanUnit(
          unitType: task.unitType,
          unitId: task.unitId,
          endUnitId: task.endUnitId,
          startAyah: task.startAyah,
          endAyah: task.endAyah,
        );

        final now = DateTime.now().toIso8601String();
        for (final id in targetAyahIds) {
          // Check existing progress
          final List<Map<String, dynamic>> existing = await txn.query(
            'ayah_progress',
            where: 'ayah_id = ?',
            whereArgs: [id],
          );

          if (existing.isEmpty) {
            await txn.insert('ayah_progress', {
              'ayah_id': id,
              'last_revision_at': now,
              'is_memorized': (task.type == TaskType.memorize) ? 1 : 0,
              'revisions': (task.type == TaskType.revision) ? 1 : 0,
            });
          } else {
            final currentRevision = existing.first['revisions'] as int? ?? 0;
            await txn.update(
              'ayah_progress',
              {
                'last_revision_at': now,
                'is_memorized': 1,
                'revisions': (task.type == TaskType.revision)
                    ? currentRevision + 1
                    : currentRevision,
              },
              where: 'ayah_id = ?',
              whereArgs: [id],
            );
          }
          final existingNotes = await txn.query(
            'task_notes',
            columns: ['ayah_id'],
            where: 'task_id = ? AND ayah_id = ?',
            whereArgs: [taskId, id],
          );

          if (existingNotes.isEmpty) {
            await txn.insert('task_notes', {
              'task_id': taskId,
              'content': '',
              'type': NoteType.correct.index,
              'ayah_id': id,
              'created_at': now,
            });
          }
        }
      } catch (e) {
        debugPrint("Error updating progress on completion: \$e");
      }
    });

    _notifyDataChanged();
  }

  // --- Notes History ---
  Future<int> addNote(
    int taskId,
    String content,
    NoteType type, {
    int? ayahId,
  }) async {
    final db = await database;
    await _ensureStaticDataLoaded();

    if (ayahId != null && _staticDataLoaded) {
      // Ensure Ayah exists in DB to satisfy Foreign Key
      final s = _metaSurahNum![ayahId - 1];
      final a = _metaAyahNum![ayahId - 1];
      await db.execute(
        'INSERT OR IGNORE INTO ayahs (id, surah, ayah) VALUES (?, ?, ?)',
        [ayahId, s, a],
      );
    }

    await db.update(
      'tasks',
      {'note': content},
      where: 'id = ?',
      whereArgs: [taskId],
    );
    final id = await db.insert('task_notes', {
      'task_id': taskId,
      'content': content,
      'type': type.index,
      'ayah_id': ayahId,
      'created_at': DateTime.now().toIso8601String(),
    });
    _notifyDataChanged();
    return id;
  }

  Future<int> deleteTaskNote(int noteId) async {
    final db = await database;
    final count = await db.delete(
      'task_notes',
      where: 'id = ?',
      whereArgs: [noteId],
    );
    _notifyDataChanged();
    return count;
  }

  Future<int> updateTaskNoteEntry(
    int noteId,
    String content,
    NoteType type, {
    int? ayahId,
  }) async {
    final db = await database;
    final Map<String, dynamic> values = {
      'content': content,
      'type': type.index,
    };
    if (ayahId != null) {
      values['ayah_id'] = ayahId;
    }
    final count = await db.update(
      'task_notes',
      values,
      where: 'id = ?',
      whereArgs: [noteId],
    );
    _notifyDataChanged();
    return count;
  }

  Future<List<TaskNote>> getTaskNotes(int taskId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'task_notes',
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: "created_at DESC",
    );
    return maps.map((m) {
      final adjusted = Map<String, dynamic>.from(m);
      adjusted['taskId'] = m['task_id'];
      adjusted['ayahId'] = m['ayah_id'];
      adjusted['createdAt'] = m['created_at'];
      return TaskNote.fromMap(adjusted);
    }).toList();
  }

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
          SELECT strftime('%Y-%m-%d', completed_at) as date, COUNT(*) as count
          FROM tasks
          WHERE status = 2 AND completed_at >= date('now', '-$days days')
          GROUP BY date
          ORDER BY date ASC
      ''');
  }

  // --- Ayah Progress CRUD ---

  Future<Map<String, dynamic>?> getAyahProgress(int ayahId) async {
    final db = await database;
    final res = await db.query(
      'ayah_progress',
      where: 'ayah_id = ?',
      whereArgs: [ayahId],
      limit: 1,
    );
    if (res.isEmpty) return null;

    final m = res.first;
    return {
      'ayahId': m['ayah_id'], // Map back to what UI expects if consistent
      'isMemorized': m['is_memorized'] == 1,
      'revisions': m['revisions'],
      'lastResult': m['last_result'],
      'correctCount': m['correct_count'],
      'mistakeCount': m['mistake_count'],
      'doubtCount': m['doubt_count'],
    };
  }

  Future<void> updateAyahProgress({
    required int ayahId,
    required bool isMemorized,
    String? lastResult, // 'correct','mistake','doubt'
    bool incrementRevision = true,
  }) async {
    final db = await database;

    // Using simple logic instead of complex UPSERT for readability/stability
    final existing = await getAyahProgress(ayahId);

    final now = DateTime.now().toIso8601String();

    if (existing == null) {
      await db.insert('ayah_progress', {
        'ayah_id': ayahId,
        'is_memorized': isMemorized ? 1 : 0,
        'revisions': incrementRevision ? 1 : 0,
        'last_revision_at': now,
        'last_result': lastResult,
        'correct_count': (lastResult == 'correct') ? 1 : 0,
        'mistake_count': (lastResult == 'mistake') ? 1 : 0,
        'doubt_count': (lastResult == 'doubt') ? 1 : 0,
      });
    } else {
      final updates = <String, dynamic>{
        'is_memorized': isMemorized ? 1 : 0,
        'last_revision_at': now,
      };

      if (lastResult != null) updates['last_result'] = lastResult;

      if (incrementRevision) {
        updates['revisions'] = (existing['revisions'] as int) + 1;
      }
      if (lastResult == 'correct') {
        updates['correct_count'] = (existing['correctCount'] as int) + 1;
      } else if (lastResult == 'mistake') {
        updates['mistake_count'] = (existing['mistakeCount'] as int) + 1;
      } else if (lastResult == 'doubt') {
        updates['doubt_count'] = (existing['doubtCount'] as int) + 1;
      }

      await db.update(
        'ayah_progress',
        updates,
        where: 'ayah_id = ?',
        whereArgs: [ayahId],
      );
    }

    _notifyDataChanged();
  }

  // --- Global Coverage ---

  Future<double> getMemorizedPercentage({dynamic type}) async {
    await _ensureStaticDataLoaded();
    final db = await database;

    // Get all memorized ayah IDs
    final List<Map<String, dynamic>> maps = await db.query(
      'ayah_progress',
      columns: ['ayah_id'],
      where: 'is_memorized = 1',
    );
    final memorizedIds = maps.map((m) => m['ayah_id'] as int).toSet();

    if (type == 1) {
      // Ayah
      if (_totalAyahs == 0) return 0.0;
      return (memorizedIds.length / _totalAyahs) * 100;
    } else if (type == 2) {
      // Page
      int memorizedPages = 0;
      const totalPages = 604;

      if (_pageToAyahIds != null) {
        for (int p = 1; p <= totalPages; p++) {
          final ayahs = _pageToAyahIds![p];
          if (ayahs.isNotEmpty &&
              ayahs.every((id) => memorizedIds.contains(id))) {
            memorizedPages++;
          }
        }
      }
      return (memorizedPages / totalPages) * 100;
    } else if (type == 3) {
      // Surah
      int memorizedSurahs = 0;
      const totalSurahs = 114;

      if (_surahToAyahIds != null) {
        for (int s = 1; s <= totalSurahs; s++) {
          final ayahs = _surahToAyahIds![s];
          if (ayahs.isNotEmpty &&
              ayahs.every((id) => memorizedIds.contains(id))) {
            memorizedSurahs++;
          }
        }
      }
      return (memorizedSurahs / totalSurahs) * 100;
    }

    // Default: Ayah
    if (_totalAyahs == 0) return 0.0;
    return (memorizedIds.length / _totalAyahs) * 100;
  }

  Future<bool> isJuzFullyMemorized(int juzNumber) async {
    // Check if all ayahs in juz are in ayah_progress with is_memorized = 1
    await _ensureStaticDataLoaded();
    if (_juzToAyahIds == null) return false;

    final juzAyahs = _juzToAyahIds![juzNumber];
    if (juzAyahs.isEmpty) return false;

    final db = await database;
    final placeholders = List.filled(juzAyahs.length, '?').join(',');
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM ayah_progress WHERE is_memorized = 1 AND ayah_id IN ($placeholders)',
            juzAyahs,
          ),
        ) ??
        0;

    return count == juzAyahs.length;
  }

  Future<bool> isPageRangeFullyMemorized(int startPage, int endPage) async {
    await _ensureStaticDataLoaded();
    final db = await database;

    for (int p = startPage; p <= endPage; p++) {
      final pageAyahs = _pageToAyahIds![p];
      if (pageAyahs.isEmpty) continue;

      final placeholders = List.filled(pageAyahs.length, '?').join(',');
      final count =
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM ayah_progress WHERE is_memorized = 1 AND ayah_id IN ($placeholders)',
              pageAyahs,
            ),
          ) ??
          0;

      if (count != pageAyahs.length) return false;
    }
    return true;
  }

  // --- Missing / Compatibility Methods for v6 ---

  Future<List<Map<String, dynamic>>> getAllSurahProgress() async {
    final db = await database;
    await _ensureStaticDataLoaded();

    final List<Map<String, dynamic>> result = [];

    // 1. Fetch all revision/memorization stats
    // We fetch everything to aggregate efficiently in memory
    final List<Map<String, dynamic>> allProgress = await db.query(
      'ayah_progress',
      columns: ['ayah_id', 'is_memorized', 'revisions'],
    );

    // Map: AyahID -> {isMemorized, revisions}
    final progressMap = {
      for (var r in allProgress)
        r['ayah_id'] as int: {
          'm': r['is_memorized'] == 1,
          'r': r['revisions'] as int,
        },
    };

    if (_surahToAyahIds != null) {
      for (int s = 1; s <= 114; s++) {
        final ayahs = _surahToAyahIds![s];
        if (ayahs.isEmpty) continue;

        int memorizedCount = 0;
        int minRevisions = 999999; // Start high for min calculation

        for (final aid in ayahs) {
          final p = progressMap[aid];

          // Check memorization
          if (p != null && p['m'] == true) memorizedCount++;

          // Check revisions (treat null/missing as 0)
          final r = (p != null) ? (p['r'] as int) : 0;
          if (r < minRevisions) minRevisions = r;
        }

        // Safety check if loop didn't run or ayahs was empty (though guarded above)
        if (minRevisions == 999999) minRevisions = 0;

        if (memorizedCount > 0 || minRevisions > 0) {
          result.add({
            'unitId': s,
            'isMemorized': memorizedCount == ayahs.length ? 1 : 0,
            'revisionCount': minRevisions,
            'lastRevisedAt': null,
          });
        }
      }
    }
    return result;
  }

  // New helper to get raw map for other units (Juz/Hizb)
  Future<Map<int, Map<String, dynamic>>> getAyahProgressMap() async {
    final db = await database;
    final List<Map<String, dynamic>> all = await db.query(
      'ayah_progress',
      columns: ['ayah_id', 'is_memorized', 'revisions'],
    );
    return {
      for (var r in all)
        r['ayah_id'] as int: {
          'isMemorized': r['is_memorized'] == 1,
          'revisions': r['revisions'] as int,
        },
    };
  }

  Future<List<bool>> getGlobalPageCoverage() async {
    await _ensureStaticDataLoaded();

    final Set<int> memorizedIds = (await getGlobalCoveredAyahs());
    final List<bool> coverage = List.filled(605, false);

    if (_pageToAyahIds != null) {
      for (int p = 1; p <= 604; p++) {
        final pAyahs = _pageToAyahIds![p];
        if (pAyahs.isEmpty) continue;

        final count = pAyahs.where((id) => memorizedIds.contains(id)).length;
        if (count == pAyahs.length) {
          coverage[p] = true;
        }
      }
    }
    return coverage;
  }

  Future<Set<int>> getGlobalCoveredAyahs() async {
    final db = await database;
    final List<Map<String, dynamic>> res = await db.query(
      'ayah_progress',
      columns: ['ayah_id'],
      where: 'is_memorized = 1',
    );
    return res.map((r) => r['ayah_id'] as int).toSet();
  }

  Future<List<Map<String, dynamic>>> getAllNotesWithTasks() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        id, 
        task_id as taskId, 
        ayah_id as ayahId, 
        content, 
        type, 
        created_at as createdAt 
      FROM task_notes
      ORDER BY created_at DESC
    ''');
  }

  Future<List<TaskNote>> getNotesForAyahs(List<int> ids) async {
    if (ids.isEmpty) return [];
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final List<Map<String, dynamic>> maps = await db.query(
      'task_notes',
      where: 'ayah_id IN ($placeholders)',
      whereArgs: ids,
      orderBy: 'created_at DESC',
    );

    return maps.map((m) {
      final adjusted = Map<String, dynamic>.from(m);
      adjusted['taskId'] = m['task_id'];
      adjusted['ayahId'] = m['ayah_id'];
      adjusted['createdAt'] = m['created_at'];
      return TaskNote.fromMap(adjusted);
    }).toList();
  }

  Future<List<TaskNote>> getNotesForUnit(dynamic type, int unitId) async {
    final pType = (type is PlanUnitType) ? type : PlanUnitType.surah;
    await _ensureStaticDataLoaded();
    List<int> targetAyahs = [];

    if (pType == PlanUnitType.surah) {
      if (_surahToAyahIds != null && unitId <= 114) {
        targetAyahs = _surahToAyahIds![unitId];
      }
    } else if (pType == PlanUnitType.juz) {
      if (_juzToAyahIds != null && unitId <= 30) {
        targetAyahs = _juzToAyahIds![unitId];
      }
    } else if (pType == PlanUnitType.hizb) {
      targetAyahs = await QuranDatabase().getAyahIdsForPlanUnit(
        unitType: PlanUnitType.hizb,
        unitId: unitId,
      );
    }

    if (targetAyahs.isEmpty) return [];
    return await getNotesForAyahs(targetAyahs);
  }

  Future<bool> isSurahFullyMemorized(int surahNum) async {
    await _ensureStaticDataLoaded();
    if (_surahToAyahIds == null) return false;
    if (surahNum < 1 || surahNum > 114) return false;

    final ayahs = _surahToAyahIds![surahNum];
    if (ayahs.isEmpty) return false;

    final db = await database;
    final placeholders = List.filled(ayahs.length, '?').join(',');
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM ayah_progress WHERE is_memorized = 1 AND ayah_id IN ($placeholders)',
            ayahs,
          ),
        ) ??
        0;

    return count == ayahs.length;
  }

  Future<List<int>> getMemorizedAyahIds() async {
    final db = await database;
    final res = await db.query(
      'ayah_progress',
      columns: ['ayah_id'],
      where: 'is_memorized = 1',
    );
    return res.map((r) => r['ayah_id'] as int).toList();
  }

  Future<void> closeAndReset() async {
    _staticDataLoaded = false;
    _metaPageNum = null;
    _metaSurahNum = null;
    _metaJuzNum = null;
    _metaAyahNum = null;
    // Release caches
    _pageToAyahIds = null;

    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
