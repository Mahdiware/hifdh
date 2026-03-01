import 'dart:async';
import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
// Conditional import for web
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'
    if (dart.library.io) 'package:hifdh/core/services/stub_sqflite_web.dart';
import 'package:hifdh/shared/models/ayah.dart';
import 'package:hifdh/shared/models/surah.dart';
import 'package:hifdh/shared/models/plan_task.dart';

class QuranDatabase {
  static final QuranDatabase _instance = QuranDatabase._internal();
  static Database? _database;
  static Completer<Database>? _initCompleter;

  factory QuranDatabase() {
    return _instance;
  }

  QuranDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;

    // Prevent concurrent initialization
    if (_initCompleter == null) {
      _initCompleter = Completer<Database>();
      try {
        _database = await _initDatabase();
        _initCompleter!.complete(_database);
      } catch (e) {
        _initCompleter!.completeError(e);
        _initCompleter = null; // Allow retry on subsequent calls
      }
    }

    return _initCompleter!.future;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      // Initialize FFI for Web if needed
      // Note: databaseFactoryFfiWeb is imported conditionally
      // We set the global factory if it's available (which it is on web via import)
      // On web we often need to ensure the factory is set for openDatabase to work
      // or use the factory directly.

      // Use dynamic to bypass strong mode checks if necessary, or just rely on kIsWeb guard.
      // Since databaseFactoryFfiWeb is non-nullable on web, the check is redundant there.
      // On mobile, it's null, but kIsWeb prevents execution.
      // So we can safely assign.
      // However, to silence the analyzer warning about non-nullable type on Web:
      try {
        // Cast to dynamic to avoid static analysis complaints about nullability mismatch across imports
        var factory = databaseFactoryFfiWeb as dynamic;
        if (factory != null) {
          databaseFactory = factory;
        }
      } catch (e) {
        debugPrint("Failed to set databaseFactory: $e");
      }

      var path = 'quran.db';
      // On Web, checking existence is tricky with path string only,
      // but openDatabase will create it. We want to check if it has data.
      // We can try to open it and check tables.

      // However, to populate from asset, we use writeDatabaseBytes
      // if the DB doesn't exist.
      // Since 'databaseExists' works on web standard implementation (checks IndexedDB),
      // let's try to follow similar pattern.
      var exists = await databaseFactory.databaseExists(path);

      if (!exists) {
        debugPrint("Web: Creating new copy from asset");
        ByteData data = await rootBundle.load(join("assets", "quran.db"));
        Uint8List bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        await databaseFactory.writeDatabaseBytes(path, bytes);
      }

      return await openDatabase(path, readOnly: true);
    }

    // Non-web implementation
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'quran.db');

    // Check if the database exists
    var exists = await databaseExists(path);

    if (exists) {
      // Check for schema updates (e.g. missing rubNumber column)
      // Since we can't easily alter the pre-packaged DB structure without migration scripts,
      // we check validity. If invalid (old version), we delete and re-copy.
      Database? checkDb;
      try {
        checkDb = await openDatabase(path, readOnly: true);
        final tableInfo = await checkDb.rawQuery(
          "PRAGMA table_info(quran_meta)",
        );
        final hasRubNumber = tableInfo.any((c) => c['name'] == 'rubNumber');

        if (!hasRubNumber) {
          debugPrint("Old database version detected. Deleting...");
          await checkDb.close();
          checkDb = null;
          await deleteDatabase(path);
          exists = false;
        } else {
          // Database is good, return it directly to avoid close/open race in singleton mode
          return checkDb;
        }
      } catch (e) {
        debugPrint("Error checking database version: $e");
        if (checkDb != null) {
          await checkDb.close();
        }
        // If corrupt, delete
        await deleteDatabase(path);
        exists = false;
      }
    }

    if (!exists) {
      // Should be capable of handling the copy from assets
      debugPrint("Creating new copy from asset");

      // Make sure the parent directory exists
      try {
        await Directory(dirname(path)).create(recursive: true);
      } catch (_) {}

      // Copy from asset
      ByteData data = await rootBundle.load(join("assets", "quran.db"));
      List<int> bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      // Write and flush the bytes written
      await File(path).writeAsBytes(bytes, flush: true);
    } else {
      debugPrint("Opening existing database");
    }

    // open the database
    return await openDatabase(path, readOnly: true);
  }

  Future<List<Surah>> getAllSurahs() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('surah_info');
    return List.generate(maps.length, (i) {
      return Surah.fromMap(maps[i]);
    });
  }

  Future<List<Map<String, dynamic>>> getTables() async {
    final db = await database;
    return await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table';",
    );
  }

  Future<Ayah?> getRandomAyah() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      "SELECT qt.text, qm.surahNumber, qm.ayahNumber, si.surahArabicName "
      "FROM quran_text qt "
      "JOIN quran_meta qm ON qt.id = qm.id "
      "JOIN surah_info si ON qm.surahNumber = si.surahNumber "
      "ORDER BY RANDOM() LIMIT 1",
    );

    if (maps.isNotEmpty) {
      return Ayah.fromMap(maps.first);
    }
    return null;
  }

  Future<Ayah?> getAyahBySurahAyah(int surah, int ayah) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      "SELECT qt.text, qm.surahNumber, qm.ayahNumber, si.surahArabicName "
      "FROM quran_text qt "
      "JOIN quran_meta qm ON qt.id = qm.id "
      "JOIN surah_info si ON qm.surahNumber = si.surahNumber "
      "WHERE qm.surahNumber = ? AND qm.ayahNumber = ? LIMIT 1",
      [surah, ayah],
    );

    if (maps.isNotEmpty) {
      return Ayah.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getAyahsMetadataForSurah(
    int surahId,
  ) async {
    final db = await database;
    return await db.rawQuery(
      "SELECT id, ayahNumber, pageNumber, juzNumber FROM quran_meta WHERE surahNumber = ? ORDER BY ayahNumber ASC",
      [surahId],
    );
  }

  Future<Map<String, dynamic>?> getAyahInfoById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      "SELECT qm.surahNumber, qm.ayahNumber, si.surahName, si.surahArabicName "
      "FROM quran_meta qm "
      "JOIN surah_info si ON qm.surahNumber = si.surahNumber "
      "WHERE qm.id = ? LIMIT 1",
      [id],
    );

    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  Future<Ayah?> getRandomAyahBySurah(int surah) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      "SELECT qt.text, qm.surahNumber, qm.ayahNumber, si.surahArabicName "
      "FROM quran_text qt "
      "JOIN quran_meta qm ON qt.id = qm.id "
      "JOIN surah_info si ON qm.surahNumber = si.surahNumber "
      "WHERE qm.surahNumber=? ORDER BY RANDOM() LIMIT 1",
      [surah],
    );

    if (maps.isNotEmpty) {
      return Ayah.fromMap(maps.first);
    }
    return null;
  }

  Future<Ayah?> getRandomAyahBySurahList(List<int> surahs) async {
    final db = await database;
    if (surahs.isEmpty) return null;

    final placeholders = List.filled(surahs.length, '?').join(',');
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      "SELECT qt.text, qm.surahNumber, qm.ayahNumber, si.surahArabicName "
      "FROM quran_text qt "
      "JOIN quran_meta qm ON qt.id = qm.id "
      "JOIN surah_info si ON qm.surahNumber = si.surahNumber "
      "WHERE qm.surahNumber IN ($placeholders) ORDER BY RANDOM() LIMIT 1",
      surahs,
    );

    if (maps.isNotEmpty) {
      return Ayah.fromMap(maps.first);
    }
    return null;
  }

  Future<Ayah?> getRandomAyahByJuz(int juz) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      "SELECT qt.text, qm.surahNumber, qm.ayahNumber, si.surahArabicName "
      "FROM quran_text qt "
      "JOIN quran_meta qm ON qt.id = qm.id "
      "JOIN surah_info si ON qm.surahNumber = si.surahNumber "
      "WHERE qm.juzNumber=? ORDER BY RANDOM() LIMIT 1",
      [juz],
    );

    if (maps.isNotEmpty) {
      return Ayah.fromMap(maps.first);
    }
    return null;
  }

  Future<Ayah?> getRandomAyahByPageRange(int startPage, int endPage) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      "SELECT qt.text, qm.surahNumber, qm.ayahNumber, si.surahArabicName "
      "FROM quran_text qt "
      "JOIN quran_meta qm ON qt.id = qm.id "
      "JOIN surah_info si ON qm.surahNumber = si.surahNumber "
      "WHERE qm.pageNumber BETWEEN ? AND ? ORDER BY RANDOM() LIMIT 1",
      [startPage, endPage],
    );

    if (maps.isNotEmpty) {
      return Ayah.fromMap(maps.first);
    }
    return null;
  }

  Future<Ayah?> getRandomAyahBySurahAyahRange(
    int startSurah,
    int startAyah,
    int endSurah,
    int endAyah,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      "SELECT qt.text, qm.surahNumber, qm.ayahNumber "
      "FROM quran_text qt "
      "JOIN quran_meta qm ON qt.id = qm.id "
      "WHERE (qm.surahNumber > ? AND qm.surahNumber < ?) "
      "   OR (qm.surahNumber = ? AND qm.ayahNumber >= ?) "
      "   OR (qm.surahNumber = ? AND qm.ayahNumber <= ?) "
      "ORDER BY RANDOM() LIMIT 1",
      [startSurah, endSurah, startSurah, startAyah, endSurah, endAyah],
    );

    if (maps.isNotEmpty) {
      return Ayah.fromMap(maps.first);
    }
    return null;
  }

  Future<List<String>> getAyahsByPage(int page) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      "SELECT qt.text FROM quran_text qt "
      "JOIN quran_meta qm ON qt.id = qm.id "
      "WHERE qm.pageNumber=? ORDER BY qm.ayahNumber ASC",
      [page],
    );

    return maps.map((e) => e['text'] as String).toList();
  }

  Future<List<String>> getAyahsBySurah(int surah) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      "SELECT qt.text FROM quran_text qt "
      "JOIN quran_meta qm ON qt.id = qm.id "
      "WHERE qm.surahNumber=? ORDER BY qm.ayahNumber ASC",
      [surah],
    );

    return maps.map((e) => e['text'] as String).toList();
  }

  Future<List<String>> getAyahsByJuz(int juz) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      "SELECT qt.text FROM quran_text qt "
      "JOIN quran_meta qm ON qt.id = qm.id "
      "WHERE qm.juzNumber=? ORDER BY qm.surahNumber ASC, qm.ayahNumber ASC",
      [juz],
    );

    return maps.map((e) => e['text'] as String).toList();
  }

  Future<int> getAyahCount() async {
    final db = await database;
    return Sqflite.firstIntValue(
          await db.rawQuery("SELECT COUNT(*) FROM quran_text"),
        ) ??
        0;
  }

  // Returns distinct Surah numbers present in a specific Juz
  Future<List<int>> getSurahsInJuz(int juzNumber) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      "SELECT DISTINCT surahNumber FROM quran_meta WHERE juzNumber = ?",
      [juzNumber],
    );
    return maps.map((e) => e['surahNumber'] as int).toList();
  }

  Future<List<int>> getSurahsInHizb(int hizbNumber) async {
    final db = await database;
    int startRub = (hizbNumber - 1) * 4 + 1;
    int endRub = hizbNumber * 4;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      "SELECT DISTINCT surahNumber FROM quran_meta WHERE rubNumber BETWEEN ? AND ?",
      [startRub, endRub],
    );
    return maps.map((e) => e['surahNumber'] as int).toList();
  }

  // Returns all distinct Juz numbers that a Surah spans across
  Future<List<int>> getJuzsForSurah(int surahNumber) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      "SELECT DISTINCT juzNumber FROM quran_meta WHERE surahNumber = ? ORDER BY juzNumber",
      [surahNumber],
    );
    return maps.map((e) => e['juzNumber'] as int).toList();
  }

  Future<int> getSurahAyahCount(int surahNumber) async {
    final db = await database;
    return Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT MAX(ayahNumber) FROM quran_meta WHERE surahNumber = ?",
            [surahNumber],
          ),
        ) ??
        0;
  }

  // Returns list of objects {surahNumber, startPage, endPage}
  Future<List<Map<String, int>>> getAllSurahPageRanges() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
      "SELECT surahNumber, MIN(pageNumber) as startPage, MAX(pageNumber) as endPage "
      "FROM quran_meta GROUP BY surahNumber",
    );

    return result.map((row) {
      return {
        'surahNumber': row['surahNumber'] as int,
        'startPage': row['startPage'] as int,
        'endPage': row['endPage'] as int,
      };
    }).toList();
  }

  Future<Map<String, int>> getJuzPageRange(int juzNumber) async {
    final db = await database;
    final List<Map<String, dynamic>> res = await db.rawQuery(
      "SELECT MIN(pageNumber) as startPage, MAX(pageNumber) as endPage FROM quran_meta WHERE juzNumber = ?",
      [juzNumber],
    );
    if (res.isNotEmpty && res.first['startPage'] != null) {
      return {
        'startPage': res.first['startPage'] as int,
        'endPage': res.first['endPage'] as int,
      };
    }
    return {'startPage': 0, 'endPage': 0};
  }

  Future<List<Map<String, int>>> getAllJuzPageRanges() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT juzNumber, MIN(pageNumber) as startPage, MAX(pageNumber) as endPage '
      'FROM quran_meta '
      'GROUP BY juzNumber '
      'ORDER BY juzNumber ASC',
    );

    return result
        .where(
          (row) =>
              row['juzNumber'] != null &&
              row['startPage'] != null &&
              row['endPage'] != null,
        )
        .map((row) {
          return {
            'juzNumber': row['juzNumber'] as int,
            'startPage': row['startPage'] as int,
            'endPage': row['endPage'] as int,
          };
        })
        .toList();
  }

  // Get distinct pages that contain the specific Ayah range
  // Useful for marking partial memorization
  Future<List<int>> getPagesForSurahAyahRange(
    int surah,
    int startAyah,
    int endAyah,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      "SELECT DISTINCT pageNumber FROM quran_meta "
      "WHERE surahNumber = ? AND ayahNumber >= ? AND ayahNumber <= ? "
      "ORDER BY pageNumber",
      [surah, startAyah, endAyah],
    );
    return maps.map((e) => e['pageNumber'] as int).toList();
  }

  // Get distinct pages that contain the specific Rubuc range
  Future<List<int>> getPagesForRubRange(int startRub, int endRub) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      "SELECT DISTINCT pageNumber FROM quran_meta "
      "WHERE rubNumber >= ? AND rubNumber <= ? "
      "ORDER BY pageNumber",
      [startRub, endRub],
    );
    return maps.map((e) => e['pageNumber'] as int).toList();
  }

  // Fetch all meta data for granular coverage calculation
  // Returns list of {id, surahNumber, ayahNumber, rubNumber, juzNumber, pageNumber}
  Future<List<Map<String, dynamic>>> getAllQuranMeta() async {
    final db = await database;
    return await db.query('quran_meta', orderBy: 'id');
  }

  Future<List<Map<String, dynamic>>> getAyahsForPlanUnit({
    required PlanUnitType unitType,
    required int unitId,
    int? endUnitId,
    int? startAyah,
    int? endAyah,
  }) async {
    final db = await database;
    String whereClause = "";
    List<dynamic> args = [];

    if (unitType == PlanUnitType.surah) {
      whereClause = "qm.surahNumber = ?";
      args.add(unitId);
      if (startAyah != null && endAyah != null) {
        whereClause += " AND qm.ayahNumber BETWEEN ? AND ?";
        args.add(startAyah);
        args.add(endAyah);
      }
    } else if (unitType == PlanUnitType.page) {
      whereClause = "qm.pageNumber BETWEEN ? AND ?";
      args.add(unitId);
      args.add(endUnitId ?? unitId);
    } else if (unitType == PlanUnitType.juz) {
      whereClause = "qm.juzNumber = ?";
      args.add(unitId);
      // Support for granular Juz tasks (Hizb/Rubuc)
      if (startAyah != null && endAyah != null) {
        whereClause += " AND qm.rubNumber BETWEEN ? AND ?";
        args.add(startAyah);
        args.add(endAyah);
      }
    } else if (unitType == PlanUnitType.hizb) {
      int startRub = (unitId - 1) * 4 + 1;
      int endRub = unitId * 4;
      whereClause = "qm.rubNumber BETWEEN ? AND ?";
      args.add(startRub);
      args.add(endRub);
    } else {
      debugPrint("Invalid unit type: $unitType");
      return [];
    }

    return await db.rawQuery('''
      SELECT qm.id, qm.surahNumber, qm.ayahNumber, SUBSTR(qt.text, 1, 50) as text, si.surahName as surahEnglishName, si.surahArabicName
      FROM quran_meta qm
      JOIN quran_text qt ON qm.id = qt.id
      JOIN surah_info si ON qm.surahNumber = si.surahNumber
      WHERE $whereClause
      ORDER BY qm.surahNumber, qm.ayahNumber
      ''', args);
  }

  // --- Ayah ID Helpers for Task Completion ---

  Future<List<int>> getAyahIdsForPlanUnit({
    required PlanUnitType unitType,
    required int unitId,
    int? endUnitId,
    int? startAyah,
    int? endAyah,
  }) async {
    final db = await database;
    String whereClause = "";
    List<dynamic> args = [];

    if (unitType == PlanUnitType.surah) {
      whereClause = "surahNumber = ?";
      args.add(unitId);
      if (startAyah != null && endAyah != null) {
        whereClause += " AND ayahNumber BETWEEN ? AND ?";
        args.add(startAyah);
        args.add(endAyah);
      }
    } else if (unitType == PlanUnitType.page) {
      whereClause = "pageNumber BETWEEN ? AND ?";
      args.add(unitId);
      args.add(endUnitId ?? unitId);
    } else if (unitType == PlanUnitType.juz) {
      whereClause = "juzNumber = ?";
      args.add(unitId);
      // Support for granular Juz tasks (Hizb/Rubuc)
      if (startAyah != null && endAyah != null) {
        whereClause += " AND rubNumber BETWEEN ? AND ?";
        args.add(startAyah);
        args.add(endAyah);
      }
    } else if (unitType == PlanUnitType.hizb) {
      int startRub = (unitId - 1) * 4 + 1;
      int endRub = unitId * 4;
      whereClause = "rubNumber BETWEEN ? AND ?";
      args.add(startRub);
      args.add(endRub);
    } else {
      return [];
    }

    final maps = await db.query(
      'quran_meta',
      columns: ['id'],
      where: whereClause,
      whereArgs: args,
    );
    return maps.map((m) => m['id'] as int).toList();
  }

  Future<Map<String, int>> getAyahRangeForPlanUnit({
    required PlanUnitType unitType,
    required int unitId,
    int? endUnitId,
    int? startAyah,
    int? endAyah,
  }) async {
    final db = await database;
    String whereClause = "";
    List<dynamic> args = [];

    if (unitType == PlanUnitType.surah) {
      whereClause = "surahNumber = ?";
      args.add(unitId);
      if (startAyah != null && endAyah != null) {
        whereClause += " AND ayahNumber BETWEEN ? AND ?";
        args.add(startAyah);
        args.add(endAyah);
      }
    } else if (unitType == PlanUnitType.page) {
      whereClause = "pageNumber BETWEEN ? AND ?";
      args.add(unitId);
      args.add(endUnitId ?? unitId);
    } else if (unitType == PlanUnitType.juz) {
      whereClause = "juzNumber = ?";
      args.add(unitId);
      if (startAyah != null && endAyah != null) {
        whereClause += " AND rubNumber BETWEEN ? AND ?";
        args.add(startAyah);
        args.add(endAyah);
      }
    } else if (unitType == PlanUnitType.hizb) {
      int startRub = (unitId - 1) * 4 + 1;
      int endRub = unitId * 4;
      whereClause = "rubNumber BETWEEN ? AND ?";
      args.add(startRub);
      args.add(endRub);
    } else {
      return {'min': 0, 'max': 0};
    }

    final res = await db.rawQuery(
      "SELECT MIN(id) as minId, MAX(id) as maxId FROM quran_meta WHERE $whereClause",
      args,
    );

    if (res.isNotEmpty) {
      return {
        'min': res.first['minId'] as int? ?? 0,
        'max': res.first['maxId'] as int? ?? 0,
      };
    }
    return {'min': 0, 'max': 0};
  }
}
