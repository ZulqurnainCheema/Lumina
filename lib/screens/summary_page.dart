import 'package:flutter/material.dart';
import 'package:lumina/services/database_services.dart';
import 'package:lumina/theme.dart';
import 'package:lumina/widgets/empty_state.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

class SummaryPage extends StatelessWidget {
  final int id;
  final _databaseServices = DatabaseServices.instance;
  SummaryPage({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your notes')),
      body: FutureBuilder<List<String>>(
        future: _databaseServices.getSummaries(id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Error loading summaries'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const EmptyState(
              icon: Symbols.edit_note,
              message:
                  'The one-line notes you write after each session collect '
                  'here.',
            );
          } else {
            final summaries = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: summaries.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: LuminaDecorations.card,
                  child: Text(
                    summaries[index],
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
