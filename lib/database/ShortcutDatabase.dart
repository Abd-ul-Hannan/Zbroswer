import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import '../models/shortcut_model.dart';

class ShortcutDatabase {
  static final ShortcutDatabase instance = ShortcutDatabase._init();
  static Database? _database;

  ShortcutDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('shortcuts.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE shortcuts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        url TEXT,
        favicon TEXT
      )
    ''');

    // Insert default shortcuts
    await db.insert('shortcuts', {'title': 'Google', 'url': 'https://www.google.com', 'favicon': 'https://www.google.com/favicon.ico'});
    await db.insert('shortcuts', {'title': 'YouTube', 'url': 'https://www.youtube.com', 'favicon': 'https://www.youtube.com/favicon.ico'});
    await db.insert('shortcuts', {'title': 'Facebook', 'url': 'https://www.facebook.com', 'favicon': 'https://www.facebook.com/favicon.ico'});
    await db.insert('shortcuts', {'title': 'Twitter', 'url': 'https://www.twitter.com', 'favicon': 'https://www.twitter.com/favicon.ico'});
    await db.insert('shortcuts', {'title': 'Amazon', 'url': 'https://www.amazon.com', 'favicon': 'https://www.amazon.com/favicon.ico'});
    await db.insert('shortcuts', {'title': 'Wikipedia', 'url': 'https://www.wikipedia.org', 'favicon': 'https://www.wikipedia.org/favicon.ico'});
  }

  Future<int> insertShortcut(ShortcutModel shortcut) async {
    final db = await instance.database;
    return await db.insert('shortcuts', shortcut.toMap());
  }

  Future<List<ShortcutModel>> getShortcuts() async {
    final db = await instance.database;
    final result = await db.query('shortcuts', orderBy: 'id ASC');
    return result.map((map) => ShortcutModel.fromMap(map)).toList();
  }

  Future<int> deleteShortcut(int id) async {
    final db = await instance.database;
    final result = await db.delete('shortcuts', where: 'id = ?', whereArgs: [id]);
    debugPrint('Deleted shortcut with id: $id, result: $result');
    return result;
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
