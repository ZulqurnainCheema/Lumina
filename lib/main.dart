import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:lumina/models/books.dart';
import 'package:lumina/screens/add_book_progress.dart';
import 'package:lumina/screens/add_books.dart';
import 'package:lumina/screens/book_progress.dart';
import 'package:lumina/screens/summary_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'theme.dart';
import 'package:go_router/go_router.dart';
import 'services/database_services.dart';
import 'screens/statistics.dart';
import 'package:lumina/notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else if (defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  Notifications notifications = Notifications();
  await notifications.init();
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
        GoRoute(
          path: 'book-progress/:id',
          builder: (BuildContext context, GoRouterState state) {
            final id = state.pathParameters['id']!;
            return BookProgress(id: int.parse(id));
          },
        ),
        GoRoute(
          path: 'add-book-progress/:id',
          builder: (BuildContext context, GoRouterState state) {
            final id = state.pathParameters['id']!;
            return AddBookProgress(id: int.parse(id));
          },
        ),
        GoRoute(
          path: 'summary/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return SummaryPage(id: int.parse(id));
          },
        ),
        GoRoute(
          path: 'statistics',
          builder: (context, state) {
            return const StatisticsScreen();
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
  late Future<List<Books>> _booksFuture;

  void _onRouteChange() {
    final location = _router.routerDelegate.currentConfiguration.uri.toString();
    if (location == '/' && mounted) {
      _refreshBooks();
    }
  }

  @override
  void initState() {
    super.initState();
    _booksFuture = _databaseServices.getBooks();
    _router.routerDelegate.addListener(_onRouteChange);
  }

  @override
  void dispose() {
    _router.routerDelegate.removeListener(_onRouteChange);
    super.dispose();
  }

  void _refreshBooks() {
    setState(() {
      _booksFuture = _databaseServices.getBooks();
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
              SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    FutureBuilder<List<Books>>(
                      future: _booksFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }
                        final List<Books> books = snapshot.data ?? <Books>[];
                        if (books.isEmpty) {
                          return const Center(
                            child: Text('No books in your library yet.'),
                          );
                        }
                        final List<Books> readingBooks = books
                            .where((book) => book.status == 'reading')
                            .toList();
                        if (readingBooks.isEmpty) {
                          return const Center(
                            child: Text('No books currently being read.'),
                          );
                        }
                        return ListView.builder(
                          itemCount: readingBooks.length,
                          itemBuilder: (context, index) {
                            final Books book = readingBooks[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: buildBookCard(
                                context,
                                book.id,
                                book.title,
                                book.author,
                                book.coverUrl,
                                onDeleted: _refreshBooks,
                              ),
                            );
                          },
                        );
                      },
                    ),
                    FutureBuilder<List<Books>>(
                      future: _booksFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }
                        final List<Books> books = snapshot.data ?? <Books>[];
                        final List<Books> finishedBooks = books
                            .where((book) => book.status == 'read')
                            .toList();
                        if (finishedBooks.isEmpty) {
                          return const Center(
                            child: Text('No finished books yet.'),
                          );
                        }
                        return ListView.builder(
                          itemCount: finishedBooks.length,
                          itemBuilder: (context, index) {
                            final Books book = finishedBooks[index];

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: buildBookCard(
                                context,
                                book.id,
                                book.title,
                                book.author,
                                book.coverUrl,
                                onDeleted: _refreshBooks,
                              ),
                            );
                          },
                        );
                      },
                    ),
                    FutureBuilder<List<Books>>(
                      future: _booksFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }
                        final List<Books> books = snapshot.data ?? <Books>[];
                        final List<Books> wantToReadBooks = books
                            .where((book) => book.status == 'to-read')
                            .toList();
                        if (wantToReadBooks.isEmpty) {
                          return const Center(
                            child: Text(
                              'No books in your want-to-read list yet.',
                            ),
                          );
                        }
                        return ListView.builder(
                          itemCount: wantToReadBooks.length,
                          itemBuilder: (context, index) {
                            final Books book = wantToReadBooks[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: buildBookCard(
                                context,
                                book.id,
                                book.title,
                                book.author,
                                book.coverUrl,
                                onDeleted: _refreshBooks,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          onPressed: () async {
            final bool? added = await GoRouter.of(
              context,
            ).push<bool>('/add-books');
            if (!context.mounted || added != true) {
              return;
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) {
                return;
              }
              _refreshBooks();
            });
          },
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
                  onPressed: () {
                    GoRouter.of(context).push('/home');
                  },
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
                  onPressed: () {
                    GoRouter.of(context).push('/statistics');
                  },
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
  int id,
  String title,
  String author,
  String coverUrl, {
  required VoidCallback onDeleted,
}) {
  final DatabaseServices databaseServices = DatabaseServices.instance;
  Future<int?> getBookPercentageRead(int bookId) async {
    final int percentageRead = await databaseServices.getPercentageRead(bookId);
    return percentageRead;
  }

  return InkWell(
    onTap: () {
      GoRouter.of(context).push('/book-progress/$id');
    },
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: LuminaDecorations.card,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 104,
            decoration: LuminaDecorations.thumbnail,
            clipBehavior: Clip.antiAlias,
            child: coverUrl.isNotEmpty
                ? Image.network(
                    coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(
                          Symbols.menu_book_rounded,
                          color: LuminaColors.accent,
                        ),
                      );
                    },
                  )
                : const Center(
                    child: Icon(
                      Symbols.menu_book_rounded,
                      color: LuminaColors.accent,
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: FutureBuilder<int?>(
              future: getBookPercentageRead(id),
              builder: (context, snapshot) {
                final int percentage = snapshot.data ?? 0;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(author, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: LuminaColors.borderSubtle,
                      color: LuminaColors.accent,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$percentage% read',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                );
              },
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Symbols.more_vert),
            onSelected: (String value) async {
              if (value != 'delete') {
                return;
              }
              try {
                await databaseServices.deleteBook(id);
                onDeleted();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Book deleted.')),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to delete book.')),
                  );
                }
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'delete',
                child: Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
