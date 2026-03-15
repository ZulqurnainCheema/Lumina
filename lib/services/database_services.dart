import 'package:flutter/widgets.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseServices {
  static Database? _db;
  static final DatabaseServices instance = DatabaseServices._constructor();
  DatabaseServices._constructor();

  Future<Database> get database async {
    if (_db != null) {
      return _db!;
    } else {
      _db = await getDatabase();
      return _db!;
    }
  }

  Future<Database> getDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = '$databasePath/lumina.db';
    debugPrint('Database path: $path');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE books(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            author TEXT,
            coverUrl TEXT,
            totalPages INTEGER,
            status ENUM('to-read', 'reading', 'read'),
            createdAt TEXT
          )
          CREATE TABLE entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            bookId INTEGER,
            percentageRead INTEGER,
            summary TEXT,
            createdAt TEXT,
            FOREIGN KEY (bookId) REFERENCES books (id) ON DELETE CASCADE
          )
        ''');
      },
    );
  }

  Future<List<Map<String, dynamic>>> getBooks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('books');
    return maps;
  }

  void addBook(Map<String, dynamic> book) async {
    final db = await database;
    await db.insert('books', book);
  }

  void updateBook(int id, Map<String, dynamic> book) async {
    final db = await database;
    await db.update('books', book, where: 'id = ?', whereArgs: [id]);
  }

  void deleteBook(int id) async {
    final db = await database;
    await db.delete('books', where: 'id = ?', whereArgs: [id]);
  }

  void getEntries(int bookId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'entries',
      where: 'bookId = ?',
      whereArgs: [bookId],
    );
  }

  void addEntry(Map<String, dynamic> entry) async {
    final db = await database;
    await db.insert('entries', entry);
  }

  void updateEntry(int id, Map<String, dynamic> entry) async {
    final db = await database;
    await db.update('entries', entry, where: 'id = ?', whereArgs: [id]);
  }

  void deleteEntry(int id) async {
    final db = await database;
    await db.delete('entries', where: 'id = ?', whereArgs: [id]);
  }
}
