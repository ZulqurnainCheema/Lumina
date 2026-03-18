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
            status TEXT NOT NULL CHECK(status IN ('to-read', 'reading', 'read')),
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

  Future<List<DateTime>> getRecentEntryTimes({int limit = 14}) async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.query(
      'entries',
      columns: ['createdAt'],
      where: 'createdAt IS NOT NULL',
      orderBy: 'createdAt DESC',
      limit: limit,
    );
    return rows
        .map((row) => row['createdAt'] as String?)
        .whereType<String>()
        .map(DateTime.tryParse)
        .whereType<DateTime>()
        .toList();
  }

  Future<DateTime?> getLastEntryTime() async {
    final List<DateTime> recentEntries = await getRecentEntryTimes(limit: 1);
    if (recentEntries.isEmpty) {
      return null;
    }
    return recentEntries.first;
  }

  Future<void> addEntry(Map<String, dynamic> entry) async {
    final Database db = await database;
    final int bookId = (entry['bookId'] as num).toInt();
    final int currentTotal = await getPercentageRead(bookId);
    final int requestedProgress = ((entry['percentageRead'] as num?) ?? 0)
        .toInt()
        .clamp(0, 100);
    final int remaining = (100 - currentTotal).clamp(0, 100);
    final int progressToInsert = requestedProgress.clamp(0, remaining);

    if (progressToInsert <= 0) {
      return;
    }

    final Map<String, dynamic> safeEntry = Map<String, dynamic>.from(entry)
      ..['percentageRead'] = progressToInsert;
    await db.insert('entries', safeEntry);

    final int newTotal = currentTotal + progressToInsert;
    if (currentTotal == 0) {
      await updateBook(bookId, {'status': 'reading'});
    }
    if (newTotal > 80) {
      await updateBook(bookId, {'status': 'read'});
    }
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

  Future<List<String>> getSummaries(int bookId) async {
    final Database db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'entries',
      columns: ['summary'],
      where: 'bookId = ?',
      whereArgs: [bookId],
    );
    return result
        .map((row) => row['summary'] as String?)
        .whereType<String>()
        .toList();
  }

  Future<void> deleteEntry(int id) async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.query(
      'entries',
      columns: ['bookId'],
      where: 'id = ?',
      whereArgs: [id],
    );
    await db.delete('entries', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;
    final int bookId = rows.first['bookId'] as int;
    final int newTotal = await getPercentageRead(bookId);
    if (newTotal <= 0) {
      await updateBook(bookId, {'status': 'to-read'});
    } else if (newTotal < 85) {
      await updateBook(bookId, {'status': 'reading'});
    } else {
      await updateBook(bookId, {'status': 'read'});
    }
  }

  //Reporting functions
  Future<Map<String, dynamic>> getProgressReportbyDateofAllBooks() async {
    final Database db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT 
        date(createdAt) as date, 
        SUM(percentageRead) as totalProgress
      FROM entries
      WHERE createdAt IS NOT NULL
      GROUP BY date(createdAt)
      ORDER BY date(createdAt) ASC
    ''');
    return {
      'dates': result.map((row) => row['date'] as String).toList(),
      'progress': result
          .map((row) => row['totalProgress'] as int? ?? 0)
          .toList(),
    };
  }

  Future<int> getDaysStreak() async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.rawQuery('''
      SELECT DISTINCT date(createdAt) as entryDate
      FROM entries
      WHERE createdAt IS NOT NULL
      ORDER BY date(createdAt) DESC
    ''');

    if (rows.isEmpty) {
      return 0;
    }

    final List<DateTime> entryDates = rows
        .map((row) => row['entryDate'] as String?)
        .whereType<String>()
        .map(DateTime.parse)
        .map((date) => DateTime(date.year, date.month, date.day))
        .toList();

    final DateTime today = DateTime.now();
    final DateTime normalizedToday = DateTime(
      today.year,
      today.month,
      today.day,
    );
    final DateTime yesterday = normalizedToday.subtract(
      const Duration(days: 1),
    );

    if (entryDates.first != normalizedToday && entryDates.first != yesterday) {
      return 0;
    }

    int streak = 1;
    for (int index = 1; index < entryDates.length; index++) {
      final int difference = entryDates[index - 1]
          .difference(entryDates[index])
          .inDays;
      if (difference != 1) {
        break;
      }
      streak++;
    }

    return streak;
  }

  Future<int> getWeeklyProgress() async {
    final Database db = await database;
    final DateTime now = DateTime.now();
    final DateTime startDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));

    final List<Map<String, dynamic>> result = await db.rawQuery(
      '''
      SELECT SUM(percentageRead) as weeklyProgress
      FROM entries
      WHERE createdAt IS NOT NULL
        AND date(createdAt) >= date(?)
      ''',
      [startDate.toIso8601String()],
    );

    if (result.isEmpty) {
      return 0;
    }
    final Object? weeklyProgress = result.first['weeklyProgress'];
    if (weeklyProgress is int) {
      return weeklyProgress;
    }
    if (weeklyProgress is double) {
      return weeklyProgress.round();
    }
    return 0;
  }

  Future<double> getAverageDailyProgress() async {
    final Database db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT AVG(dailyProgress) as averageDailyProgress
      FROM (
        SELECT date(createdAt) as day, SUM(percentageRead) as dailyProgress
        FROM entries
        WHERE createdAt IS NOT NULL
        GROUP BY date(createdAt)
      )
    ''');

    if (result.isEmpty) {
      return 0;
    }

    final Object? average = result.first['averageDailyProgress'];
    if (average is int) {
      return average.toDouble();
    }
    if (average is double) {
      return average;
    }
    return 0;
  }

  Future<int> getFinishedBooksCount() async {
    final Database db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT COUNT(*) as finishedBooks
      FROM books
      WHERE status = 'read'
    ''');

    if (result.isEmpty) {
      return 0;
    }

    final Object? count = result.first['finishedBooks'];
    if (count is int) {
      return count;
    }
    if (count is double) {
      return count.round();
    }
    return 0;
  }
}
