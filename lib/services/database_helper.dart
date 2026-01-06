import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/ayah.dart';
import '../models/surah.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    var databasesPath = await getDatabasesPath();
    var path = join(databasesPath, 'quran.db');

    // Check if the database exists
    var exists = await databaseExists(path);

    if (exists) {
      // Check for schema updates (e.g. missing rubNumber column)
      // Since we can't easily alter the pre-packaged DB structure without migration scripts,
      // we check validity. If invalid (old version), we delete and re-copy.
      try {
        final db = await openDatabase(path, readOnly: true);
        final tableInfo = await db.rawQuery("PRAGMA table_info(quran_meta)");
        final hasRubNumber = tableInfo.any((c) => c['name'] == 'rubNumber');
        await db.close();

        if (!hasRubNumber) {
          print("Old database version detected. Deleting...");
          await deleteDatabase(path);
          exists = false;
        }
      } catch (e) {
        print("Error checking database version: $e");
        // If corrupt, delete
        await deleteDatabase(path);
        exists = false;
      }
    }

    if (!exists) {
      // Should be capable of handling the copy from assets
      print("Creating new copy from asset");

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
      print("Opening existing database");
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
}
