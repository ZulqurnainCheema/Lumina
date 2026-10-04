import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lumina/models/books.dart';
import 'package:lumina/services/database_services.dart';
import 'package:lumina/theme.dart';
import 'package:lumina/widgets/book_cover.dart';
import 'package:lumina/widgets/empty_state.dart';
import 'package:lumina/widgets/route_refresh.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

class Library extends StatefulWidget {
  const Library({super.key});

  @override
  State<Library> createState() => _LibraryState();
}

class _LibraryState extends State<Library> with RouteRefresh<Library> {
  final DatabaseServices _databaseServices = DatabaseServices.instance;
  late Future<List<Books>> _booksFuture;

  @override
  String get routePath => '/library';

  @override
  void onRouteShown() {
    _refreshBooks();
  }

  @override
  void initState() {
    super.initState();
    _booksFuture = _databaseServices.getBooks();
  }

  void _refreshBooks() {
    setState(() {
      _booksFuture = _databaseServices.getBooks();
    });
  }

  void _addBook() {
    GoRouter.of(context).push('/add-books');
  }

  Widget _buildTab({
    required bool Function(Books book) filter,
    required IconData emptyIcon,
    required String emptyMessage,
  }) {
    return FutureBuilder<List<Books>>(
      future: _booksFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<Books> books = snapshot.data!.where(filter).toList();
        if (books.isEmpty) {
          return EmptyState(
            icon: emptyIcon,
            message: emptyMessage,
            actionLabel: 'Add a book',
            onAction: _addBook,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
          itemCount: books.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: buildBookCard(
                context,
                books[index],
                onDeleted: _refreshBooks,
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'Library',
                  style: Theme.of(context).textTheme.displayLarge,
                ),
              ),
              const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: EdgeInsets.symmetric(horizontal: 8),
                tabs: [
                  Tab(text: 'Reading'),
                  Tab(text: 'Finished'),
                  Tab(text: 'Want to Read'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildTab(
                      filter: (book) =>
                          book.status == 'reading' && book.abandonedAt == null,
                      emptyIcon: Symbols.auto_stories,
                      emptyMessage:
                          'Nothing in progress. Open a book from Want to Read '
                          'and start a session.',
                    ),
                    _buildTab(
                      filter: (book) => book.status == 'read',
                      emptyIcon: Symbols.done_all,
                      emptyMessage: 'Books you finish are kept here.',
                    ),
                    _buildTab(
                      filter: (book) =>
                          book.status == 'to-read' ||
                          (book.status == 'reading' &&
                              book.abandonedAt != null),
                      emptyIcon: Symbols.bookmark_add,
                      emptyMessage: 'Add the books you want to read next.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addBook,
          icon: const Icon(Icons.add),
          label: const Text('Add book'),
        ),
      ),
    );
  }
}

Widget buildBookCard(
  BuildContext context,
  Books book, {
  required VoidCallback onDeleted,
}) {
  final DatabaseServices databaseServices = DatabaseServices.instance;
  final TextTheme textTheme = Theme.of(context).textTheme;

  return InkWell(
    borderRadius: BorderRadius.circular(LuminaTheme.radiusCard),
    onTap: () {
      GoRouter.of(context).push('/book-progress/${book.id}');
    },
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 4, 16),
      decoration: LuminaDecorations.card,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookCover(coverUrl: book.coverUrl),
          const SizedBox(width: 14),
          Expanded(
            child: FutureBuilder<int>(
              future: databaseServices.getPercentageRead(book.id),
              builder: (context, snapshot) {
                final int percentage = snapshot.data ?? 0;
                final int pagesLeft =
                    (book.totalPages * (100 - percentage) / 100).ceil();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(book.author, style: textTheme.bodySmall),
                    const SizedBox(height: 12),
                    LuminaWidgets.progressBar(percentage / 100),
                    const SizedBox(height: 6),
                    Text(
                      book.abandonedAt != null
                          ? 'Paused at $percentage%'
                          : book.totalPages > 0 && percentage < 100
                          ? '$percentage% · $pagesLeft pages left'
                          : '$percentage% read',
                      style: textTheme.bodySmall,
                    ),
                  ],
                );
              },
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Symbols.more_vert),
            iconColor: LuminaColors.textTertiary,
            onSelected: (String value) async {
              if (value != 'delete') {
                return;
              }
              try {
                await databaseServices.deleteBook(book.id);
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
