import 'package:flutter/foundation.dart';
import 'package:reading_assist/models/books.dart';
import 'package:reading_assist/models/entries.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseServices {
  static Database? _db;
  static final DatabaseServices instance = DatabaseServices._constructor();

  DatabaseServices._constructor();

  Future<Database> get database async {
    if (_db != null) {
      return _db!;
    }
    _db = await getDatabase();
    return _db!;
  }

  Future<Database> getDatabase() async {
    final String path;
    if (kIsWeb) {
      // Web uses IndexedDB-backed virtual FS; use a plain file name.
      path = 'lumina_web.db';
    } else {
      final String databasePath = await getDatabasesPath();
      path = '$databasePath/lumina.db';
    }
    debugPrint('Database path: $path');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE books(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            author TEXT NOT NULL,
            coverUrl TEXT,
            totalPages INTEGER,
            status TEXT NOT NULL CHECK(status IN ('to-read', 'reading', 'finished')),
            createdAt TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE entries(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            bookId INTEGER NOT NULL,
            percentageRead INTEGER,
            summary TEXT,
            createdAt TEXT,
            FOREIGN KEY (bookId) REFERENCES books (id) ON DELETE CASCADE
          )
        ''');
      },
    );
  }

  Future<List<Books>> getBooks() async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('books');
    return maps
        .map(
          (map) => Books(
            id: map['id'] as int,
            title: map['title'] as String,
            author: map['author'] as String,
            coverUrl: (map['coverUrl'] as String?) ?? '',
            totalPages: (map['totalPages'] as int?) ?? 0,
            status: map['status'] as String,
            createdAt: map['createdAt'] as String?,
          ),
        )
        .toList();
  }

  Future<void> addBook(Map<String, dynamic> book) async {
    final Database db = await database;
    await db.insert('books', book);
  }

  Future<void> updateBook(int id, Map<String, dynamic> book) async {
    final Database db = await database;
    await db.update('books', book, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteBook(int id) async {
    final Database db = await database;
    await db.delete('books', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getTotalPages(int bookId) async {
    final Database db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'books',
      columns: ['totalPages'],
      where: 'id = ?',
      whereArgs: [bookId],
    );
    if (result.isNotEmpty) {
      return result.first['totalPages'] as int;
    }
    return 0; // Default to 0 if book not found
  }

  Future<List<Entries>> getEntries(int bookId) async {
    final Database db = await database;
    final List<Map<String, dynamic>> entries = await db.query(
      'entries',
      where: 'bookId = ?',
      whereArgs: [bookId],
      orderBy: 'createdAt DESC',
    );
    return entries
        .map(
          (entry) => Entries(
            id: entry['id'] as int,
            bookId: entry['bookId'] as int,
            percentageRead: entry['percentageRead'] as int? ?? 0,
            summary: entry['summary'] as String? ?? '',
            createdAt: entry['createdAt'] as String?,
          ),
        )
        .toList();
  }

  Future<void> addEntry(Map<String, dynamic> entry) async {
    final Database db = await database;
    await db.insert('entries', entry);
  }

  Future<void> updateEntry(int id, Map<String, dynamic> entry) async {
    final Database db = await database;
    await db.update('entries', entry, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getPercentageRead(int bookId) async {
    final Database db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT SUM(percentageRead) as percentageRead FROM entries WHERE bookId = ?',
      [bookId],
    );
    if (result.isNotEmpty) {
      return result.first['percentageRead'] as int? ?? 0;
    }
    return 0;
  }

  Future<void> deleteEntry(int id) async {
    final Database db = await database;
    await db.delete('entries', where: 'id = ?', whereArgs: [id]);
  }
}
