import 'package:flutter/material.dart';
import 'package:lumina/models/entries.dart';
import 'package:lumina/services/habit_services.dart';
import 'package:lumina/services/home_widget_service.dart';
import 'package:lumina/services/notifications_center.dart';
import 'package:lumina/theme.dart';
import 'package:lumina/services/database_services.dart';
import 'package:lumina/widgets/celebration.dart';

class AddBookProgress extends StatefulWidget {
  const AddBookProgress({super.key, required this.id, this.durationSeconds});

  final int id;
  final int? durationSeconds;

  @override
  State<AddBookProgress> createState() => _AddBookProgressState();
}

class _AddBookProgressState extends State<AddBookProgress> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _percentageReadController =
      TextEditingController();
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _pagesController = TextEditingController();
  final TextEditingController _hookController = TextEditingController();
  final _DatabaseServices = DatabaseServices.instance;
  bool _isbypages = false;
  int? _absorption;

  bool get _hasSession => (widget.durationSeconds ?? 0) > 0;

  TextStyle? get _fieldTextStyle => Theme.of(context).textTheme.bodyMedium
      ?.copyWith(color: LuminaColors.white, fontWeight: FontWeight.w500);

  String? _validateNumber(String? value, {required int max}) {
    final String text = (value ?? '').trim();
    // After a timed session the amount can be left blank.
    if (text.isEmpty && _hasSession) {
      return null;
    }
    final int? number = int.tryParse(text);
    if (number == null || number < (_hasSession ? 0 : 1)) {
      return 'Please enter a number';
    }
    if (number > max) {
      return 'That is more than $max';
    }
    return null;
  }

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
      final int? pagesRead = _isbypages
          ? int.tryParse(_pagesController.text.trim())
          : null;
      final int percentageRead;
      if (_isbypages) {
        percentageRead = totalPages > 0
            ? ((pagesRead ?? 0) / totalPages * 100).toInt()
            : 0;
      } else {
        percentageRead =
            int.tryParse(_percentageReadController.text.trim()) ?? 0;
      }
      Entries newEntry = Entries(
        bookId: widget.id,
        percentageRead: percentageRead,
        summary: _summaryController.text.trim(),
        createdAt: DateTime.now().toIso8601String(),
        pagesRead: pagesRead,
        durationSeconds: widget.durationSeconds,
        hook: _hookController.text.trim(),
        absorption: _absorption,
      );
      await _DatabaseServices.addEntry(newEntry.toMap());
      await NotificationsCenter.instance.refresh();
      await HomeWidgetService.update();
      final Celebration? celebration = await HabitServices.instance
          .afterEntry();
      if (!context.mounted) {
        return;
      }
      if (celebration != null) {
        await showCelebration(context, celebration);
        if (!context.mounted) {
          return;
        }
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
                    _hasSession
                        ? (widget.durationSeconds! < 60
                              ? 'You read for under a minute'
                              : 'You read for ${HabitServices.formatDuration(widget.durationSeconds!)}')
                        : 'Add Book Progress',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Log how far you got. The two notes are optional and take ten seconds.',
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
                              labelText: 'Pages Read',
                              hintText: 'Pages you read this session',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) =>
                                _validateNumber(value, max: 5000),
                          ),
                          SizedBox(height: 20),
                        ] else ...[
                          TextFormField(
                            controller: _percentageReadController,
                            style: _fieldTextStyle,
                            decoration: InputDecoration(
                              labelText: 'Percentage Read',
                              hintText: 'Percent of the book read this session',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) =>
                                _validateNumber(value, max: 100),
                          ),
                          SizedBox(height: 20),
                        ],
                        TextFormField(
                          controller: _summaryController,
                          style: _fieldTextStyle,
                          decoration: InputDecoration(
                            labelText: 'One thing worth keeping',
                            hintText: 'A line, an idea, or what just happened',
                          ),
                          keyboardType: TextInputType.multiline,
                          maxLines: 4,
                        ),
                        SizedBox(height: 20),
                        TextFormField(
                          controller: _hookController,
                          style: _fieldTextStyle,
                          decoration: InputDecoration(
                            labelText: 'What do you want to find out next?',
                            hintText: 'Lumina shows this back to you tomorrow',
                          ),
                          maxLines: 2,
                        ),
                        SizedBox(height: 20),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'How lost in it were you?',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (int level = 1; level <= 5; level++)
                              ChoiceChip(
                                label: Text('$level'),
                                selected: _absorption == level,
                                showCheckmark: false,
                                onSelected: (selected) {
                                  setState(() {
                                    _absorption = selected ? level : null;
                                  });
                                },
                              ),
                          ],
                        ),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () async {
                            await SubmissionHandler();
                          },
                          child: Text('Save'),
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
