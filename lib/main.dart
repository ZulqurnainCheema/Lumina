import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:reading_assist/screens/add_books.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'theme.dart';
import 'package:go_router/go_router.dart';
import 'services/database_services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Lumina',
      debugShowCheckedModeBanner: false,
      theme: LuminaTheme.dark(),
      routerConfig: _router,
    );
  }
}

final GoRouter _router = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const MyHomePage(title: 'Lumina');
      },
      routes: <RouteBase>[
        GoRoute(
          path: 'add-books',
          builder: (BuildContext context, GoRouterState state) {
            return const Addbooks();
          },
        ),
      ],
    ),
  ],
);

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final DatabaseServices _databaseServices = DatabaseServices.instance;
  final List<Map<String, dynamic>> _books = [];
  @override
  void initState() {
    super.initState();
    fetchBooks();
  }

  void fetchBooks() async {
    final books = await _databaseServices.getBooks();
    debugPrint('Books: $books');
    setState(() {
      _books.clear();
      _books.addAll(books);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 80,
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16),
          iconTheme: IconThemeData(
            color: Theme.of(context).colorScheme.primary,
            size: 30,
          ),
          leading: Icon(
            Symbols.menu_book,
            color: Theme.of(context).colorScheme.primary,
          ),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
          actions: [
            IconButton(
              onPressed: () {},
              icon: Icon(Symbols.search),
              color: Theme.of(context).colorScheme.primary,
            ),
            IconButton(
              icon: Icon(Symbols.person_4_sharp),
              color: Theme.of(context).colorScheme.primary,
              onPressed: () {},
            ),
          ],
          shape: Border(
            bottom: BorderSide(color: LuminaColors.borderSubtle, width: 0.5),
          ),
        ),
        body: Container(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Text(
                "My Library",
                style: Theme.of(context).textTheme.displayLarge,
              ),
              Text(
                'You have 4 books in your library.',

                style: Theme.of(context).textTheme.bodySmall,
              ),
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                dividerColor: LuminaColors.neutral,
                dividerHeight: 0.2,
                unselectedLabelStyle: Theme.of(context).textTheme.bodySmall,
                tabs: [
                  Tab(text: "Reading"),
                  Tab(text: "Finished"),
                  Tab(text: "Want to Read"),
                ],
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          onPressed: () => GoRouter.of(context).push('/add-books'),
          tooltip: 'add book',
          child: const Icon(Icons.add, size: 40),
        ),
        bottomNavigationBar: BottomAppBar(
          color: Theme.of(context).colorScheme.inversePrimary,
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () {},
                  icon: Icon(Symbols.home),
                  focusColor: Theme.of(context).colorScheme.primary,
                  color: LuminaColors.neutral,
                ),
                IconButton(
                  onPressed: () {},
                  icon: Icon(Symbols.auto_stories),
                  focusColor: Theme.of(context).colorScheme.primary,
                  color: LuminaColors.neutral,
                ),
                IconButton(
                  onPressed: () {},
                  icon: Icon(Symbols.bar_chart),
                  focusColor: Theme.of(context).colorScheme.primary,
                  color: LuminaColors.neutral,
                ),
                IconButton(
                  onPressed: () {},
                  icon: Icon(Symbols.settings),
                  focusColor: Theme.of(context).colorScheme.primary,
                  color: LuminaColors.neutral,
                ),
              ],
            ),
          ),
        ), // This trailing comma makes auto-formatting nicer for build methods.
      ),
    );
  }
}

Widget buildBookCard(
  BuildContext context,
  String title,
  String author,
  double progress,
) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(color: LuminaColors.accent),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: LuminaColors.accent.withAlpha(20),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Book Title',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
          ],
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Text('Author Name', style: Theme.of(context).textTheme.labelMedium),
            Text(author, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
        SizedBox(height: 12),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: LuminaColors.neutral.withAlpha(50),
          color: LuminaColors.accent,
        ),
      ],
    ),
  );
}
