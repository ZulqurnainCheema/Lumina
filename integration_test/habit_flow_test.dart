import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina/main.dart';
import 'package:lumina/services/database_services.dart';
import 'package:lumina/services/habit_services.dart';
import 'package:lumina/theme.dart';
import 'package:lumina/widgets/streak_card.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Every test saves one or more screenshots here; docs/testing.md shows them.
const String screenshotDirectory = String.fromEnvironment(
  'SHOT_DIR',
  defaultValue: 'docs/screenshots',
);

final DatabaseServices databaseServices = DatabaseServices.instance;
final GlobalKey screenshotKey = GlobalKey();

DateTime daysAgo(int days) {
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month, now.day - days, 21);
}

Future<int> addBook({String title = 'Dune'}) async {
  final Database db = await databaseServices.database;
  return db.insert('books', {
    'title': title,
    'author': 'Frank Herbert',
    'coverUrl': '',
    'totalPages': 320,
    'status': 'reading',
    'createdAt': daysAgo(30).toIso8601String(),
  });
}

Future<void> readOn(
  int bookId,
  DateTime day, {
  String summary = '',
  String hook = '',
}) async {
  final Database db = await databaseServices.database;
  await db.insert('entries', {
    'bookId': bookId,
    'percentageRead': 4,
    'summary': summary,
    'createdAt': day.toIso8601String(),
    'pagesRead': 13,
    'durationSeconds': 1500,
    'hook': hook,
  });
}

// Skips the first-run plan screen and the Monday review offer.
Future<void> skipOpenPrompts() async {
  final String today = HabitServices.dateKey(DateTime.now());
  await databaseServices.setSetting('planPrompted', today);
  await databaseServices.setSetting('reviewOffered', today);
}

Future<void> settle(WidgetTester tester) async {
  for (int round = 0; round < 4; round++) {
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
  }
}

Future<void> startApp(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(412, 892));
  await tester.pumpWidget(
    RepaintBoundary(
      key: screenshotKey,
      child: MyApp(key: UniqueKey()),
    ),
  );
  await settle(tester);
}

GoRouter router(WidgetTester tester) {
  return GoRouter.of(tester.element(find.byType(Scaffold).last));
}

Future<void> goHome(WidgetTester tester) async {
  router(tester).go('/');
  await settle(tester);
}

Future<void> screenshot(WidgetTester tester, String name) async {
  await settle(tester);
  final RenderRepaintBoundary boundary =
      screenshotKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
  final ui.Image image = await boundary.toImage(pixelRatio: 2);
  final ByteData? bytes = await image.toByteData(
    format: ui.ImageByteFormat.png,
  );
  final File file = File('$screenshotDirectory/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Fonts must come from the app bundle, as on a first launch with no network.
  GoogleFonts.config.allowRuntimeFetching = false;
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

  testWidgets('first run asks for a reading plan', (tester) async {
    await startApp(tester);

    expect(find.text('When will you read?'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'After I...'),
      'finish dinner',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'I read in...'),
      'the armchair',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'If...'),
      'I pick up my phone',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Then I...'),
      'put it on the desk and open the book',
    );
    await screenshot(tester, '01-reading-plan');

    await tester.ensureVisible(find.text('Save plan'));
    await tester.tap(find.text('Save plan'));
    await settle(tester);

    expect(find.text('Add your first book'), findsOneWidget);
    await screenshot(tester, '02-today-empty');
    await tester.scrollUntilVisible(
      find.text('After I finish dinner, I read in the armchair.'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
  });

  testWidgets('today shows the streak, the open question and the time left', (
    tester,
  ) async {
    await skipOpenPrompts();
    final int book = await addBook();
    for (int day = 9; day >= 1; day--) {
      await readOn(
        book,
        daysAgo(day),
        hook: day == 1 ? 'Does Jessica survive the desert?' : '',
      );
    }

    await startApp(tester);

    expect(find.text('9 day streak'), findsOneWidget);
    expect(find.text('One page keeps the streak.'), findsOneWidget);
    expect(find.text('1 freeze banked'), findsOneWidget);
    // Nine read days fill the week strip; today is still open.
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(6));
    expect(find.text('Does Jessica survive the desert?'), findsOneWidget);
    expect(find.textContaining('pages left'), findsOneWidget);
    // One main action on the screen.
    expect(find.byType(ElevatedButton), findsOneWidget);
    await screenshot(tester, '03-today');
  });

  testWidgets('the streak rules and their source are one tap away', (
    tester,
  ) async {
    await skipOpenPrompts();
    final int book = await addBook();
    await readOn(book, daysAgo(1));

    await startApp(tester);
    await tester.scrollUntilVisible(
      find.text('How it works'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('How it works'));
    await settle(tester);

    expect(find.text('How your streak works'), findsOneWidget);
    expect(find.textContaining('earns a freeze, up to 2'), findsOneWidget);
    await screenshot(tester, '04-streak-rules');

    await tester.tap(find.text('Why?'));
    await settle(tester);
    expect(find.text('A streak you can repair'), findsOneWidget);
    expect(find.textContaining('Silverman & Barasch (2023)'), findsOneWidget);
    await screenshot(tester, '04-why-sheet');

    await tester.tap(find.text('See all the science'));
    await settle(tester);

    expect(find.text('The science'), findsOneWidget);
    await screenshot(tester, '05-science');

    await tester.scrollUntilVisible(
      find.text('No points, coins or prizes'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('No points, coins or prizes'));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.textContaining('Deci, Koestner & Ryan (1999)'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await screenshot(tester, '06-science-left-out');
    await goHome(tester);
  });

  testWidgets('a reading session is timed, logged and hits a milestone', (
    tester,
  ) async {
    await skipOpenPrompts();
    final int book = await addBook();
    for (int day = 6; day >= 1; day--) {
      await readOn(book, daysAgo(day));
    }

    await startApp(tester);
    await tester.tap(find.text('Continue reading'));
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);

    expect(find.text('Done reading'), findsOneWidget);
    await screenshot(tester, '07-reading-session');

    await tester.tap(find.text('Done reading'));
    await settle(tester);
    expect(find.textContaining('You read for'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Percent you are at now'),
      '27',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'One line, from memory'),
      'Fear is the mind-killer.',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Your open question'),
      'Who betrayed the Atreides?',
    );
    expect(find.textContaining('From the timer.'), findsOneWidget);
    await screenshot(tester, '08-session-wrap-up');

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(find.text('7 days in a row'), findsOneWidget);
    await screenshot(tester, '09-streak-milestone');

    await tester.tap(find.text('Keep going'));
    await settle(tester);

    expect(find.text('7 day streak'), findsOneWidget);
    expect(find.text('Who betrayed the Atreides?'), findsOneWidget);
    final entries = await databaseServices.getEntries(book);
    expect(entries.first.durationSeconds, greaterThan(0));
    expect(await databaseServices.getSetting('sessionBookId'), '');
  });

  testWidgets('a missed day offers a streak repair', (tester) async {
    await skipOpenPrompts();
    final int book = await addBook();
    await readOn(book, daysAgo(4));
    await readOn(book, daysAgo(3));
    await readOn(book, daysAgo(2));

    await startApp(tester);

    expect(find.text('0 day streak'), findsOneWidget);
    expect(
      find.text(
        'You missed yesterday. Read 20 minutes today and your 3 day streak comes back.',
      ),
      findsOneWidget,
    );
    await screenshot(tester, '10-streak-repair');
  });

  testWidgets('coming back after a gap is celebrated', (tester) async {
    await skipOpenPrompts();
    final int book = await addBook();
    await readOn(book, daysAgo(5));

    await startApp(tester);
    await tester.tap(find.text('Continue reading'));
    await settle(tester);
    await tester.tap(find.text('Done reading'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Percent you are at now'),
      '6',
    );
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(find.text('You came back.'), findsOneWidget);
    await screenshot(tester, '11-comeback');

    await tester.tap(find.text('Keep going'));
    await settle(tester);
    expect(find.text('1 day streak'), findsOneWidget);
  });

  testWidgets('library sorts books by shelf and opens a book', (tester) async {
    await skipOpenPrompts();
    final int book = await addBook();
    await readOn(
      book,
      daysAgo(1),
      summary: 'Fear is the mind-killer.',
      hook: 'Who betrayed the Atreides?',
    );
    await readOn(book, daysAgo(0));
    final Database db = await databaseServices.database;
    await db.insert('books', {
      'title': 'The Left Hand of Darkness',
      'author': 'Ursula K. Le Guin',
      'coverUrl': '',
      'totalPages': 304,
      'status': 'to-read',
    });
    await databaseServices.setSetting(
      'recallShown',
      HabitServices.dateKey(DateTime.now()),
    );

    await startApp(tester);
    await tester.tap(find.text('Library'));
    await settle(tester);

    expect(find.text('Dune'), findsWidgets);
    expect(find.text('The Left Hand of Darkness'), findsNothing);
    await screenshot(tester, '12-library');

    await tester.tap(find.text('Dune').last);
    await settle(tester);

    expect(find.text('Read now'), findsOneWidget);
    expect(find.text('Fear is the mind-killer.'), findsOneWidget);
    expect(find.text('Wanted to know: Who betrayed the Atreides?'), findsOne);
    await screenshot(tester, '13-book-detail');
    await goHome(tester);
  });

  testWidgets('stats explains itself with no entries', (tester) async {
    await skipOpenPrompts();

    await startApp(tester);
    await tester.tap(find.text('Stats'));
    await settle(tester);

    expect(find.textContaining('No reading yet.'), findsOneWidget);
    await screenshot(tester, '14-stats-empty');
    await goHome(tester);
  });

  testWidgets('stats shows the week, all time and habit strength', (
    tester,
  ) async {
    await skipOpenPrompts();
    final int book = await addBook();
    for (int day = 9; day >= 0; day--) {
      await readOn(book, daysAgo(day));
    }
    await databaseServices.addHabitCheck(11, daysAgo(28).toIso8601String());
    await databaseServices.addHabitCheck(16, daysAgo(14).toIso8601String());
    await databaseServices.addHabitCheck(21, daysAgo(0).toIso8601String());

    await startApp(tester);
    await tester.tap(find.text('Stats'));
    await settle(tester);

    expect(find.text('7 of 7 days'), findsOneWidget);
    expect(find.text('Longest streak'), findsOneWidget);
    await screenshot(tester, '15-stats');

    await tester.scrollUntilVisible(
      find.textContaining('28 means it happens without thinking'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await screenshot(tester, '16-stats-habit-strength');
    await goHome(tester);
  });

  testWidgets('weekly review records how automatic reading feels', (
    tester,
  ) async {
    await skipOpenPrompts();
    final int book = await addBook();
    for (int day = 6; day >= 0; day--) {
      await readOn(book, daysAgo(day));
    }

    await startApp(tester);
    router(tester).push('/review');
    await settle(tester);

    expect(find.text('You read on 7 of 7 days'), findsOneWidget);
    expect(find.text('HOW AUTOMATIC IS IT?'), findsOneWidget);
    await screenshot(tester, '17-weekly-review');

    await tester.scrollUntilVisible(
      find.text('Start the new week'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Start the new week'));
    await settle(tester);

    expect(await databaseServices.getHabitChecks(), hasLength(1));
  });

  testWidgets('settings changes the daily goal', (tester) async {
    await skipOpenPrompts();

    await startApp(tester);
    await tester.tap(find.byTooltip('Settings'));
    await settle(tester);
    await tester.tap(find.text('20 min'));
    await settle(tester);

    expect(await databaseServices.getSetting('dailyGoalMinutes'), '20');
    await screenshot(tester, '18-settings');
    await goHome(tester);
    expect(find.text('of 20 min today'), findsOneWidget);
  });

  testWidgets('a book untouched for a week can be dropped', (tester) async {
    await skipOpenPrompts();
    final int book = await addBook();
    await readOn(book, daysAgo(10));

    await startApp(tester);

    expect(find.text('Still into Dune?'), findsOneWidget);
    await screenshot(tester, '19-stale-book');

    await tester.tap(find.text('Drop it'));
    await settle(tester);

    expect((await databaseServices.getBook(book))?.abandonedAt, isNotNull);
    await tester.tap(find.text('Library'));
    await settle(tester);
    expect(find.textContaining('Nothing in progress.'), findsOneWidget);
    await goHome(tester);
  });

  testWidgets('yesterday\'s note comes back as a recall prompt', (
    tester,
  ) async {
    await skipOpenPrompts();
    final int book = await addBook();
    await readOn(book, daysAgo(1), summary: 'Fear is the mind-killer.');

    await startApp(tester);

    // A card on Today, not a pop-up.
    await tester.scrollUntilVisible(
      find.text('Show my note'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('What do you remember?'), findsOneWidget);
    await screenshot(tester, '20-recall-prompt');

    await tester.tap(find.text('Show my note'));
    await settle(tester);

    expect(find.text('Fear is the mind-killer.'), findsOneWidget);
    await screenshot(tester, '21-recall-answer');

    await tester.tap(find.text('Got it'));
    await settle(tester);

    // Once answered, it is gone for the day.
    expect(find.text('What do you remember?'), findsNothing);
  });

  testWidgets('a timer left running can be corrected before saving', (
    tester,
  ) async {
    await skipOpenPrompts();
    final int book = await addBook();
    await readOn(book, daysAgo(1));

    await startApp(tester);
    // As if the timer had been left running for four hours.
    router(tester).push('/add-book-progress/$book', extra: 4 * 60 * 60);
    await settle(tester);

    expect(find.textContaining('The timer ran for 4h 0m'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Minutes read'),
      '30',
    );
    await screenshot(tester, '26-long-timer');
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(
      await databaseServices.getSecondsOnDate(
        HabitServices.dateKey(DateTime.now()),
      ),
      30 * 60,
    );
    expect(find.text('30'), findsOneWidget);
  });

  testWidgets('a session and the bookmark can be corrected', (tester) async {
    await skipOpenPrompts();
    final int book = await addBook();
    await databaseServices.addEntry({
      'bookId': book,
      'summary': 'Fear is the mind-killer.',
      'createdAt': DateTime.now().toIso8601String(),
      'pagesRead': 13,
      'durationSeconds': 1500,
    });

    await startApp(tester);
    await tester.tap(find.text('Library'));
    await settle(tester);
    await tester.tap(find.text('Dune').last);
    await settle(tester);
    expect(find.text('25m · 13 pages'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await settle(tester);
    await tester.tap(find.text('Edit'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Pages read in this session'),
      '20',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Minutes read'),
      '40',
    );
    await screenshot(tester, '27-edit-session');
    await tester.tap(find.text('Save changes'));
    await settle(tester);

    expect(find.text('40m · 20 pages'), findsOneWidget);
    expect(await databaseServices.getCurrentPage(book), 20);

    await tester.tap(find.byTooltip('Edit book'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Page you are on'),
      '160',
    );
    await screenshot(tester, '28-edit-book');
    await tester.tap(find.text('Save changes'));
    await settle(tester);

    expect(await databaseServices.getCurrentPage(book), 160);
    expect(find.text('50%'), findsOneWidget);
    await goHome(tester);
    expect(find.textContaining('160 pages left'), findsOneWidget);
  });

  testWidgets('today lists every book in progress', (tester) async {
    await skipOpenPrompts();
    final int book = await addBook();
    await readOn(book, daysAgo(1));
    final Database db = await databaseServices.database;
    final int second = await db.insert('books', {
      'title': 'Hyperion',
      'author': 'Dan Simmons',
      'coverUrl': '',
      'totalPages': 480,
      'status': 'reading',
    });
    await readOn(second, daysAgo(3));

    await startApp(tester);
    await tester.scrollUntilVisible(
      find.text('ALSO READING'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Hyperion'), findsWidgets);
    await screenshot(tester, '29-also-reading');

    await tester.tap(find.text('Read'));
    await settle(tester);
    expect(find.text('Done reading'), findsOneWidget);
    // Leave the session without saving.
    await tester.tap(find.byTooltip('discard session'));
    await settle(tester);
  });

  testWidgets('logging without the timer can still fill the ring', (
    tester,
  ) async {
    await skipOpenPrompts();
    final int book = await addBook();
    await readOn(book, daysAgo(1));

    Future<void> logManually({
      required String page,
      required String minutes,
    }) async {
      await tester.tap(find.text('Library'));
      await settle(tester);
      await tester.tap(find.text('Dune').last);
      await settle(tester);
      await tester.tap(find.text('Log manually'));
      await settle(tester);
      await tester.tap(find.text('Pages'));
      await settle(tester);
      expect(find.textContaining('You were on page'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Page you are on now'),
        page,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Minutes read'),
        minutes,
      );
      if (minutes.isNotEmpty) {
        await screenshot(tester, '23-log-current-page');
      }
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await settle(tester);
      await goHome(tester);
    }

    await startApp(tester);

    // No minutes typed: the streak counts, and the ring says why it is empty.
    // The seeded session left the bookmark on page 13.
    await logManually(page: '24', minutes: '');
    expect(find.text('2 day streak'), findsOneWidget);
    expect(find.text('Read today'), findsOneWidget);
    expect(find.text('no time logged'), findsOneWidget);
    await screenshot(tester, '25-read-no-time');

    // Minutes typed: they fill the ring. Page 42 means 18 more pages, not 42.
    await logManually(page: '42', minutes: '12');
    expect(find.text('12'), findsOneWidget);
    expect(find.text('of 10 min today'), findsOneWidget);
    expect(await databaseServices.getCurrentPage(book), 42);
    expect(await databaseServices.getPagesRead(book), 42);
    expect(find.textContaining('278 pages left'), findsOneWidget);
    await screenshot(tester, '24-manual-minutes');
  });

  testWidgets('the streak card draws on its own for the home-screen widget', (
    tester,
  ) async {
    final int book = await addBook();
    // Seven days earn a freeze, a missed day spends it, then two more days.
    for (int day = 10; day >= 4; day--) {
      await readOn(book, daysAgo(day));
    }
    await readOn(book, daysAgo(2));
    await readOn(book, daysAgo(1));
    final TodayData today = await HabitServices.instance.getToday();

    // The same bare tree home_widget renders: no app, no Material ancestor.
    await tester.binding.setSurfaceSize(const Size(372, 236));
    await tester.pumpWidget(
      RepaintBoundary(
        key: screenshotKey,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Theme(
                data: LuminaTheme.dark(),
                child: SizedBox(
                  width: 372,
                  child: StreakCard(today: today, showWhy: false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await settle(tester);

    expect(find.text('9 day streak'), findsOneWidget);
    expect(find.text('One page keeps the streak.'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(5));
    expect(find.byIcon(Icons.ac_unit_rounded), findsOneWidget);
    expect(find.text('Why?'), findsNothing);
    await screenshot(tester, '22-streak-widget');
  });
}
