import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:hifdh/globals.dart';
import 'package:hifdh/core/services/database_migrator.dart';
import 'package:hifdh/shared/models/plan_task.dart';
import 'quran_database.dart';

extension TaskTypeDb on TaskType {
  static bool integerMode = true;

  dynamic toDbValue() {
    if (integerMode) {
      return this == TaskType.memorize ? 0 : 1;
    }
    return this == TaskType.memorize ? 'memorize' : 'revise';
  }

  static TaskType fromDb(dynamic raw) {
    if (raw is int) {
      return raw == 0 ? TaskType.memorize : TaskType.revision;
    }
    if (raw is String) {
      return raw == 'memorize' ? TaskType.memorize : TaskType.revision;
    }
    return TaskType.revision;
  }
}

class PlannerDatabase {
  // Singleton Pattern
  static final PlannerDatabase _instance = PlannerDatabase._internal();
  static Database? _database;
  static Future<Database>? _dbFuture;

  // Cache Versioning: Increments on every write (insert/update/delete)
  int _dbVersion = 0;

  // UI Notifier to trigger rebuilds
  final ValueNotifier<int> dataUpdateNotifier = ValueNotifier(0);

  // Upgrade Status Notifier
  final ValueNotifier<bool> isUpgrading = ValueNotifier(false);

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

  static const int _sqliteSafeVarLimit = 800;
  static const int _schemaVersion = Globals.dbVersion;
  static final RegExp _digitsOnlyRegExp = RegExp(r'^\d+$');
  bool _notifyScheduled = false;
  bool _lowMemoryMode = true;
  Duration _staticCacheIdleTtl = const Duration(minutes: 3);
  Timer? _staticCacheEvictTimer;
  int _staticCacheLockCount = 0;

  int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  int _toEpochMs(DateTime value) => value.millisecondsSinceEpoch;

  int? _toEpochMsNullable(DateTime? value) => value?.millisecondsSinceEpoch;

  DateTime _fromDbDateTime(dynamic raw, {DateTime? fallback}) {
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    if (raw is String && raw.isNotEmpty) {
      if (_digitsOnlyRegExp.hasMatch(raw)) {
        final asInt = int.tryParse(raw);
        if (asInt != null) {
          return DateTime.fromMillisecondsSinceEpoch(asInt);
        }
      }
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        return parsed;
      }
    }
    return fallback ?? DateTime.now();
  }

  String _toIsoStringFromDb(dynamic raw, {DateTime? fallback}) {
    return _fromDbDateTime(raw, fallback: fallback).toIso8601String();
  }

  void _log(String msg, {Object? error, StackTrace? st}) {
    debugPrint('[PlannerDB] $msg${error != null ? ' - $error' : ''}');
    if (st != null) {
      debugPrint(st.toString());
    }
  }

  int _resultToDb(String value) {
    switch (value) {
      case 'correct':
        return 0;
      case 'mistake':
        return 1;
      case 'doubt':
      default:
        return 2;
    }
  }

  String _resultFromDb(dynamic raw) {
    if (raw is int) {
      switch (raw) {
        case 0:
          return 'correct';
        case 1:
          return 'mistake';
        case 2:
        default:
          return 'doubt';
      }
    }
    if (raw is String) {
      return raw;
    }
    return 'doubt';
  }

  int _computeMaxRowsPerBatch(int columnsPerRow) {
    if (columnsPerRow <= 0) return 1;
    final rows = _sqliteSafeVarLimit ~/ columnsPerRow;
    return rows > 0 ? rows : 1;
  }

  void configureMemoryMode({
    bool lowMemoryMode = true,
    Duration cacheIdleTtl = const Duration(minutes: 3),
  }) {
    _lowMemoryMode = lowMemoryMode;
    _staticCacheIdleTtl = cacheIdleTtl;

    if (!_lowMemoryMode) {
      _staticCacheEvictTimer?.cancel();
      _staticCacheEvictTimer = null;
    } else if (_staticDataLoaded) {
      _touchStaticCache();
    }
  }

  void _touchStaticCache() {
    if (!_lowMemoryMode) return;
    _staticCacheEvictTimer?.cancel();
    _staticCacheEvictTimer = Timer(_staticCacheIdleTtl, () {
      if (_staticCacheLockCount > 0) {
        _touchStaticCache();
        return;
      }
      clearStaticCache();
    });
  }

  T _withStaticCacheReadLock<T>(T Function() action) {
    _staticCacheLockCount++;
    try {
      return action();
    } finally {
      _staticCacheLockCount--;
    }
  }

  String _quoteIdentifier(String value) {
    return '"${value.replaceAll('"', '""')}"';
  }

  Future<void> _resetToBaseline(Database db) async {
    _log('Resetting legacy database to V$_schemaVersion baseline schema');
    await db.execute('PRAGMA foreign_keys = OFF');
    try {
      final objects = await db.rawQuery('''
        SELECT type, name
        FROM sqlite_master
        WHERE name NOT LIKE 'sqlite_%'
          AND type IN ('view', 'table')
      ''');

      // Drop views first, then tables.
      objects.sort((a, b) {
        final at = (a['type'] as String?) ?? '';
        final bt = (b['type'] as String?) ?? '';
        if (at == bt) return 0;
        if (at == 'view') return -1;
        if (bt == 'view') return 1;
        return 0;
      });

      for (final row in objects) {
        final type = (row['type'] as String?)?.toLowerCase();
        final name = row['name'] as String?;
        if (type == null || name == null || name.isEmpty) continue;

        final objectType = type == 'view' ? 'VIEW' : 'TABLE';
        await db.execute(
          'DROP $objectType IF EXISTS ${_quoteIdentifier(name)}',
        );
      }

      await _createTables(db);
      await _createIndexes(db);
      await db.execute('PRAGMA user_version = $_schemaVersion');
      TaskTypeDb.integerMode = true;
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
    }
  }

  Future<void> _postOpenSetup(Database db) async {
    try {
      await _createIndexes(db);

      final taskColumnsMeta = await db.rawQuery("PRAGMA table_info(tasks)");
      final taskTypeRow = taskColumnsMeta.firstWhere(
        (r) => r['name'] == 'task_type',
        orElse: () => const <String, Object?>{},
      );
      final taskTypeType =
          (taskTypeRow['type'] as String?)?.toUpperCase() ?? '';
      final integerMode = taskTypeType.contains('INT');
      TaskTypeDb.integerMode = integerMode;
    } catch (e) {
      _log('Post-open setup failed', error: e);
      // Keep app functional with v3 baseline expectation.
      TaskTypeDb.integerMode = true;
    }
  }

  Future<void> checkpointWal({bool truncate = true}) async {
    final db = await database;
    final mode = truncate ? 'TRUNCATE' : 'PASSIVE';
    try {
      await db.execute('PRAGMA wal_checkpoint($mode)');
    } catch (e) {
      _log('WAL checkpoint failed', error: e);
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _dbFuture ??= _initDatabase();
    _database = await _dbFuture!;
    return _database!;
  }

  void notifyDataChanged() {
    _notifyDataChanged();
  }

  void _notifyDataChanged() {
    _dbVersion++;
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      dataUpdateNotifier.value = _dbVersion;
    });
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    // V3 Baseline database. Legacy schemas are reset automatically.
    final path = join(dbPath, Globals.dbName);

    // Use a fixed schema version rather than AppVersion.
    // This prevents data loss when the app is updated but the schema hasn't changed.
    _log('Database Initializing: Version $_schemaVersion');

    Future<Database> openPlannerDb() {
      return openDatabase(
        path,
        version: _schemaVersion,
        onConfigure: (db) async {
          try {
            await db.execute('PRAGMA foreign_keys = ON');
          } catch (e, st) {
            debugPrint('PRAGMA foreign_keys failed: $e\n$st');
          }

          try {
            // PRAGMA journal_mode returns a result, use rawQuery
            final res = await db.rawQuery('PRAGMA journal_mode=WAL');
            debugPrint("PRAGMA journal_mode=WAL result: $res");
          } catch (e, st) {
            debugPrint("PRAGMA journal_mode failed: $e\n$st");
          }

          try {
            await db.execute("PRAGMA synchronous = NORMAL");
          } catch (e, st) {
            debugPrint("PRAGMA synchronous failed: $e\n$st");
          }

          try {
            await db.execute("PRAGMA wal_autocheckpoint = 1000");
          } catch (e, st) {
            debugPrint("PRAGMA wal_autocheckpoint failed: $e\n$st");
          }
        },

        onUpgrade: (db, oldVersion, newVersion) async {
          isUpgrading.value = true;
          if (oldVersion < Globals.dbBaselineVersion) {
            await _resetToBaseline(db);
          } else {
            await DatabaseMigrator.upgrade(db, oldVersion, newVersion);
          }
          isUpgrading.value = false;
        },
        onCreate: (db, version) async {
          await _createTables(db);
          await _createIndexes(db);
        },
      );
    }

    late final Database db;
    try {
      db = await openPlannerDb();
    } catch (e, st) {
      final message = e.toString().toLowerCase();
      final isReadOnlyOpenFailure =
          message.contains('read-only') || message.contains('readonly');

      if (!isReadOnlyOpenFailure) rethrow;

      _log(
        'Planner DB open failed due to read-only state. Recreating local DB file.',
        error: e,
        st: st,
      );

      try {
        await deleteDatabase(path);
      } catch (deleteError, deleteSt) {
        _log(
          'Failed to delete read-only planner DB before recreate',
          error: deleteError,
          st: deleteSt,
        );
        rethrow;
      }

      db = await openPlannerDb();
    }

    await _postOpenSetup(db);
    isUpgrading.value = false;
    return db;
  }

  Future<void> _createIndexes(DatabaseExecutor db) async {
    try {
      // Ensure foreign keys on
      await db.execute('PRAGMA foreign_keys = ON');

      // Tasks indexes
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tasks_status_deadline ON tasks(status, deadline)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tasks_unit ON tasks(unit_id)',
      );

      // Notes indexes
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_task_notes_task_ayah ON task_notes(task_id, ayah_id)',
      );

      // Progress indexes
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ayah_progress_mem ON ayah_progress(is_memorized)',
      );

      // Link table indexes
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_unit_ayahs_unit_ayah ON unit_ayahs(unit_id, ayah_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_unit_ayahs_ayah ON unit_ayahs(ayah_id)',
      );

      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS ux_units_type_range_title ON units(unit_type, start_unit_id, end_unit_id, title)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_units_lookup ON units(unit_type, start_unit_id, end_unit_id, title)',
      );

      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ayah_rev_events_ayah ON ayah_revision_events(ayah_id)',
      );
    } catch (e) {
      _log('Error creating indexes', error: e);
    }
  }

  Future<void> _createTables(DatabaseExecutor db) async {
    // 1. AYAHS
    await db.execute('''
      CREATE TABLE ayahs (
          id INTEGER PRIMARY KEY,
          surah INTEGER NOT NULL,
          ayah INTEGER NOT NULL,
          UNIQUE(surah, ayah)
      )
    ''');

    // 2. UNITS
    await db.execute('''
      CREATE TABLE units (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          unit_type TEXT NOT NULL CHECK (unit_type IN ('surah','juz','page','hizb','custom')),
          parent_unit INTEGER,
          part_label TEXT,
          title TEXT NOT NULL,
          start_unit_id INTEGER,
          end_unit_id INTEGER,
          start_ayah INTEGER,
          end_ayah INTEGER,
          created_at INTEGER NOT NULL,
          FOREIGN KEY(parent_unit) REFERENCES units(id) ON DELETE CASCADE,
          FOREIGN KEY(start_ayah) REFERENCES ayahs(id) ON DELETE SET NULL,
          FOREIGN KEY(end_ayah) REFERENCES ayahs(id) ON DELETE SET NULL
      )
    ''');

    // 3. UNIT_AYAHS
    await db.execute('''
      CREATE TABLE unit_ayahs (
          unit_id INTEGER NOT NULL,
          ayah_id INTEGER NOT NULL,
          PRIMARY KEY (unit_id, ayah_id),
          FOREIGN KEY(unit_id) REFERENCES units(id) ON DELETE CASCADE,
          FOREIGN KEY(ayah_id) REFERENCES ayahs(id) ON DELETE CASCADE
      )
    ''');

    // 4. TASKS (Updated with 'pending' type support)
    await db.execute('''
      CREATE TABLE tasks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          subtitle TEXT,
          task_type INTEGER NOT NULL CHECK (task_type IN (0,1)),
          unit_id INTEGER NOT NULL,
          start_ayah INTEGER,
          end_ayah INTEGER,
          deadline INTEGER,
          created_at INTEGER NOT NULL,
          completed_at INTEGER,
          status INTEGER DEFAULT 0,
          note TEXT,
          FOREIGN KEY(unit_id) REFERENCES units(id) ON DELETE CASCADE,
          FOREIGN KEY(start_ayah) REFERENCES ayahs(id),
          FOREIGN KEY(end_ayah) REFERENCES ayahs(id)
      )
    ''');

    // 5. TASK NOTES
    await db.execute('''
      CREATE TABLE task_notes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          task_id INTEGER NOT NULL,
          ayah_id INTEGER,
          content TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          type INTEGER DEFAULT 0,
          FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE,
          FOREIGN KEY(ayah_id) REFERENCES ayahs(id)
      )
    ''');

    // 6. AYAH PROGRESS
    await db.execute('''
      CREATE TABLE ayah_progress (
          ayah_id INTEGER PRIMARY KEY,
          last_revision_at INTEGER,
          last_result INTEGER CHECK (last_result IN (0,1,2)),
          correct_count INTEGER DEFAULT 0,
          mistake_count INTEGER DEFAULT 0,
          doubt_count INTEGER DEFAULT 0,
          is_memorized INTEGER DEFAULT 0,
          revisions INTEGER DEFAULT 0,
          note TEXT,
          FOREIGN KEY(ayah_id) REFERENCES ayahs(id) ON DELETE CASCADE
      )
    ''');

    // 7. UNIT PROGRESS
    await db.execute('''
      CREATE TABLE unit_progress (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          unit_id INTEGER NOT NULL,
          total_ayahs INTEGER,
          memorized_ayahs INTEGER DEFAULT 0,
          last_updated_at INTEGER,
          FOREIGN KEY(unit_id) REFERENCES units(id) ON DELETE CASCADE
      )
    ''');

    // 8. AYAH REVISION EVENTS
    await db.execute('''
      CREATE TABLE ayah_revision_events (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          ayah_id INTEGER NOT NULL,
          task_id INTEGER,
          result INTEGER NOT NULL CHECK (result IN (0,1,2)),
          created_at INTEGER NOT NULL,
          note TEXT,
          FOREIGN KEY(ayah_id) REFERENCES ayahs(id) ON DELETE CASCADE,
          FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE SET NULL
      )
    ''');
  }

  Future<void> _ensureStaticDataLoaded() async {
    if (_staticDataLoaded) {
      _touchStaticCache();
      return;
    }

    if (_staticLoadFuture != null) {
      try {
        await _staticLoadFuture;
        _touchStaticCache();
      } catch (e) {
        _staticLoadFuture = null;
        _log('Static data load retry required', error: e);
        rethrow;
      }
      return;
    }

    _staticLoadFuture = _performStaticLoad();

    try {
      await _staticLoadFuture;
      _staticDataLoaded = true;
      _touchStaticCache();
    } catch (e) {
      _staticLoadFuture = null;
      rethrow;
    }
  }

  Future<void> _performStaticLoad() async {
    try {
      final rawMeta = await QuranDatabase().getAllQuranMeta();
      if (rawMeta.isEmpty) return;

      final localMetaPageNum = Uint16List(_totalAyahs);
      final localMetaSurahNum = Uint16List(_totalAyahs);
      final localMetaJuzNum = Uint16List(_totalAyahs);
      final localMetaHizbNum = Uint16List(_totalAyahs);
      final localMetaAyahNum = Uint16List(_totalAyahs);

      final localPageToAyahIds = List.generate(605, (_) => <int>[]);
      final localSurahToAyahIds = List.generate(115, (_) => <int>[]);
      final localJuzToAyahIds = List.generate(31, (_) => <int>[]);
      final localHizbToAyahIds = List.generate(61, (_) => <int>[]);

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

        localMetaPageNum[offset] = p;
        localMetaSurahNum[offset] = s;
        localMetaJuzNum[offset] = j;
        localMetaHizbNum[offset] = h;
        localMetaAyahNum[offset] = a;

        if (p <= 604) localPageToAyahIds[p].add(id);
        if (s <= 114) localSurahToAyahIds[s].add(id);
        if (j <= 30) localJuzToAyahIds[j].add(id);
        if (h <= 60) localHizbToAyahIds[h].add(id);
      }

      final rawSurahRanges = await QuranDatabase().getAllSurahPageRanges();
      final localSurahStartPage = Uint16List(115);
      final localSurahEndPage = Uint16List(115);

      for (final r in rawSurahRanges) {
        final s = r['surahNumber']!;
        if (s <= 114) {
          localSurahStartPage[s] = r['startPage']!;
          localSurahEndPage[s] = r['endPage']!;
        }
      }

      final localJuzStartPage = Uint16List(31);
      final localJuzEndPage = Uint16List(31);
      final allJuzRanges = await QuranDatabase().getAllJuzPageRanges();

      for (final row in allJuzRanges) {
        final j = row['juzNumber'];
        final startPage = row['startPage'];
        final endPage = row['endPage'];
        if (j == null || j < 1 || j > 30) continue;
        if (startPage == null || endPage == null) continue;
        localJuzStartPage[j] = startPage;
        localJuzEndPage[j] = endPage;
      }

      // Commit loaded static data atomically after full success.
      _metaPageNum = localMetaPageNum;
      _metaSurahNum = localMetaSurahNum;
      _metaJuzNum = localMetaJuzNum;
      _metaHizbNum = localMetaHizbNum;
      _metaAyahNum = localMetaAyahNum;

      _pageToAyahIds = localPageToAyahIds;
      _surahToAyahIds = localSurahToAyahIds;
      _juzToAyahIds = localJuzToAyahIds;
      _hizbToAyahIds = localHizbToAyahIds;

      _surahStartPage = localSurahStartPage;
      _surahEndPage = localSurahEndPage;
      _juzStartPage = localJuzStartPage;
      _juzEndPage = localJuzEndPage;
    } catch (e, st) {
      _log('Static load failed', error: e, st: st);
      rethrow;
    }
  }

  // --- Cached Data Accessors (Optimization) ---
  Future<List<int>> getCachedSurahsInJuz(int juz) async {
    await _ensureStaticDataLoaded();
    if (juz < 1 || juz > 30) return [];

    return _withStaticCacheReadLock(() {
      final ayahIds = _juzToAyahIds![juz];
      if (ayahIds.isEmpty) return <int>[];

      // Use a Set to find unique surahs
      final surahs = <int>{};
      for (final id in ayahIds) {
        // id is 1-based, array is 0-based
        if (id <= 0 || id > _totalAyahs) continue;
        surahs.add(_metaSurahNum![id - 1]);
      }
      return surahs.toList()..sort();
    });
  }

  Future<List<int>> getCachedSurahsInHizb(int hizb) async {
    await _ensureStaticDataLoaded();
    if (hizb < 1 || hizb > 60) return [];

    return _withStaticCacheReadLock(() {
      final ayahIds = _hizbToAyahIds![hizb];
      if (ayahIds.isEmpty) return <int>[];

      final surahs = <int>{};
      for (final id in ayahIds) {
        if (id <= 0 || id > _totalAyahs) continue;
        surahs.add(_metaSurahNum![id - 1]);
      }
      return surahs.toList()..sort();
    });
  }

  Future<Map<String, int>> getCachedJuzPageRange(int juz) async {
    await _ensureStaticDataLoaded();
    if (juz < 1 || juz > 30) return {'startPage': 0, 'endPage': 0};
    return _withStaticCacheReadLock(() {
      return {'startPage': _juzStartPage![juz], 'endPage': _juzEndPage![juz]};
    });
  }

  Future<Map<String, int>> getCachedSurahPageRange(int surah) async {
    await _ensureStaticDataLoaded();
    if (surah < 1 || surah > 114) return {'startPage': 0, 'endPage': 0};
    return _withStaticCacheReadLock(() {
      return {
        'startPage': _surahStartPage![surah],
        'endPage': _surahEndPage![surah],
      };
    });
  }

  Future<List<int>> getCachedAyahIdsForSurah(int surah) async {
    await _ensureStaticDataLoaded();
    if (surah < 1 || surah > 114) return [];
    return _withStaticCacheReadLock(() => _surahToAyahIds![surah]);
  }

  Future<List<int>> getCachedAyahIdsForJuz(int juz) async {
    await _ensureStaticDataLoaded();
    if (juz < 1 || juz > 30) return [];
    return _withStaticCacheReadLock(() => _juzToAyahIds![juz]);
  }

  Future<List<int>> getCachedAyahIdsForHizb(int hizb) async {
    await _ensureStaticDataLoaded();
    if (hizb < 1 || hizb > 60) return [];
    return _withStaticCacheReadLock(() => _hizbToAyahIds![hizb]);
  }

  // Directly retrieve cached meta for a specific Ayah ID
  Future<Map<String, int>> getCachedAyahMeta(int ayahId) async {
    await _ensureStaticDataLoaded();
    if (ayahId < 1 || ayahId > _totalAyahs) return {};
    return _withStaticCacheReadLock(() {
      return {
        'id': ayahId,
        'surahNumber': _metaSurahNum![ayahId - 1],
        'ayahNumber': _metaAyahNum![ayahId - 1],
        'juzNumber': _metaJuzNum![ayahId - 1],
        'hizbNumber': _metaHizbNum![ayahId - 1],
        'pageNumber': _metaPageNum![ayahId - 1],
      };
    });
  }

  // --- Unit & Task Helpers ---

  Future<void> _ensureAyahRowsExist(
    DatabaseExecutor db,
    Iterable<int> ayahIds,
  ) async {
    final filtered = ayahIds
        .where((id) => id >= 1 && id <= _totalAyahs)
        .toSet()
        .toList();
    if (filtered.isEmpty) return;

    if (!_staticDataLoaded || _metaSurahNum == null || _metaAyahNum == null) {
      await _ensureStaticDataLoaded();
    }
    if (_metaSurahNum == null || _metaAyahNum == null) return;

    final rowsPerChunk = _computeMaxRowsPerBatch(3);
    for (var i = 0; i < filtered.length; i += rowsPerChunk) {
      final end = (i + rowsPerChunk < filtered.length)
          ? i + rowsPerChunk
          : filtered.length;
      final chunk = filtered.sublist(i, end);

      final batch = db.batch();
      for (final ayahId in chunk) {
        batch.insert('ayahs', {
          'id': ayahId,
          'surah': _metaSurahNum![ayahId - 1],
          'ayah': _metaAyahNum![ayahId - 1],
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      try {
        await batch.commit(noResult: true);
      } catch (e) {
        _log('Failed ayah upsert chunk', error: e);
      }
    }
  }

  Future<int> _getOrCreateUnit(DatabaseExecutor db, PlanTask task) async {
    final unitTypeStr = task.unitType.name;
    final int startUnitId = task.unitId;
    final int? endUnitId = task.endUnitId;

    // Ensure FK targets exist before inserting units with start_ayah/end_ayah.
    await _ensureAyahRowsExist(db, [
      if (task.startAyah != null) task.startAyah!,
      if (task.endAyah != null) task.endAyah!,
    ]);

    // For Page or Custom types, if there is an endUnitId, compose a range string
    final String unitIdStr = (endUnitId != null)
        ? '${task.unitId}-${task.endUnitId}'
        : task.unitId.toString();

    final List<Map<String, dynamic>> existing = await db.query(
      'units',
      columns: ['id'],
      where: endUnitId == null
          ? 'unit_type = ? AND start_unit_id = ? AND title = ? AND end_unit_id IS NULL'
          : 'unit_type = ? AND start_unit_id = ? AND title = ? AND end_unit_id = ?',
      whereArgs: endUnitId == null
          ? [unitTypeStr, startUnitId, task.title]
          : [unitTypeStr, startUnitId, task.title, endUnitId],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      return existing.first['id'] as int;
    }

    final unitId = await db.insert('units', {
      'unit_type': unitTypeStr,
      'title': task.title,
      'part_label': unitIdStr,
      'start_unit_id': startUnitId,
      'end_unit_id': endUnitId,
      'start_ayah': task.startAyah,
      'end_ayah': task.endAyah,
      'created_at': _nowMs(),
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
      final ayahRowsPerChunk = _computeMaxRowsPerBatch(3);

      for (var i = 0; i < ayahIds.length; i += ayahRowsPerChunk) {
        final end = (i + ayahRowsPerChunk < ayahIds.length)
            ? i + ayahRowsPerChunk
            : ayahIds.length;
        final chunk = ayahIds.sublist(i, end);

        final batch = db.batch();

        for (final aid in chunk) {
          if (aid <= 0 || aid > _totalAyahs) continue;

          int s = 0;
          int a = 0;
          if (_staticDataLoaded && _metaSurahNum != null) {
            s = _metaSurahNum![aid - 1];
            a = _metaAyahNum![aid - 1];
          }

          batch.insert('ayahs', {
            'id': aid,
            'surah': s,
            'ayah': a,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);

          batch.insert('unit_ayahs', {
            'unit_id': unitId,
            'ayah_id': aid,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
        await batch.commit(noResult: true);
      }
    } catch (e) {
      _log('Error linking ayahs to unit', error: e);
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
        'task_type': task.type.toDbValue(),
        'unit_id': unitId,
        'start_ayah': task.startAyah,
        'end_ayah': task.endAyah,
        'deadline': _toEpochMs(task.deadline),
        'created_at': _toEpochMs(task.createdAt),
        'completed_at': _toEpochMsNullable(task.completedAt),
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
        'deadline': _toEpochMs(task.deadline),
        'completed_at': _toEpochMsNullable(task.completedAt),
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

    // Get Task details first to identify affected Ayahs
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT t.*, u.unit_type, u.part_label, u.start_unit_id, u.end_unit_id
      FROM tasks t
      JOIN units u ON t.unit_id = u.id
      WHERE t.id = ?
    ''',
      [id],
    );

    int count = 0;

    await db.transaction((txn) async {
      count = await txn.delete('tasks', where: 'id = ?', whereArgs: [id]);

      if (maps.isNotEmpty) {
        final row = maps.first;
        final task = _mapRowToPlanTask(row);

        // Modern Recalculation: If we delete a task, we must refresh the status of its ayahs
        // because this task might have been the reason they were 'memorized'.
        final targetAyahIds = await QuranDatabase().getAyahIdsForPlanUnit(
          unitType: task.unitType,
          unitId: task.unitId,
          endUnitId: task.endUnitId,
          startAyah: task.startAyah,
          endAyah: task.endAyah,
        );

        if (targetAyahIds.isNotEmpty) {
          // We pass the transaction so it sees the deletion has happened
          try {
            await _recalculateAyahProgress(txn, targetAyahIds);
          } catch (e) {
            _log('Ayah progress recalculation failed on delete', error: e);
          }
        }
      }
    });

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
      await txn.delete('ayah_revision_events');
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

    int unitId = (row['start_unit_id'] as int?) ?? 0;
    int? endUnitId = row['end_unit_id'] as int?;

    // Backward compatibility with old rows that only had part_label.
    if (unitId == 0) {
      final partLabel = row['part_label'] as String? ?? '0';
      if (partLabel.contains('-')) {
        final parts = partLabel.split('-');
        unitId = int.tryParse(parts[0]) ?? 0;
        if (parts.length > 1) {
          endUnitId = int.tryParse(parts[1]);
        }
      } else {
        unitId = int.tryParse(partLabel) ?? 0;
      }
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
      type: TaskTypeDb.fromDb(row['task_type']),
      deadline: _fromDbDateTime(row['deadline']),
      createdAt: _fromDbDateTime(row['created_at']),
      completedAt: row['completed_at'] != null
          ? _fromDbDateTime(row['completed_at'])
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
      SELECT t.*, u.unit_type, u.part_label, u.start_unit_id, u.end_unit_id, u.title as unit_title
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
      SELECT t.*, u.unit_type, u.part_label, u.start_unit_id, u.end_unit_id, u.title as unit_title
      FROM tasks t
      JOIN units u ON t.unit_id = u.id
      WHERE t.status = ?
      ORDER BY t.completed_at DESC
    ''',
      [TaskStatus.completed.index],
    );

    return maps.map((m) => _mapRowToPlanTask(m)).toList();
  }

  // --- Task Completion Logic (Modern Relationship : Recalculation Pattern) ---

  // Helper: Recalculates the source-of-truth status for specific Ayahs
  // This ensures 'Undo' and 'Complete' never get out of sync.
  Future<void> _recalculateAyahProgress(
    DatabaseExecutor txn,
    List<int> ayahIds,
  ) async {
    if (ayahIds.isEmpty) return;

    try {
      final now = _nowMs();
      final normalizedAyahIds = ayahIds.toSet().toList();
      final useLegacyTaskTypeCompat = !TaskTypeDb.integerMode;
      final memorizedPredicate = useLegacyTaskTypeCompat
          ? "(t.task_type = 0 OR t.task_type = 'memorize')"
          : 't.task_type = 0';
      final revisionPredicate = useLegacyTaskTypeCompat
          ? "(t.task_type = 1 OR t.task_type = 'revise')"
          : 't.task_type = 1';

      final stats = <Map<String, dynamic>>[];
      final maxIdsPerBatch = _computeMaxRowsPerBatch(1);
      for (var i = 0; i < normalizedAyahIds.length; i += maxIdsPerBatch) {
        final end = (i + maxIdsPerBatch < normalizedAyahIds.length)
            ? i + maxIdsPerBatch
            : normalizedAyahIds.length;
        final batch = normalizedAyahIds.sublist(i, end);
        final placeholders = List.filled(batch.length, '?').join(',');

        final rows = await txn.rawQuery('''
      SELECT 
        ua.ayah_id,
        MAX(CASE WHEN $memorizedPredicate AND t.status = 2 THEN 1 ELSE 0 END) as is_mem,
        SUM(CASE WHEN $revisionPredicate AND t.status = 2 THEN 1 ELSE 0 END) as rev_count
      FROM tasks t
      JOIN unit_ayahs ua ON t.unit_id = ua.unit_id
      WHERE ua.ayah_id IN ($placeholders)
      GROUP BY ua.ayah_id
    ''', batch);

        stats.addAll(rows);
      }

      // Convert to Map for O(1) lookup
      final statsMap = {for (var s in stats) s['ayah_id'] as int: s};

      // Preload existing ayah_progress rows in batches (avoid one query per ayah).
      final existingRows = <Map<String, dynamic>>[];
      final maxExistsBatch = _computeMaxRowsPerBatch(1);
      for (var i = 0; i < normalizedAyahIds.length; i += maxExistsBatch) {
        final end = (i + maxExistsBatch < normalizedAyahIds.length)
            ? i + maxExistsBatch
            : normalizedAyahIds.length;
        final batch = normalizedAyahIds.sublist(i, end);
        final placeholders = List.filled(batch.length, '?').join(',');
        final rows = await txn.rawQuery(
          'SELECT ayah_id FROM ayah_progress WHERE ayah_id IN ($placeholders)',
          batch,
        );
        existingRows.addAll(rows);
      }
      final existingIds = existingRows
          .map((r) => (r['ayah_id'] as num).toInt())
          .toSet();

      final upserts = <Map<String, Object?>>[];
      final inserts = <Map<String, Object?>>[];

      for (final id in normalizedAyahIds) {
        final s = statsMap[id];
        final isMem = (s != null && ((s['is_mem'] as num?)?.toInt() ?? 0) > 0);
        final revs = (s != null) ? ((s['rev_count'] as num?)?.toInt() ?? 0) : 0;

        if (!existingIds.contains(id)) {
          if (isMem || revs > 0) {
            inserts.add({
              'ayah_id': id,
              'last_revision_at': now,
              'is_memorized': isMem ? 1 : 0,
              'revisions': revs,
            });
          }
        } else {
          upserts.add({
            'ayah_id': id,
            'is_memorized': isMem ? 1 : 0,
            'revisions': revs,
          });
        }
      }

      // Batch writes to reduce sqlite roundtrips for large units/juz/hizb tasks.
      const maxOpsPerCommit = 300;
      Batch writeBatch = txn.batch();
      var opCount = 0;

      Future<void> flushIfNeeded({bool force = false}) async {
        if (opCount == 0) return;
        if (!force && opCount < maxOpsPerCommit) return;
        await writeBatch.commit(noResult: true);
        writeBatch = txn.batch();
        opCount = 0;
      }

      for (final row in upserts) {
        writeBatch.update(
          'ayah_progress',
          {
            'is_memorized': row['is_memorized'],
            'revisions': row['revisions'],
            // Keep historical `last_revision_at` unchanged on recompute.
          },
          where: 'ayah_id = ?',
          whereArgs: [row['ayah_id']],
        );
        opCount++;
        await flushIfNeeded();
      }

      for (final row in inserts) {
        writeBatch.insert('ayah_progress', row);
        opCount++;
        await flushIfNeeded();
      }

      await flushIfNeeded(force: true);
    } catch (e) {
      _log('Ayah progress recalculation failed', error: e);
    }
  }

  void clearStaticCache() {
    _staticCacheEvictTimer?.cancel();
    _staticCacheEvictTimer = null;
    _staticDataLoaded = false;
    _staticLoadFuture = null;
    _metaPageNum = null;
    _metaSurahNum = null;
    _metaJuzNum = null;
    _metaHizbNum = null;
    _metaAyahNum = null;
    _pageToAyahIds = null;
    _surahToAyahIds = null;
    _juzToAyahIds = null;
    _hizbToAyahIds = null;
    _surahStartPage = null;
    _surahEndPage = null;
    _juzStartPage = null;
    _juzEndPage = null;
  }

  Future<void> completeTask(int taskId, DateTime completedDate) async {
    final db = await database;

    // Get Task details first
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT t.*, u.unit_type, u.part_label, u.start_unit_id, u.end_unit_id
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
          'completed_at': _toEpochMs(completedDate),
        },
        where: 'id = ?',
        whereArgs: [taskId],
      );

      await _ensureStaticDataLoaded();

      try {
        final targetAyahIds = await QuranDatabase().getAyahIdsForPlanUnit(
          unitType: task.unitType,
          unitId: task.unitId,
          endUnitId: task.endUnitId,
          startAyah: task.startAyah,
          endAyah: task.endAyah,
        );

        // Modern: Recalculate based on the new Task state
        await _recalculateAyahProgress(txn, targetAyahIds);

        // Add Note Logic (Kept separate as it's an event, not state)
        // Auto-Notes for "Correct" entries to support detailed history analysis
        final now = _nowMs();
        for (final id in targetAyahIds) {
          final existingNotes = await txn.query(
            'task_notes',
            columns: ['ayah_id'],
            where: 'task_id = ? AND ayah_id = ?',
            whereArgs: [taskId, id],
          );
          // Only add "Correct" note if no specific note (Mistake/Doubt) exists for this ayah
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
        _log('Error updating progress on completion', error: e);
      }
    });

    _notifyDataChanged();
  }

  Future<void> undoCompleteTask(int taskId) async {
    final db = await database;

    // Get Task details
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT t.*, u.unit_type, u.part_label, u.start_unit_id, u.end_unit_id
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
      // 1. Reset Task Status
      await txn.update(
        'tasks',
        {'status': TaskStatus.notStarted.index, 'completed_at': null},
        where: 'id = ?',
        whereArgs: [taskId],
      );

      // 2. Remove auto-generated "Correct" notes
      await txn.delete(
        'task_notes',
        where: 'task_id = ? AND type = ?',
        whereArgs: [taskId, NoteType.correct.index],
      );

      // 3. Modern Recalculation: Update Ayah Progress based on remaining tasks
      final targetAyahIds = await QuranDatabase().getAyahIdsForPlanUnit(
        unitType: task.unitType,
        unitId: task.unitId,
        endUnitId: task.endUnitId,
        startAyah: task.startAyah,
        endAyah: task.endAyah,
      );

      if (targetAyahIds.isNotEmpty) {
        try {
          await _recalculateAyahProgress(txn, targetAyahIds);
        } catch (e) {
          _log('Ayah progress recalculation failed on undo', error: e);
        }
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
    int? safeAyahId = ayahId;

    if (ayahId != null && _staticDataLoaded) {
      if (ayahId <= 0 || ayahId > _totalAyahs) {
        safeAyahId = null;
      }

      if (safeAyahId != null) {
        // Ensure Ayah exists in DB to satisfy Foreign Key
        final s = _metaSurahNum![safeAyahId - 1];
        final a = _metaAyahNum![safeAyahId - 1];
        await db.execute(
          'INSERT OR IGNORE INTO ayahs (id, surah, ayah) VALUES (?, ?, ?)',
          [safeAyahId, s, a],
        );
      }
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
      'ayah_id': safeAyahId,
      'created_at': _nowMs(),
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
      adjusted['createdAt'] = _toIsoStringFromDb(m['created_at']);
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
          SELECT strftime('%Y-%m-%d', completed_at / 1000, 'unixepoch') as date, COUNT(*) as count
          FROM tasks
          WHERE status = 2 AND completed_at >= (strftime('%s', 'now', '-$days days') * 1000)
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
      'lastResult': _resultFromDb(m['last_result']),
      'correctCount': m['correct_count'],
      'mistakeCount': m['mistake_count'],
      'doubtCount': m['doubt_count'],
    };
  }

  Future<void> updateAyahProgress({
    required int ayahId,
    required bool isMemorized,
    required String lastResult, // 'correct','mistake','doubt'
    bool incrementRevision = true,
  }) async {
    final db = await database;

    // Using simple logic instead of complex UPSERT for readability/stability
    final existing = await getAyahProgress(ayahId);

    final nowMs = _nowMs();
    final lastResultCode = _resultToDb(lastResult);

    if (existing == null) {
      await db.insert('ayah_progress', {
        'ayah_id': ayahId,
        'is_memorized': isMemorized ? 1 : 0,
        'revisions': incrementRevision ? 1 : 0,
        'last_revision_at': nowMs,
        'last_result': lastResultCode,
        'correct_count': (lastResult == 'correct') ? 1 : 0,
        'mistake_count': (lastResult == 'mistake') ? 1 : 0,
        'doubt_count': (lastResult == 'doubt') ? 1 : 0,
      });
    } else {
      final updates = <String, dynamic>{
        'is_memorized': isMemorized ? 1 : 0,
        'last_revision_at': nowMs,
        'last_result': lastResultCode,
      };
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

    await db.insert('ayah_revision_events', {
      'ayah_id': ayahId,
      'result': lastResultCode,
      'created_at': nowMs,
    });

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
          if (p != null && (p['m'] == true || p['m'] == 1)) memorizedCount++;

          // Check revisions (treat null/missing as 0)
          final r = (p != null) ? (p['r'] as int) : 0;
          if (r < minRevisions) minRevisions = r;
        }

        // Safety check if loop didn't run or ayahs was empty (though guarded above)
        if (minRevisions == 999999) minRevisions = 0;

        if (memorizedCount > 0 || minRevisions > 0) {
          // A Surah is fully memorized ONLY if memorizedCount equals TOTAL ayahs in surah
          final isFullyMemorized = (memorizedCount == ayahs.length);

          result.add({
            'unitId': s,
            'isMemorized': isFullyMemorized ? 1 : 0,
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
    final rows = await db.rawQuery('''
      SELECT 
        n.id,
        n.task_id as taskId,
        n.ayah_id as ayahId,
        n.content,
        n.type,
        n.created_at as createdAt,
        u.unit_type as unitTypeName,
        COALESCE(u.start_unit_id, 0) as unitId
      FROM task_notes n
      LEFT JOIN tasks t ON n.task_id = t.id
      LEFT JOIN units u ON t.unit_id = u.id
      ORDER BY n.created_at DESC
    ''');

    return rows.map((row) {
      final unitTypeName = row['unitTypeName'] as String?;
      final unitType = switch (unitTypeName) {
        'surah' => PlanUnitType.surah.index,
        'juz' => PlanUnitType.juz.index,
        'page' => PlanUnitType.page.index,
        'hizb' => PlanUnitType.hizb.index,
        _ => PlanUnitType.custom.index,
      };

      return {
        ...row,
        'unitType': unitType,
        'createdAt': _toIsoStringFromDb(row['createdAt']),
      };
    }).toList();
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
      adjusted['createdAt'] = _toIsoStringFromDb(m['created_at']);
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
    clearStaticCache();

    if (_database != null) {
      await checkpointWal(truncate: true);
      await _database!.close();
      _database = null;
    }
    _dbFuture = null;
  }

  void dispose() {
    _staticCacheEvictTimer?.cancel();
    _staticCacheEvictTimer = null;
    dataUpdateNotifier.dispose();
    isUpgrading.dispose();
  }
}
