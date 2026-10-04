import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lumina/models/books.dart';
import 'package:lumina/theme.dart';
import 'package:lumina/models/entries.dart';
import 'package:lumina/services/database_services.dart';
import 'package:lumina/services/habit_services.dart';
import 'package:lumina/widgets/book_cover.dart';
import 'package:lumina/widgets/empty_state.dart';
import 'package:lumina/widgets/section_header.dart';
import 'package:lumina/widgets/stat_tile.dart';
import 'package:material_symbols_icons/symbols.dart';

class BookProgress extends StatefulWidget {
  const BookProgress({super.key, required this.id});
  final int id;
  @override
  State<BookProgress> createState() => _BookProgressState();
}

class _BookProgressState extends State<BookProgress> {
  late Future<List<Entries>> _EntriesFuture;
  late Future<Books?> _bookFuture;
  late Future<int> _percentFuture;
  final _databaseServices = DatabaseServices.instance;

  @override
  void initState() {
    super.initState();
    _EntriesFuture = _databaseServices.getEntries(widget.id);
    _bookFuture = _databaseServices.getBook(widget.id);
    _percentFuture = _databaseServices.getPercentageRead(widget.id);
  }

  void _refreshEntries() {
    setState(() {
      _EntriesFuture = _databaseServices.getEntries(widget.id);
      _bookFuture = _databaseServices.getBook(widget.id);
      _percentFuture = _databaseServices.getPercentageRead(widget.id);
    });
  }

  Future<void> _deleteEntry(int entryId) async {
    try {
      await _databaseServices.deleteEntry(entryId);
      _refreshEntries();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Entry deleted.')));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to delete entry.')));
    }
  }

  Future<void> _open(String route) async {
    await GoRouter.of(context).push(route);
    if (mounted) {
      _refreshEntries();
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () => _open('/edit-book/${widget.id}'),
            tooltip: 'Edit book',
            icon: Icon(Symbols.edit),
            color: LuminaColors.textSecondary,
          ),
          IconButton(
            onPressed: () {
              GoRouter.of(context).push('/summary/${widget.id}');
            },
            tooltip: 'Your notes',
            icon: Icon(Symbols.article_rounded),
            color: LuminaColors.textSecondary,
          ),
        ],
      ),
      body: FutureBuilder<List<Entries>>(
        future: _EntriesFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data!;
          final seconds = entries.fold<int>(
            0,
            (sum, entry) => sum + (entry.durationSeconds ?? 0),
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              FutureBuilder<Books?>(
                future: _bookFuture,
                builder: (context, bookSnapshot) {
                  final Books? book = bookSnapshot.data;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      BookCover(
                        coverUrl: book?.coverUrl ?? '',
                        title: book?.title ?? '',
                        width: 96,
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book?.title ?? '',
                              style: textTheme.displayLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              book?.author ?? '',
                              style: textTheme.bodyMedium?.copyWith(
                                color: LuminaColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              FutureBuilder<int>(
                future: _percentFuture,
                builder: (context, percentSnapshot) {
                  return LuminaWidgets.progressBar(
                    (percentSnapshot.data ?? 0) / 100,
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FutureBuilder<int>(
                      future: _percentFuture,
                      builder: (context, percentSnapshot) {
                        return StatTile(
                          label: 'Progress',
                          value: '${percentSnapshot.data ?? 0}%',
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      label: 'Sessions',
                      value: '${entries.length}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      label: 'Time',
                      value: HabitServices.formatDuration(seconds),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const SectionHeader(label: 'Sessions'),
              const SizedBox(height: 8),
              if (entries.isEmpty)
                const EmptyState(
                  icon: Symbols.timer,
                  message:
                      'Each time you read, the session lands here with your '
                      'note and your open question.',
                )
              else
                for (final Entries entry in entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: buildBookProgressCard(
                      context,
                      entry,
                      onDelete: _deleteEntry,
                      onEdit: (int entryId) => _open('/edit-entry/$entryId'),
                    ),
                  ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _open('/add-book-progress/${widget.id}'),
                  child: const Text('Log manually'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _open('/read/${widget.id}'),
                  child: const Text('Read now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget buildBookProgressCard(
  BuildContext context,
  Entries entry, {
  required Future<void> Function(int entryId) onDelete,
  required void Function(int entryId) onEdit,
}) {
  final TextTheme textTheme = Theme.of(context).textTheme;
  final DateTime? createdAt = DateTime.tryParse(entry.createdAt ?? '');
  final List<String> details = <String>[
    if ((entry.durationSeconds ?? 0) >= 60)
      HabitServices.formatDuration(entry.durationSeconds!),
    if ((entry.pagesRead ?? 0) > 0) '${entry.pagesRead} pages',
    if ((entry.pagesRead ?? 0) == 0 && entry.percentageRead > 0)
      '+${entry.percentageRead}%',
  ];
  final String hook = (entry.hook ?? '').trim();

  if (details.isEmpty) {
    details.add('No time or pages logged');
  }

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 10, 6, 18),
    decoration: LuminaDecorations.card,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                createdAt != null
                    ? DateFormat('EEE d MMM').format(createdAt)
                    : 'Unknown date',
                style: textTheme.titleMedium,
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              iconColor: LuminaColors.textTertiary,
              onSelected: (String value) async {
                if (entry.id == null) {
                  return;
                }
                if (value == 'edit') {
                  onEdit(entry.id!);
                } else if (value == 'delete') {
                  await onDelete(entry.id!);
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('Delete'),
                ),
              ],
            ),
          ],
        ),
        Text(details.join(' · '), style: textTheme.bodySmall),
        if (entry.summary.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(entry.summary, style: textTheme.bodyMedium),
          ),
        ],
        if (hook.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              'Wanted to know: $hook',
              style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ],
    ),
  );
}
