import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/services/database_services.dart';
import 'package:lumina/services/habit_services.dart';
import 'package:lumina/services/notifications_center.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final DatabaseServices databaseServices = DatabaseServices.instance;
final HabitServices habitServices = HabitServices.instance;
final DateTime today = DateTime(2026, 3, 20, 21);

DateTime daysAgo(int days) {
  return DateTime(today.year, today.month, today.day - days, 21);
}

Future<int> addBook({int totalPages = 300}) async {
  final Database db = await databaseServices.database;
  return db.insert('books', {
    'title': 'Dune',
    'author': 'Frank Herbert',
    'totalPages': totalPages,
    'status': 'reading',
  });
}

Future<void> readOn(int bookId, DateTime day, {int seconds = 0}) async {
  final Database db = await databaseServices.database;
  await db.insert('entries', {
    'bookId': bookId,
    'percentageRead': 1,
    'summary': '',
    'createdAt': day.toIso8601String(),
    'durationSeconds': seconds,
  });
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    await databaseServices.useDatabase(
      await databaseServices.openAt(inMemoryDatabasePath),
    );
  });

  tearDown(() async {
    await databaseServices.useDatabase(null);
  });

  group('streak', () {
    test('counts consecutive days including today', () async {
      final int book = await addBook();
      for (int day = 0; day < 4; day++) {
        await readOn(book, daysAgo(day));
      }

      final StreakState streak = await habitServices.getStreakState(now: today);

      expect(streak.current, 4);
      expect(streak.longest, 4);
      expect(streak.readToday, isTrue);
      expect(streak.comeback, isFalse);
    });

    test('stays alive while today is still open', () async {
      final int book = await addBook();
      await readOn(book, daysAgo(2));
      await readOn(book, daysAgo(1));

      final StreakState streak = await habitServices.getStreakState(now: today);

      expect(streak.current, 2);
      expect(streak.readToday, isFalse);
    });

    test('a missed day spends a banked freeze instead of resetting', () async {
      final int book = await addBook();
      // Seven days earn one freeze, then a gap, then reading again.
      for (int day = 9; day >= 3; day--) {
        await readOn(book, daysAgo(day));
      }
      await readOn(book, daysAgo(1));
      await readOn(book, today);

      final StreakState streak = await habitServices.getStreakState(now: today);

      expect(streak.current, 9);
      expect(streak.freezes, 0);
      expect(await databaseServices.getStreakEvents(), {
        HabitServices.dateKey(daysAgo(2)): 'freeze',
      });

      // Replaying gives the same answer and does not spend another freeze.
      final StreakState again = await habitServices.getStreakState(now: today);
      expect(again.current, 9);
      expect(again.freezes, 0);
    });

    test('banks at most two freezes', () async {
      final int book = await addBook();
      for (int day = 29; day >= 0; day--) {
        await readOn(book, daysAgo(day));
      }

      final StreakState streak = await habitServices.getStreakState(now: today);

      expect(streak.current, 30);
      expect(streak.freezes, HabitServices.maxFreezes);
    });

    test('a miss with no freeze resets and offers a repair', () async {
      final int book = await addBook();
      await readOn(book, daysAgo(4));
      await readOn(book, daysAgo(3));
      await readOn(book, daysAgo(2));

      final StreakState streak = await habitServices.getStreakState(now: today);

      expect(streak.current, 0);
      expect(streak.longest, 3);
      expect(streak.repairAvailable, isTrue);
      expect(streak.repairableStreak, 3);
    });

    test('doubling the daily goal the next day repairs the streak', () async {
      final int book = await addBook();
      await readOn(book, daysAgo(4));
      await readOn(book, daysAgo(3));
      await readOn(book, daysAgo(2));
      await readOn(
        book,
        today,
        seconds: HabitServices.defaultGoalMinutes * 60 * 2,
      );

      final StreakState streak = await habitServices.getStreakState(now: today);

      expect(streak.current, 4);
      expect(streak.repairAvailable, isFalse);
      expect(await databaseServices.getStreakEvents(), {
        HabitServices.dateKey(daysAgo(1)): 'repair',
      });
    });

    test('a short session the next day does not repair', () async {
      final int book = await addBook();
      await readOn(book, daysAgo(3));
      await readOn(book, daysAgo(2));
      await readOn(book, today, seconds: 60);

      final StreakState streak = await habitServices.getStreakState(now: today);

      expect(streak.current, 1);
      expect(streak.repairAvailable, isTrue);
      expect(streak.comeback, isTrue);
    });

    test('the repair window closes after one day', () async {
      final int book = await addBook();
      await readOn(book, daysAgo(5));
      await readOn(book, daysAgo(4));
      await readOn(book, today, seconds: 3600);

      final StreakState streak = await habitServices.getStreakState(now: today);

      expect(streak.current, 1);
      expect(streak.repairAvailable, isFalse);
      expect(await databaseServices.getStreakEvents(), isEmpty);
    });
  });

  group('celebrations', () {
    test('the comeback is celebrated once', () async {
      final int book = await addBook();
      await readOn(book, daysAgo(6));
      await readOn(book, today);

      final Celebration? first = await habitServices.afterEntry(now: today);
      final Celebration? second = await habitServices.afterEntry(now: today);

      expect(first?.title, 'You came back.');
      expect(first?.big, isTrue);
      expect(second, isNull);
    });

    test('a streak milestone is celebrated once', () async {
      final int book = await addBook();
      for (int day = 6; day >= 0; day--) {
        await readOn(book, daysAgo(day));
      }

      final Celebration? first = await habitServices.afterEntry(now: today);
      final Celebration? second = await habitServices.afterEntry(now: today);

      expect(first?.title, '7 days in a row');
      expect(second, isNull);
    });
  });

  group('entries', () {
    test('a timed session that rounds to 0% is still saved', () async {
      final int book = await addBook(totalPages: 900);
      await databaseServices.addEntry({
        'bookId': book,
        'percentageRead': 0,
        'summary': '',
        'createdAt': today.toIso8601String(),
        'pagesRead': 2,
        'durationSeconds': 300,
      });

      expect(await databaseServices.getEntries(book), hasLength(1));
      expect(
        await databaseServices.getSecondsOnDate(HabitServices.dateKey(today)),
        300,
      );
    });

    test('an entry with no progress and no session is ignored', () async {
      final int book = await addBook();
      await databaseServices.addEntry({
        'bookId': book,
        'percentageRead': 0,
        'summary': '',
        'createdAt': today.toIso8601String(),
      });

      expect(await databaseServices.getEntries(book), isEmpty);
    });

    test('today shows the hook, pages left and time left', () async {
      final int book = await addBook(totalPages: 200);
      await databaseServices.addEntry({
        'bookId': book,
        'percentageRead': 50,
        'summary': 'Paul meets the Fremen.',
        'createdAt': today.toIso8601String(),
        'pagesRead': 100,
        'durationSeconds': 6000,
        'hook': 'Does Jessica survive the desert?',
      });

      final TodayData data = await habitServices.getToday(now: today);

      expect(data.book?.title, 'Dune');
      expect(data.hook, 'Does Jessica survive the desert?');
      expect(data.pagesLeft, 100);
      expect(data.secondsLeft, 6000);
      expect(data.secondsToday, 6000);
    });
  });

  group('migration', () {
    test('a version 1 database upgrades with its rows intact', () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'lumina_test',
      );
      final String path = '${directory.path}/lumina.db';
      final Database old = await openDatabase(
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
      final int book = await old.insert('books', {
        'title': 'Dune',
        'author': 'Frank Herbert',
        'totalPages': 300,
        'status': 'reading',
      });
      await old.insert('entries', {
        'bookId': book,
        'percentageRead': 12,
        'summary': 'old note',
        'createdAt': today.toIso8601String(),
      });
      await old.close();

      await databaseServices.useDatabase(await databaseServices.openAt(path));

      expect((await databaseServices.getBooks()).single.title, 'Dune');
      expect(
        (await databaseServices.getEntries(book)).single.summary,
        'old note',
      );
      expect(await databaseServices.getPercentageRead(book), 12);
      await databaseServices.setSetting('dailyGoalMinutes', '20');
      expect(await habitServices.getGoalMinutes(), 20);
      expect((await habitServices.getStreakState(now: today)).current, 1);

      // Foreign keys are now enforced, so entries go with their book.
      await databaseServices.deleteBook(book);
      expect(await databaseServices.getEntries(book), isEmpty);

      await databaseServices.useDatabase(null);
      await directory.delete(recursive: true);
    });
  });

  group('reminders', () {
    test('fire a little before the usual reading time', () {
      expect(NotificationsCenter.reminderMinuteOfDay(<DateTime>[]), 20 * 60);
      expect(
        NotificationsCenter.reminderMinuteOfDay(<DateTime>[
          DateTime(2026, 3, 18, 22, 0),
          DateTime(2026, 3, 19, 21, 30),
          DateTime(2026, 3, 20, 7, 0),
        ]),
        21 * 60 + 15,
      );
    });

    test('count how many in a row were ignored', () {
      expect(NotificationsCenter.countIgnored(<bool>[]), 0);
      expect(
        NotificationsCenter.countIgnored(<bool>[false, true, false, false]),
        2,
      );
    });

    test('are written from the reader\'s own notes', () async {
      final int book = await addBook(totalPages: 200);
      await databaseServices.addEntry({
        'bookId': book,
        'percentageRead': 50,
        'summary': '',
        'createdAt': today.toIso8601String(),
        'pagesRead': 100,
        'durationSeconds': 6000,
        'hook': 'Does Jessica survive the desert?',
      });
      await databaseServices.setSetting('planCue', 'finish dinner');

      final List<ReminderMessage> messages = NotificationsCenter.buildMessages(
        await habitServices.getToday(now: today),
        'put the phone on the desk',
      );

      expect(messages.map((message) => message.body), [
        'You wanted to know: Does Jessica survive the desert?',
        '100 pages left, about 1h 40m.',
        'One page keeps the streak.',
        'Then: put the phone on the desk.',
      ]);
    });
  });
}
