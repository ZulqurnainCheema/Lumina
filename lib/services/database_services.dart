import 'package:flutter/foundation.dart';
import 'package:lumina/models/books.dart';
import 'package:lumina/models/entries.dart';
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

    return openAt(path);
  }

  Future<Database> openAt(String path) {
    return openDatabase(
      path,
      version: 3,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE books(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            author TEXT NOT NULL,
            coverUrl TEXT,
            totalPages INTEGER,
            status TEXT NOT NULL CHECK(status IN ('to-read', 'reading', 'read')),
            createdAt TEXT,
            abandonedAt TEXT,
            currentPage INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE entries(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            bookId INTEGER NOT NULL,
            percentageRead INTEGER,
            summary TEXT,
            createdAt TEXT,
            pagesRead INTEGER,
            durationSeconds INTEGER,
            hook TEXT,
            absorption INTEGER,
            FOREIGN KEY (bookId) REFERENCES books (id) ON DELETE CASCADE
          )
        ''');

        await _createHabitTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE books ADD COLUMN abandonedAt TEXT');
          await db.execute('ALTER TABLE entries ADD COLUMN pagesRead INTEGER');
          await db.execute(
            'ALTER TABLE entries ADD COLUMN durationSeconds INTEGER',
          );
          await db.execute('ALTER TABLE entries ADD COLUMN hook TEXT');
          await db.execute('ALTER TABLE entries ADD COLUMN absorption INTEGER');
          await _createHabitTables(db);
        }
        if (oldVersion < 3) {
          // The page the reader is on. Empty until the book is next logged,
          // when it takes over from adding up the old entries.
          await db.execute('ALTER TABLE books ADD COLUMN currentPage INTEGER');
        }
      },
    );
  }

  Future<void> _createHabitTables(Database db) async {
    await db.execute('''
      CREATE TABLE settings(
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE streak_events(
        date TEXT PRIMARY KEY,
        type TEXT NOT NULL CHECK(type IN ('freeze', 'repair'))
      )
    ''');

    await db.execute('''
      CREATE TABLE habit_checks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        createdAt TEXT,
        score INTEGER
      )
    ''');
  }

  @visibleForTesting
  Future<void> useDatabase(Database? db) async {
    await _db?.close();
    _db = db;
  }

  Future<List<Books>> getBooks() async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('books');
    return maps.map(_bookFromMap).toList();
  }

  Books _bookFromMap(Map<String, dynamic> map) {
    return Books(
      id: map['id'] as int,
      title: map['title'] as String,
      author: map['author'] as String,
      coverUrl: (map['coverUrl'] as String?) ?? '',
      totalPages: (map['totalPages'] as int?) ?? 0,
      status: map['status'] as String,
      createdAt: map['createdAt'] as String?,
      abandonedAt: map['abandonedAt'] as String?,
      currentPage: map['currentPage'] as int?,
    );
  }

  Future<Books?> getBook(int bookId) async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.query(
      'books',
      where: 'id = ?',
      whereArgs: [bookId],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _bookFromMap(rows.first);
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
      return result.first['totalPages'] as int? ?? 0;
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
            pagesRead: entry['pagesRead'] as int?,
            durationSeconds: entry['durationSeconds'] as int?,
            hook: entry['hook'] as String?,
            absorption: entry['absorption'] as int?,
          ),
        )
        .toList();
  }

  Future<Entries?> getEntry(int id) async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.query(
      'entries',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) {
      return null;
    }
    final Map<String, dynamic> entry = rows.first;
    return Entries(
      id: entry['id'] as int,
      bookId: entry['bookId'] as int,
      percentageRead: entry['percentageRead'] as int? ?? 0,
      summary: entry['summary'] as String? ?? '',
      createdAt: entry['createdAt'] as String?,
      pagesRead: entry['pagesRead'] as int?,
      durationSeconds: entry['durationSeconds'] as int?,
      hook: entry['hook'] as String?,
      absorption: entry['absorption'] as int?,
    );
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

  // Saves one reading session and moves the book's bookmark. The bookmark
  // (books.currentPage) is the one record of where the reader is; the percent
  // and "pages left" shown anywhere are worked out from it.
  Future<void> addEntry(Map<String, dynamic> entry) async {
    final Database db = await database;
    final int bookId = (entry['bookId'] as num).toInt();
    final int totalPages = await getTotalPages(bookId);
    final int percentBefore = await getPercentageRead(bookId);
    final int requestedPercent = ((entry['percentageRead'] as num?) ?? 0)
        .toInt()
        .clamp(0, 100);
    final bool hasTime = ((entry['durationSeconds'] as num?) ?? 0) > 0;

    final Map<String, dynamic> safeEntry = Map<String, dynamic>.from(entry);
    int percentAfter;
    if (totalPages > 0) {
      final int pageBefore = await getCurrentPage(bookId);
      final int requestedPages =
          (entry['pagesRead'] as num?)?.toInt() ??
          (requestedPercent * totalPages / 100).round();
      final int pageAfter = (pageBefore + requestedPages).clamp(0, totalPages);
      percentAfter = (pageAfter * 100 / totalPages).floor();
      if (pageAfter == pageBefore && !hasTime) {
        return;
      }
      safeEntry['pagesRead'] = pageAfter - pageBefore;
      safeEntry['percentageRead'] = (percentAfter - percentBefore).clamp(
        0,
        100,
      );
      await db.insert('entries', safeEntry);
      await updateBook(bookId, {'currentPage': pageAfter});
    } else {
      // No page count for this book, so it is tracked by percent alone.
      final int progress = requestedPercent.clamp(0, 100 - percentBefore);
      final bool hasPages = ((entry['pagesRead'] as num?) ?? 0) > 0;
      if (progress <= 0 && !hasTime && !hasPages) {
        return;
      }
      safeEntry['percentageRead'] = progress;
      await db.insert('entries', safeEntry);
      percentAfter = percentBefore + progress;
    }

    await updateBook(bookId, {'abandonedAt': null});
    await _updateStatus(bookId, percentAfter, started: true);
  }

  // A book is finished when all of it is read, the same point at which
  // "pages left" reaches zero.
  Future<void> _updateStatus(
    int bookId,
    int percent, {
    bool started = false,
  }) async {
    final String status;
    if (percent >= 100) {
      status = 'read';
    } else if (percent > 0 || started) {
      status = 'reading';
    } else {
      status = 'to-read';
    }
    await updateBook(bookId, {'status': status});
  }

  // Corrects where the reader is without logging a session.
  Future<void> setBookmark(int bookId, int page) async {
    final int totalPages = await getTotalPages(bookId);
    final int clamped = totalPages > 0 ? page.clamp(0, totalPages) : page;
    await updateBook(bookId, {'currentPage': clamped});
    final bool hasEntries = (await getEntries(bookId)).isNotEmpty;
    await _updateStatus(
      bookId,
      await getPercentageRead(bookId),
      started: hasEntries,
    );
  }

  // Changes a saved session. If its page count changes, the bookmark moves
  // by the same amount.
  Future<void> editEntry(int id, Map<String, dynamic> changes) async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.query(
      'entries',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) {
      return;
    }
    final int bookId = rows.first['bookId'] as int;
    final int oldPages = rows.first['pagesRead'] as int? ?? 0;
    final int pageBefore = await getCurrentPage(bookId);
    await db.update('entries', changes, where: 'id = ?', whereArgs: [id]);
    if (changes.containsKey('pagesRead')) {
      final int newPages = changes['pagesRead'] as int? ?? 0;
      await setBookmark(bookId, pageBefore + newPages - oldPages);
    }
  }

  Future<void> updateEntry(int id, Map<String, dynamic> entry) async {
    final Database db = await database;
    await db.update('entries', entry, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getPercentageRead(int bookId) async {
    final Database db = await database;
    // Once a book has a bookmark, the percent comes from it.
    final Books? book = await getBook(bookId);
    if (book?.currentPage != null && book!.totalPages > 0) {
      return (book.currentPage! * 100 / book.totalPages).floor().clamp(0, 100);
    }
    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT SUM(percentageRead) as percentageRead FROM entries WHERE bookId = ?',
      [bookId],
    );
    if (result.isNotEmpty) {
      return ((result.first['percentageRead'] as int?) ?? 0).clamp(0, 100);
    }
    return 0;
  }

  Future<int> getPagesRead(int bookId) async {
    final Database db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT SUM(pagesRead) as pagesRead FROM entries WHERE bookId = ?',
      [bookId],
    );
    return (result.first['pagesRead'] as num?)?.toInt() ?? 0;
  }

  // The page the reader is on: the book's bookmark, or for a book not logged
  // since bookmarks were added, worked out from its old entries.
  Future<int> getCurrentPage(int bookId) async {
    final Books? book = await getBook(bookId);
    if (book?.currentPage != null) {
      return book!.currentPage!;
    }
    final int totalPages = book?.totalPages ?? 0;
    final int pages = await getPagesRead(bookId);
    if (totalPages <= 0) {
      return pages;
    }
    final int fromPercent = (await getPercentageRead(bookId) * totalPages / 100)
        .round();
    return (pages > fromPercent ? pages : fromPercent).clamp(0, totalPages);
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
        .where((summary) => summary.trim().isNotEmpty)
        .toList();
  }

  Future<void> deleteEntry(int id) async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.query(
      'entries',
      columns: ['bookId', 'pagesRead'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return;
    final int bookId = rows.first['bookId'] as int;
    // Take the session's pages back off the bookmark.
    final int pageBefore = await getCurrentPage(bookId);
    await db.delete('entries', where: 'id = ?', whereArgs: [id]);
    final Books? book = await getBook(bookId);
    if (book?.currentPage != null) {
      final int pages = rows.first['pagesRead'] as int? ?? 0;
      await updateBook(bookId, {
        'currentPage': (pageBefore - pages).clamp(0, pageBefore),
      });
    }
    await _updateStatus(
      bookId,
      await getPercentageRead(bookId),
      started: (await getEntries(bookId)).isNotEmpty,
    );
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

  //Settings
  Future<String?> getSetting(String key) async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String? value) async {
    final Database db = await database;
    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> getIntSetting(String key, int fallback) async {
    final String? value = await getSetting(key);
    return int.tryParse(value ?? '') ?? fallback;
  }

  //Habit functions
  Future<Set<String>> getReadDates() async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.rawQuery('''
      SELECT DISTINCT date(createdAt) as entryDate
      FROM entries
      WHERE createdAt IS NOT NULL
    ''');
    return rows
        .map((row) => row['entryDate'] as String?)
        .whereType<String>()
        .toSet();
  }

  Future<Map<String, String>> getStreakEvents() async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.query('streak_events');
    return {
      for (final Map<String, dynamic> row in rows)
        row['date'] as String: row['type'] as String,
    };
  }

  Future<void> addStreakEvent(String date, String type) async {
    final Database db = await database;
    await db.insert('streak_events', {
      'date': date,
      'type': type,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<int> getSecondsOnDate(String date) async {
    final Database db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
      '''
      SELECT SUM(durationSeconds) as seconds
      FROM entries
      WHERE createdAt IS NOT NULL
        AND date(createdAt) = ?
      ''',
      [date],
    );
    return (result.first['seconds'] as num?)?.toInt() ?? 0;
  }

  // The book being read most recently, or the newest unread one.
  Future<Books?> getCurrentBook() async {
    final Database db = await database;
    final List<Map<String, dynamic>> reading = await db.rawQuery('''
      SELECT books.*
      FROM books
      LEFT JOIN entries ON entries.bookId = books.id
      WHERE books.status = 'reading' AND books.abandonedAt IS NULL
      GROUP BY books.id
      ORDER BY MAX(entries.createdAt) DESC
      LIMIT 1
    ''');
    if (reading.isNotEmpty) {
      return _bookFromMap(reading.first);
    }
    final List<Map<String, dynamic>> toRead = await db.query(
      'books',
      where: "status = 'to-read' AND abandonedAt IS NULL",
      orderBy: 'createdAt DESC',
      limit: 1,
    );
    if (toRead.isNotEmpty) {
      return _bookFromMap(toRead.first);
    }
    return null;
  }

  // Every book in progress, most recently read first.
  Future<List<Books>> getReadingBooks() async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.rawQuery('''
      SELECT books.*
      FROM books
      LEFT JOIN entries ON entries.bookId = books.id
      WHERE books.status = 'reading' AND books.abandonedAt IS NULL
      GROUP BY books.id
      ORDER BY MAX(entries.createdAt) DESC
    ''');
    return rows.map(_bookFromMap).toList();
  }

  Future<String?> getLatestHook(int bookId) async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.query(
      'entries',
      columns: ['hook'],
      where: "bookId = ? AND hook IS NOT NULL AND trim(hook) != ''",
      whereArgs: [bookId],
      orderBy: 'createdAt DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['hook'] as String?;
  }

  // Seconds per page for this book, falling back to every book.
  Future<double?> getSecondsPerPage(int bookId) async {
    final Database db = await database;
    for (final String filter in <String>['AND bookId = $bookId', '']) {
      final List<Map<String, dynamic>> result = await db.rawQuery('''
        SELECT SUM(durationSeconds) as seconds, SUM(pagesRead) as pages
        FROM entries
        WHERE durationSeconds > 0 AND pagesRead > 0 $filter
      ''');
      final int seconds = (result.first['seconds'] as num?)?.toInt() ?? 0;
      final int pages = (result.first['pages'] as num?)?.toInt() ?? 0;
      if (pages > 0) {
        return seconds / pages;
      }
    }
    return null;
  }

  // A note written 1, 7 or 30 days ago, to be recalled before it is shown.
  Future<Map<String, dynamic>?> getRecallEntry(String today) async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.rawQuery(
      '''
      SELECT entries.summary as summary, books.title as title
      FROM entries
      JOIN books ON books.id = entries.bookId
      WHERE entries.summary IS NOT NULL
        AND trim(entries.summary) != ''
        AND CAST(julianday(?) - julianday(date(entries.createdAt)) AS INTEGER)
          IN (1, 7, 30)
      ORDER BY entries.createdAt DESC
      LIMIT 1
      ''',
      [today],
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first;
  }

  Future<List<Books>> getStaleBooks(String today, {int days = 7}) async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.rawQuery(
      '''
      SELECT books.*
      FROM books
      JOIN entries ON entries.bookId = books.id
      WHERE books.status = 'reading' AND books.abandonedAt IS NULL
      GROUP BY books.id
      HAVING julianday(?) - julianday(date(MAX(entries.createdAt))) >= ?
      ''',
      [today, days],
    );
    return rows.map(_bookFromMap).toList();
  }

  Future<Map<String, int>> getLifetimeTotals() async {
    final Database db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT
        SUM(pagesRead) as pages,
        SUM(durationSeconds) as seconds,
        MAX(durationSeconds) as longestSession
      FROM entries
    ''');
    return {
      'pages': (result.first['pages'] as num?)?.toInt() ?? 0,
      'seconds': (result.first['seconds'] as num?)?.toInt() ?? 0,
      'longestSession': (result.first['longestSession'] as num?)?.toInt() ?? 0,
    };
  }

  Future<Map<String, int>> getPeriodSummary(String from, String to) async {
    final Database db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
      '''
      SELECT
        COUNT(DISTINCT date(createdAt)) as days,
        SUM(durationSeconds) as seconds,
        SUM(pagesRead) as pages,
        MAX(durationSeconds) as longestSession
      FROM entries
      WHERE createdAt IS NOT NULL
        AND date(createdAt) >= ? AND date(createdAt) <= ?
      ''',
      [from, to],
    );
    return {
      'days': (result.first['days'] as num?)?.toInt() ?? 0,
      'seconds': (result.first['seconds'] as num?)?.toInt() ?? 0,
      'pages': (result.first['pages'] as num?)?.toInt() ?? 0,
      'longestSession': (result.first['longestSession'] as num?)?.toInt() ?? 0,
    };
  }

  Future<Map<String, int>> getMinutesByDate(String from) async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.rawQuery(
      '''
      SELECT date(createdAt) as day, SUM(durationSeconds) as seconds
      FROM entries
      WHERE createdAt IS NOT NULL AND date(createdAt) >= ?
      GROUP BY date(createdAt)
      ''',
      [from],
    );
    return {
      for (final Map<String, dynamic> row in rows)
        row['day'] as String: ((row['seconds'] as num?)?.toInt() ?? 0) ~/ 60,
    };
  }

  Future<int?> getBestReadingHour() async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.rawQuery('''
      SELECT CAST(strftime('%H', createdAt) AS INTEGER) as hour
      FROM entries
      WHERE createdAt IS NOT NULL
      GROUP BY hour
      ORDER BY COUNT(*) DESC
      LIMIT 1
    ''');
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['hour'] as int?;
  }

  Future<void> addHabitCheck(int score, String createdAt) async {
    final Database db = await database;
    await db.insert('habit_checks', {'score': score, 'createdAt': createdAt});
  }

  Future<List<Map<String, dynamic>>> getHabitChecks() async {
    final Database db = await database;
    return db.query('habit_checks', orderBy: 'createdAt ASC');
  }
}
