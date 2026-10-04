import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lumina/models/entries.dart';
import 'package:lumina/services/habit_services.dart';
import 'package:lumina/services/home_widget_service.dart';
import 'package:lumina/services/notifications_center.dart';
import 'package:lumina/theme.dart';
import 'package:lumina/services/database_services.dart';
import 'package:lumina/widgets/celebration.dart';
import 'package:lumina/widgets/section_header.dart';

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
  final TextEditingController _minutesController = TextEditingController();
  final _DatabaseServices = DatabaseServices.instance;
  bool _isbypages = false;
  int? _absorption;

  bool get _hasSession => (widget.durationSeconds ?? 0) > 0;

  TextStyle? get _fieldTextStyle => Theme.of(context).textTheme.bodyMedium
      ?.copyWith(color: LuminaColors.white, fontWeight: FontWeight.w500);

  // Where the reader was before this entry.
  int _percentSoFar = 0;
  int _currentPage = 0;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _loadPosition();
  }

  Future<void> _loadPosition() async {
    final int percentSoFar = await _DatabaseServices.getPercentageRead(
      widget.id,
    );
    final int currentPage = await _DatabaseServices.getCurrentPage(widget.id);
    final int totalPages = await _DatabaseServices.getTotalPages(widget.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _percentSoFar = percentSoFar;
      _currentPage = currentPage;
      _totalPages = totalPages;
    });
  }

  // The number typed is where you are now, so it has to be past where you
  // were and not past the end of the book.
  String? _validatePosition(String? value) {
    final String text = (value ?? '').trim();
    // After a timed session the position can be left blank.
    if (text.isEmpty && _hasSession) {
      return null;
    }
    final int? number = int.tryParse(text);
    if (number == null) {
      return 'Please enter a number';
    }
    final int before = _isbypages ? _currentPage : _percentSoFar;
    final int end = _isbypages ? _totalPages : 100;
    if (number < before || (number == before && !_hasSession)) {
      return _isbypages
          ? 'You were already on page $before'
          : 'You were already at $before%';
    }
    if (end > 0 && number > end) {
      return _isbypages ? 'The book has $end pages' : 'That is more than 100%';
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

      final String typed =
          (_isbypages ? _pagesController : _percentageReadController).text
              .trim();
      final progress = HabitServices.resolveProgress(
        byPages: _isbypages,
        // Left blank after a timed session: no change in position.
        position:
            int.tryParse(typed) ??
            (_isbypages ? _currentPage : currentPercentage),
        totalPages: _totalPages,
        percentSoFar: currentPercentage,
        currentPage: _currentPage,
      );
      Entries newEntry = Entries(
        bookId: widget.id,
        percentageRead: progress.percent,
        summary: _summaryController.text.trim(),
        createdAt: DateTime.now().toIso8601String(),
        pagesRead: progress.pages,
        // Without the timer, the minutes typed in fill today's ring.
        durationSeconds: _hasSession
            ? widget.durationSeconds
            : (int.tryParse(_minutesController.text.trim()) ?? 0) * 60,
        hook: _hookController.text.trim(),
        absorption: _absorption,
      );
      await _DatabaseServices.addEntry(newEntry.toMap());
      HapticFeedback.mediumImpact();
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
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(),
      body: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    !_hasSession
                        ? 'Log progress'
                        : widget.durationSeconds! < 60
                        ? 'You read for under a minute'
                        : 'You read for ${HabitServices.formatDuration(widget.durationSeconds!)}',
                    style: textTheme.displayLarge,
                  ),
                  SizedBox(height: 8),
                  Text(
                    _hasSession
                        ? 'Any amount keeps your streak. The two notes are optional.'
                        : 'Any amount keeps your streak. Add the minutes to fill today\'s ring.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: LuminaColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 28),
                  SectionHeader(
                    label: 'Where are you now?',
                    researchKey: 'tracking',
                  ),
                  SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment<bool>(
                          value: false,
                          label: Text('Percent'),
                        ),
                        ButtonSegment<bool>(value: true, label: Text('Pages')),
                      ],
                      selected: {_isbypages},
                      onSelectionChanged: (Set<bool> selection) {
                        setState(() {
                          _isbypages = selection.first;
                        });
                      },
                    ),
                  ),
                  SizedBox(height: 12),
                  if (_isbypages)
                    TextFormField(
                      controller: _pagesController,
                      style: _fieldTextStyle,
                      decoration: InputDecoration(
                        labelText: 'Page you are on now',
                        helperText: _totalPages > 0
                            ? 'You were on page $_currentPage of $_totalPages'
                            : 'You were on page $_currentPage',
                      ),
                      keyboardType: TextInputType.number,
                      validator: _validatePosition,
                    )
                  else
                    TextFormField(
                      controller: _percentageReadController,
                      style: _fieldTextStyle,
                      decoration: InputDecoration(
                        labelText: 'Percent you are at now',
                        helperText: 'You were at $_percentSoFar%',
                      ),
                      keyboardType: TextInputType.number,
                      validator: _validatePosition,
                    ),
                  if (!_hasSession) ...[
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _minutesController,
                      style: _fieldTextStyle,
                      decoration: InputDecoration(
                        labelText: 'Minutes read',
                        hintText: 'Counts toward today\'s goal',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final String text = (value ?? '').trim();
                        if (text.isEmpty) {
                          return null;
                        }
                        final int? minutes = int.tryParse(text);
                        if (minutes == null || minutes < 0 || minutes > 600) {
                          return 'Please enter minutes between 0 and 600';
                        }
                        return null;
                      },
                    ),
                  ],
                  SizedBox(height: 28),
                  SectionHeader(label: 'Keep one thing', researchKey: 'recall'),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: _summaryController,
                    style: _fieldTextStyle,
                    decoration: InputDecoration(
                      labelText: 'One line, from memory',
                      hintText: 'An idea, a line, or what just happened',
                    ),
                    keyboardType: TextInputType.multiline,
                    maxLines: 3,
                  ),
                  SizedBox(height: 28),
                  SectionHeader(
                    label: 'What do you want to find out next?',
                    researchKey: 'hook',
                  ),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: _hookController,
                    style: _fieldTextStyle,
                    decoration: InputDecoration(
                      labelText: 'Your open question',
                      hintText: 'Lumina shows this back to you tomorrow',
                    ),
                    maxLines: 2,
                  ),
                  SizedBox(height: 28),
                  SectionHeader(label: 'How absorbed were you?'),
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
                  SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Distracted', style: textTheme.bodySmall),
                      Text('Lost in it', style: textTheme.bodySmall),
                    ],
                  ),
                  SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () async {
                      await SubmissionHandler();
                    },
                    child: Text('Save'),
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
