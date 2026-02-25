import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class HistoryDatabase {
  static final HistoryDatabase instance = HistoryDatabase._init();
  static Database? _database;

  HistoryDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('history.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(path, version: 2, onCreate: _createDB, onUpgrade: _upgradeDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        url TEXT,
        favicon TEXT,
        timestamp TEXT
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE history ADD COLUMN favicon TEXT');
    }
  }

  Future<int> insertHistory(Map<String, dynamic> history) async {
    final db = await instance.database;
    final url = history['url'];
    
    // Check if URL already exists
    final existing = await db.query(
      'history',
      where: 'url = ?',
      whereArgs: [url],
      limit: 1,
    );
    
    if (existing.isNotEmpty) {
      // Update existing entry with new timestamp and data
      return await db.update(
        'history',
        history,
        where: 'url = ?',
        whereArgs: [url],
      );
    } else {
      // Insert new entry
      return await db.insert('history', history);
    }
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    final db = await instance.database;
    return await db.query('history', orderBy: 'timestamp DESC');
  }

  Future<int> deleteHistory(int id) async {
    final db = await instance.database;
    return await db.delete('history', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> clearHistory() async {
    final db = await instance.database;
    return await db.delete('history');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
