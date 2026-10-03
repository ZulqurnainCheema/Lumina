import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina/main.dart';
import 'package:lumina/services/database_services.dart';
import 'package:lumina/services/habit_services.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
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

    expect(
      find.text('After I finish dinner, I read in the armchair.'),
      findsOneWidget,
    );
    await screenshot(tester, '02-plan-on-home');
  });

  testWidgets('today card shows the streak, the hook and the time left', (
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
    expect(
      find.text('You wanted to know: Does Jessica survive the desert?'),
      findsOneWidget,
    );
    expect(find.textContaining('pages left'), findsOneWidget);
    expect(find.byIcon(Icons.ac_unit_rounded), findsOneWidget);
    await screenshot(tester, '03-today-card');
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
    await screenshot(tester, '04-reading-session');

    await tester.tap(find.text('Done reading'));
    await settle(tester);
    expect(find.textContaining('You read for'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Percentage Read'),
      '3',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'One thing worth keeping'),
      'Fear is the mind-killer.',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'What do you want to find out next?'),
      'Who betrayed the Atreides?',
    );
    await tester.ensureVisible(find.text('4'));
    await tester.tap(find.text('4'));
    await screenshot(tester, '05-session-wrap-up');

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(find.text('7 days in a row'), findsOneWidget);
    await screenshot(tester, '06-streak-milestone');

    await tester.tap(find.text('Keep going'));
    await settle(tester);

    expect(find.text('7 day streak'), findsOneWidget);
    expect(
      find.text('You wanted to know: Who betrayed the Atreides?'),
      findsOneWidget,
    );
    final entries = await databaseServices.getEntries(book);
    expect(entries.first.durationSeconds, greaterThan(0));
    expect(entries.first.absorption, 4);
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
    await screenshot(tester, '07-streak-repair');
  });

  testWidgets('coming back after a gap is celebrated', (tester) async {
    await skipOpenPrompts();
    final int book = await addBook();
    await readOn(book, daysAgo(5));

    await startApp(tester);
    await tester.tap(find.byTooltip('start reading'));
    await settle(tester);
    await tester.tap(find.text('Done reading'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Percentage Read'),
      '2',
    );
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(find.text('You came back.'), findsOneWidget);
    await screenshot(tester, '08-comeback');

    await tester.tap(find.text('Keep going'));
    await settle(tester);
    expect(find.text('1 day streak'), findsOneWidget);
  });

  testWidgets('statistics opens with no entries', (tester) async {
    await skipOpenPrompts();

    await startApp(tester);
    await tester.tap(find.byIcon(Symbols.bar_chart));
    await settle(tester);

    expect(find.textContaining('No reading progress yet.'), findsOneWidget);
    await screenshot(tester, '09-statistics-empty');
    await goHome(tester);
  });

  testWidgets('statistics shows streaks, reading time and habit strength', (
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
    await tester.tap(find.byIcon(Symbols.bar_chart));
    await settle(tester);

    expect(find.text('Longest Streak'), findsOneWidget);
    await screenshot(tester, '10-statistics');

    await tester.scrollUntilVisible(
      find.text('Habit Strength'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await screenshot(tester, '11-statistics-habit-strength');
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
    expect(find.text('How automatic is it?'), findsOneWidget);
    await screenshot(tester, '12-weekly-review');

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
    await tester.tap(find.byIcon(Symbols.settings));
    await settle(tester);
    await tester.tap(find.text('20 min'));
    await settle(tester);

    expect(await databaseServices.getSetting('dailyGoalMinutes'), '20');
    await screenshot(tester, '13-settings');
    await goHome(tester);
    expect(find.text('0 of 20 min today'), findsOneWidget);
  });

  testWidgets('a book untouched for a week can be dropped', (tester) async {
    await skipOpenPrompts();
    final int book = await addBook();
    await readOn(book, daysAgo(10));

    await startApp(tester);

    expect(find.text('Still into Dune?'), findsOneWidget);
    await screenshot(tester, '14-stale-book');

    await tester.tap(find.text('Drop it'));
    await settle(tester);

    expect((await databaseServices.getBook(book))?.abandonedAt, isNotNull);
    expect(find.text('No books currently being read.'), findsOneWidget);
  });

  testWidgets('yesterday\'s note comes back as a recall prompt', (
    tester,
  ) async {
    await skipOpenPrompts();
    final int book = await addBook();
    await readOn(book, daysAgo(1), summary: 'Fear is the mind-killer.');

    await startApp(tester);

    expect(find.text('What do you remember?'), findsOneWidget);
    await screenshot(tester, '15-recall-prompt');

    await tester.tap(find.text('Show my note'));
    await settle(tester);

    expect(find.text('Fear is the mind-killer.'), findsOneWidget);
    await screenshot(tester, '16-recall-answer');

    await tester.tap(find.text('Got it'));
    await settle(tester);
  });
}
