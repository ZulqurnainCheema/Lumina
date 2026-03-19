import 'package:flutter/material.dart';
import 'package:lumina/models/entries.dart';
import 'package:lumina/notifications_handler.dart';
import 'package:lumina/theme.dart';
import 'package:lumina/services/database_services.dart';

class AddBookProgress extends StatefulWidget {
  const AddBookProgress({super.key, required this.id});

  final int id;

  @override
  State<AddBookProgress> createState() => _AddBookProgressState();
}

class _AddBookProgressState extends State<AddBookProgress> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _percentageReadController =
      TextEditingController();
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _pagesController = TextEditingController();
  final _DatabaseServices = DatabaseServices.instance;
  bool _isbypages = false;

  TextStyle? get _fieldTextStyle => Theme.of(context).textTheme.bodyMedium
      ?.copyWith(color: LuminaColors.white, fontWeight: FontWeight.w500);

  Future<void> SubmissionHandler() async {
    if (_formKey.currentState!.validate()) {
      final currentPercentage = await _DatabaseServices.getPercentageRead(
        widget.id,
      );
      if (currentPercentage >= 100) {
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Book is already at 100%')),
        );
        return;
      }

      final totalPages = await _DatabaseServices.getTotalPages(widget.id);
      Entries newEntry = Entries(
        bookId: widget.id,
        percentageRead: _isbypages
            ? (int.parse(_pagesController.text) / totalPages * 100).toInt()
            : int.parse(_percentageReadController.text),
        summary: _summaryController.text,
        createdAt: DateTime.now().toIso8601String(),
      );
      await _DatabaseServices.addEntry(newEntry.toMap());
      await NotificationsHandler.instance.refreshSchedules();
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Book progress added successfully!')),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Add Book Progress")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
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
                children: [
                  Text(
                    'Add Book Progress',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Expand your reading journey by adding your book progress. Share your insights and reflections as you read.',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  SizedBox(height: 30),
                  Row(
                    children: [
                      Text('Track by Pages'),
                      Switch(
                        value: _isbypages,
                        onChanged: (value) {
                          setState(() {
                            _isbypages = value;
                          });
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        if (_isbypages) ...[
                          TextFormField(
                            controller: _pagesController,
                            style: _fieldTextStyle,
                            decoration: InputDecoration(
                              labelText: 'Total Pages Read',
                              hintText: 'Enter the total number of pages read',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter the total number of pages read';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 20),
                        ] else ...[
                          TextFormField(
                            controller: _percentageReadController,
                            style: _fieldTextStyle,
                            decoration: InputDecoration(
                              labelText: 'Percentage Read',
                              hintText: 'Enter the percentage of the book read',
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter the percentage of the book read';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 20),
                        ],
                        TextFormField(
                          controller: _summaryController,
                          style: _fieldTextStyle,
                          decoration: InputDecoration(
                            labelText: 'Summary',
                            hintText:
                                'Enter a brief summary of the book progress',
                          ),
                          keyboardType: TextInputType.multiline,
                          maxLines: 15,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a summary of the book progress';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () async {
                            await SubmissionHandler();
                          },
                          child: Text('Add Book'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
