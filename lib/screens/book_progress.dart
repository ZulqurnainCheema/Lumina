import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lumina/theme.dart';
import 'package:lumina/models/entries.dart';
import 'package:lumina/services/database_services.dart';
import 'package:material_symbols_icons/symbols.dart';

class BookProgress extends StatefulWidget {
  const BookProgress({super.key, required this.id});
  final int id;
  @override
  State<BookProgress> createState() => _BookProgressState();
}

class _BookProgressState extends State<BookProgress> {
  late Future<List<Entries>> _EntriesFuture;
  final _databaseServices = DatabaseServices.instance;

  @override
  void initState() {
    super.initState();
    _EntriesFuture = _databaseServices.getEntries(widget.id);
  }

  void _refreshEntries() {
    setState(() {
      _EntriesFuture = _databaseServices.getEntries(widget.id);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Progress'),
        actions: [
          IconButton(
            onPressed: () {
              GoRouter.of(context).go('/summary/${widget.id}');
            },
            icon: Icon(Symbols.article_rounded),
            color: LuminaColors.white,
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.45,
                  colors: [Color(0xFF13311F), LuminaColors.background],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: FutureBuilder<List<Entries>>(
                future: _EntriesFuture,
                builder: (context, snapshot) {
                  final entries = snapshot.data ?? <Entries>[];
                  final entriesCount = entries.length;
                  final progress = entries
                      .fold<int>(0, (sum, entry) => sum + entry.percentageRead)
                      .clamp(0, 100);

                  Widget entriesSection;
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    entriesSection = const Center(
                      child: CircularProgressIndicator(),
                    );
                  } else if (snapshot.hasError) {
                    entriesSection = Center(
                      child: Text('Error: ${snapshot.error}'),
                    );
                  } else if (entries.isEmpty) {
                    entriesSection = const Center(
                      child: Text('No progress updates yet.'),
                    );
                  } else {
                    entriesSection = ListView.builder(
                      padding: const EdgeInsets.only(bottom: 120),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        final createdAt = DateTime.tryParse(
                          entry.createdAt ?? '',
                        );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: buildBookProgressCard(
                            context,
                            entry.id,
                            entry.percentageRead,
                            createdAt,
                            entry.summary,
                            onDelete: _deleteEntry,
                          ),
                        );
                      },
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reading Insights',
                        style: Theme.of(context).textTheme.displayLarge,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Track milestones, reflections, and small wins for book #${widget.id}.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _MetricTile(
                              label: 'Progress',
                              value: '$progress%',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MetricTile(
                              label: 'Entries',
                              value: entriesCount.toString(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progress / 100,
                          minHeight: 8,
                          backgroundColor: LuminaColors.track,
                          valueColor: const AlwaysStoppedAnimation(
                            LuminaColors.accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Recent Updates',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 14),
                      Expanded(child: entriesSection),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        onPressed: () async {
          final result = await GoRouter.of(
            context,
          ).push<bool>('/add-book-progress/${widget.id}');

          if (!mounted) {
            return;
          }

          if (result == true) {
            _refreshEntries();
          }
        },
        tooltip: 'add book',
        child: const Icon(Icons.add, size: 40),
      ),
    );
  }
}

Widget buildBookProgressCard(
  BuildContext context,
  int? entryId,
  int percentageRead,
  DateTime? createdAt,
  String summary, {
  required Future<void> Function(int entryId) onDelete,
}) {
  final updatedLabel = createdAt != null
      ? createdAt.toLocal().toString().split(' ')[0]
      : 'Unknown date';

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: LuminaDecorations.card,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: LuminaColors.track,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              '$percentageRead%',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$percentageRead% read',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Updated on $updatedLabel',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Text(
                summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (String value) async {
            if (value == 'delete' && entryId != null) {
              await onDelete(entryId);
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
          ],
        ),
      ],
    ),
  );
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LuminaColors.background.withAlpha(150),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LuminaColors.borderSubtle),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
