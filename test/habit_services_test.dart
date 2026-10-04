import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/research.dart';
import 'package:lumina/services/backup_services.dart';
import 'package:lumina/services/database_services.dart';
import 'package:lumina/services/habit_services.dart';
import 'package:lumina/services/home_widget_service.dart';
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

  group('coherence', () {
    test('a book is finished at 100%, not before', () async {
      final int book = await addBook();
      await databaseServices.addEntry({
        'bookId': book,
        'percentageRead': 90,
        'summary': '',
        'createdAt': today.toIso8601String(),
      });
      expect((await databaseServices.getBook(book))?.status, 'reading');
      expect((await habitServices.getToday(now: today)).book?.id, book);

      await databaseServices.addEntry({
        'bookId': book,
        'percentageRead': 10,
        'summary': '',
        'createdAt': today.toIso8601String(),
      });
      expect((await databaseServices.getBook(book))?.status, 'read');
      expect(await databaseServices.getFinishedBooksCount(), 1);

      // Deleting the last entry puts it back in progress.
      final entries = await databaseServices.getEntries(book);
      await databaseServices.deleteEntry(
        entries.firstWhere((entry) => entry.percentageRead == 10).id!,
      );
      expect((await databaseServices.getBook(book))?.status, 'reading');
    });

    test('the page typed is where you are, not how many you read', () {
      // Was on page 24, now on page 42 of 320.
      final progress = HabitServices.resolveProgress(
        byPages: true,
        position: 42,
        totalPages: 320,
        percentSoFar: 7,
        currentPage: 24,
      );
      expect(progress.pages, 18);
      expect(progress.percent, 6); // 42 of 320 is 13%, up from 7%
    });

    test('the percent typed is where you are, and records the pages', () {
      // Was at 10% (page 32), now at 25% of 320 pages.
      final progress = HabitServices.resolveProgress(
        byPages: false,
        position: 25,
        totalPages: 320,
        percentSoFar: 10,
        currentPage: 32,
      );
      expect(progress.percent, 15);
      expect(progress.pages, 48);
    });

    test('short sessions add up instead of rounding to nothing', () {
      // Three pages at a time through a 900-page book.
      int percent = 0;
      int page = 0;
      for (int session = 1; session <= 6; session++) {
        final progress = HabitServices.resolveProgress(
          byPages: true,
          position: session * 3,
          totalPages: 900,
          percentSoFar: percent,
          currentPage: page,
        );
        percent += progress.percent;
        page += progress.pages!;
      }
      expect(page, 18);
      expect(percent, 2);
    });

    test('reaching the last page finishes the book', () {
      final progress = HabitServices.resolveProgress(
        byPages: true,
        position: 300,
        totalPages: 300,
        percentSoFar: 60,
        currentPage: 180,
      );
      expect(progress.percent, 40);
      expect(progress.pages, 120);
    });

    test('pages left counts from the page you are on', () async {
      final int book = await addBook(totalPages: 320);
      await databaseServices.addEntry({
        'bookId': book,
        'percentageRead': 13,
        'summary': '',
        'createdAt': today.toIso8601String(),
        'pagesRead': 42,
      });

      expect(await databaseServices.getCurrentPage(book), 42);
      expect((await habitServices.getToday(now: today)).pagesLeft, 278);
    });

    test('the ring, the streak and the stats read the same entries', () async {
      final int book = await addBook(totalPages: 200);
      await databaseServices.addEntry({
        'bookId': book,
        'percentageRead': 10,
        'summary': '',
        'createdAt': today.toIso8601String(),
        'pagesRead': 20,
        'durationSeconds': 900,
      });

      final TodayData data = await habitServices.getToday(now: today);
      final Map<String, int> week = await databaseServices.getPeriodSummary(
        HabitServices.dateKey(daysAgo(6)),
        HabitServices.dateKey(today),
      );
      final Map<String, int> lifetime = await databaseServices
          .getLifetimeTotals();

      expect(data.streak.readToday, isTrue);
      expect(data.streak.current, 1);
      expect(data.week.last.state, DayState.read);
      expect(data.secondsToday, 900);
      expect(week, containsPair('days', 1));
      expect(week, containsPair('seconds', 900));
      expect(week, containsPair('pages', 20));
      expect(lifetime, containsPair('pages', 20));
      expect(data.pagesLeft, 180);
    });
  });

  group('corrections', () {
    Future<int> bookOnPage42() async {
      final int book = await addBook(totalPages: 320);
      await databaseServices.addEntry({
        'bookId': book,
        'summary': '',
        'createdAt': daysAgo(1).toIso8601String(),
        'pagesRead': 24,
        'durationSeconds': 1200,
      });
      await databaseServices.addEntry({
        'bookId': book,
        'summary': '',
        'createdAt': today.toIso8601String(),
        'pagesRead': 18,
        'durationSeconds': 900,
      });
      return book;
    }

    test('logging moves the bookmark', () async {
      final int book = await bookOnPage42();

      expect((await databaseServices.getBook(book))?.currentPage, 42);
      expect(await databaseServices.getPercentageRead(book), 13);
    });

    test('editing a session moves the bookmark by the difference', () async {
      final int book = await bookOnPage42();
      final entry = (await databaseServices.getEntries(book)).first;

      await databaseServices.editEntry(entry.id!, {
        'pagesRead': 28,
        'durationSeconds': 600,
      });

      expect(await databaseServices.getCurrentPage(book), 52);
      expect(
        await databaseServices.getSecondsOnDate(HabitServices.dateKey(today)),
        600,
      );
    });

    test('deleting a session moves the bookmark back', () async {
      final int book = await bookOnPage42();
      final entry = (await databaseServices.getEntries(book)).first;

      await databaseServices.deleteEntry(entry.id!);

      expect(await databaseServices.getCurrentPage(book), 24);
      expect((await databaseServices.getBook(book))?.status, 'reading');
    });

    test('the bookmark can be set directly', () async {
      final int book = await bookOnPage42();

      await databaseServices.setBookmark(book, 160);
      expect(await databaseServices.getPercentageRead(book), 50);
      expect((await habitServices.getToday(now: today)).pagesLeft, 160);

      // The last page finishes the book; it cannot go past the end.
      await databaseServices.setBookmark(book, 999);
      expect(await databaseServices.getCurrentPage(book), 320);
      expect((await databaseServices.getBook(book))?.status, 'read');
    });

    test('today lists the other books in progress', () async {
      final int first = await bookOnPage42();
      final Database db = await databaseServices.database;
      final int second = await db.insert('books', {
        'title': 'Hyperion',
        'author': 'Dan Simmons',
        'totalPages': 480,
        'status': 'reading',
      });
      await readOn(second, daysAgo(3));

      final TodayData data = await habitServices.getToday(now: today);

      expect(data.book?.id, first);
      expect(data.otherBooks.map((book) => book.title), ['Hyperion']);
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

  group('streak widget', () {
    test('shows the last seven days, oldest first', () async {
      final int book = await addBook();
      // Seven days earn a freeze, one missed day spends it, then two read.
      for (int day = 10; day >= 4; day--) {
        await readOn(book, daysAgo(day));
      }
      await readOn(book, daysAgo(2));
      await readOn(book, daysAgo(1));

      final TodayData data = await habitServices.getToday(now: today);

      expect(HomeWidgetService.weekCode(data.week), 'rrrsrro');
      expect(data.week.last.date.day, today.day);
      expect(
        HomeWidgetService.streakStatus(data.streak),
        'Read today to keep it',
      );
    });

    test('marks a missed day and offers the repair', () async {
      final int book = await addBook();
      await readOn(book, daysAgo(3));
      await readOn(book, daysAgo(2));

      final TodayData data = await habitServices.getToday(now: today);

      expect(HomeWidgetService.weekCode(data.week), 'mmmrrmo');
      expect(HomeWidgetService.streakStatus(data.streak), 'Repair today');
    });
  });

  group('backup', () {
    Future<int> seed() async {
      final int book = await addBook();
      await databaseServices.addEntry({
        'bookId': book,
        'percentageRead': 10,
        'summary': 'Fear is the mind-killer.',
        'createdAt': today.toIso8601String(),
        'pagesRead': 30,
        'durationSeconds': 1500,
        'hook': 'Who betrayed the Atreides?',
      });
      await databaseServices.setSetting('dailyGoalMinutes', '20');
      await databaseServices.setSetting('planCue', 'finish dinner');
      await databaseServices.setSetting('sessionBookId', '$book');
      await databaseServices.addStreakEvent('2026-03-10', 'freeze');
      await databaseServices.addHabitCheck(17, today.toIso8601String());
      return book;
    }

    test('a backup restores everything on an empty device', () async {
      final int book = await seed();
      final String json = await BackupServices.instance.exportJson(now: today);

      // A fresh install.
      final Database db = await databaseServices.database;
      for (final String table in <String>[
        'entries',
        'books',
        'settings',
        'streak_events',
        'habit_checks',
      ]) {
        await db.delete(table);
      }
      expect(await databaseServices.getBooks(), isEmpty);

      final BackupSummary summary = await BackupServices.instance.importJson(
        json,
      );

      expect(summary.books, 1);
      expect(summary.entries, 1);
      expect((await databaseServices.getBooks()).single.title, 'Dune');
      final entry = (await databaseServices.getEntries(book)).single;
      expect(entry.summary, 'Fear is the mind-killer.');
      expect(entry.hook, 'Who betrayed the Atreides?');
      expect(entry.durationSeconds, 1500);
      expect(await habitServices.getGoalMinutes(), 20);
      expect(await databaseServices.getSetting('planCue'), 'finish dinner');
      expect(await databaseServices.getStreakEvents(), {
        '2026-03-10': 'freeze',
      });
      expect(await databaseServices.getHabitChecks(), hasLength(1));
      // A half-finished session on the old device is not carried over.
      expect(await databaseServices.getSetting('sessionBookId'), isNull);
    });

    test('restoring replaces what is on the device', () async {
      await seed();
      final String json = await BackupServices.instance.exportJson(now: today);
      final Database db = await databaseServices.database;
      await db.insert('books', {
        'title': 'Added after the backup',
        'author': 'Someone',
        'status': 'to-read',
      });

      await BackupServices.instance.importJson(json);

      expect((await databaseServices.getBooks()).single.title, 'Dune');
    });

    test(
      'a file that is not a backup is refused and changes nothing',
      () async {
        await seed();

        for (final String bad in <String>[
          'not json at all',
          '{"app": "something-else", "books": [], "entries": []}',
          '{"app": "lumina", "formatVersion": 99, "books": [], "entries": []}',
        ]) {
          await expectLater(
            BackupServices.instance.importJson(bad),
            throwsFormatException,
          );
        }

        expect(await databaseServices.getBooks(), hasLength(1));
      },
    );

    test('a backup with a broken row restores nothing', () async {
      await seed();
      const String broken =
          '{"app": "lumina", "formatVersion": 1, "books": [], '
          '"entries": [{"bookId": 999, "percentageRead": 5}]}';

      await expectLater(
        BackupServices.instance.importJson(broken),
        throwsA(anything),
      );

      // The entry points at a book that does not exist, so the whole restore
      // is rolled back.
      expect((await databaseServices.getBooks()).single.title, 'Dune');
    });

    test('the file is named by date', () {
      expect(
        BackupServices.instance.fileName(now: DateTime(2026, 3, 5)),
        'lumina-backup-2026-03-05.json',
      );
    });
  });

  group('research', () {
    test('every why chip in the app points at a real entry', () {
      final RegExp usage = RegExp(r"researchKey: '(\w+)'");
      final Set<String> usedKeys = <String>{};
      for (final FileSystemEntity file in Directory(
        'lib',
      ).listSync(recursive: true)) {
        if (file is File && file.path.endsWith('.dart')) {
          usedKeys.addAll(
            usage.allMatches(file.readAsStringSync()).map((m) => m.group(1)!),
          );
        }
      }

      expect(usedKeys, isNotEmpty);
      final Set<String> known = researchEntries.map((e) => e.key).toSet();
      expect(usedKeys.difference(known), isEmpty);
    });

    test('every entry cites a source or says it has none', () {
      for (final Research research in researchEntries) {
        expect(research.finding, isNotEmpty);
        expect(
          research.citation.isNotEmpty || research.note != null,
          isTrue,
          reason: research.key,
        );
      }
      expect(
        researchEntries.map((e) => e.key).toSet(),
        hasLength(researchEntries.length),
      );
    });
  });
}
