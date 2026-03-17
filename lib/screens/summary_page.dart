import 'package:flutter/material.dart';
import 'package:reading_assist/services/database_services.dart';

class SummaryPage extends StatelessWidget {
  final int id;
  final _databaseServices = DatabaseServices.instance;
  SummaryPage({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book Summary')),
      body: FutureBuilder<List<String>>(
        future: _databaseServices.getSummaries(id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Error loading summaries'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No summaries available'));
          } else {
            final summaries = snapshot.data!;
            return ListView.builder(
              itemCount: summaries.length,
              itemBuilder: (context, index) {
                return ListTile(title: Text(summaries[index]));
              },
            );
          }
        },
      ),
    );
  }
}
