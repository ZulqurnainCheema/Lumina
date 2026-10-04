import 'package:flutter/material.dart';
import 'package:lumina/services/database_services.dart';
import 'package:lumina/services/habit_services.dart';
import 'package:lumina/theme.dart';
import 'package:lumina/widgets/section_header.dart';
import 'package:lumina/widgets/stat_tile.dart';

class WeeklyReview extends StatefulWidget {
  const WeeklyReview({super.key});

  @override
  State<WeeklyReview> createState() => _WeeklyReviewState();
}

class _WeeklyReviewState extends State<WeeklyReview> {
  // Self-Report Behavioural Automaticity Index (Gardner et al. 2012).
  static const List<String> _automaticityItems = <String>[
    'I do automatically',
    'I do without having to consciously remember',
    'I do without thinking',
    'I start doing before I realize I am doing it',
  ];
  static const int _daysBetweenChecks = 14;

  final DatabaseServices _databaseServices = DatabaseServices.instance;
  late final Future<_ReviewData> _reviewFuture;
  final List<int> _answers = List<int>.filled(_automaticityItems.length, 4);

  @override
  void initState() {
    super.initState();
    _reviewFuture = _loadReview();
  }

  Future<_ReviewData> _loadReview() async {
    final DateTime now = DateTime.now();
    final String to = HabitServices.dateKey(now);
    final String from = HabitServices.dateKey(
      DateTime(now.year, now.month, now.day - 6),
    );
    final Map<String, int> week = await _databaseServices.getPeriodSummary(
      from,
      to,
    );
    final int? bestHour = await _databaseServices.getBestReadingHour();
    final List<Map<String, dynamic>> checks = await _databaseServices
        .getHabitChecks();
    final DateTime? lastCheck = checks.isEmpty
        ? null
        : DateTime.tryParse(checks.last['createdAt'] as String? ?? '');
    return _ReviewData(
      week: week,
      bestHour: bestHour,
      checkDue:
          lastCheck == null ||
          now.difference(lastCheck).inDays >= _daysBetweenChecks,
    );
  }

  Future<void> _finishReview(bool checkDue) async {
    final DateTime now = DateTime.now();
    if (checkDue) {
      await _databaseServices.addHabitCheck(
        _answers.reduce((a, b) => a + b),
        now.toIso8601String(),
      );
    }
    await _databaseServices.setSetting(
      'lastReviewDate',
      HabitServices.dateKey(now),
    );
    if (!mounted) {
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(),
      body: FutureBuilder<_ReviewData>(
        future: _reviewFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final _ReviewData review = snapshot.data!;
          final int days = review.week['days']!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              Text('Weekly review', style: textTheme.displayLarge),
              const SizedBox(height: 28),
              const SectionHeader(
                label: 'Your last 7 days',
                researchKey: 'freshStart',
              ),
              const SizedBox(height: 8),
              Text(
                'You read on $days of 7 days',
                style: textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                days >= 5
                    ? 'That is a week most people never manage. Same plan again.'
                    : 'New week, clean slate. What one thing would make it easier to start?',
                style: textTheme.bodyMedium?.copyWith(
                  color: LuminaColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Time',
                      value: HabitServices.formatDuration(
                        review.week['seconds']!,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      label: 'Pages',
                      value: '${review.week['pages']}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      label: 'Longest',
                      value: HabitServices.formatDuration(
                        review.week['longestSession']!,
                      ),
                    ),
                  ),
                ],
              ),
              if (review.bestHour != null) ...[
                const SizedBox(height: 10),
                Text(
                  'You usually read around ${review.bestHour}:00.',
                  style: textTheme.bodySmall,
                ),
              ],
              if (review.checkDue) ...[
                const SizedBox(height: 32),
                const SectionHeader(
                  label: 'How automatic is it?',
                  researchKey: 'habitStrength',
                ),
                const SizedBox(height: 4),
                Text('Reading is something...', style: textTheme.titleLarge),
                for (int index = 0; index < _automaticityItems.length; index++)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 18),
                      Text(
                        _automaticityItems[index],
                        style: textTheme.bodyMedium,
                      ),
                      Slider(
                        value: _answers[index].toDouble(),
                        min: 1,
                        max: 7,
                        divisions: 6,
                        label: '${_answers[index]}',
                        onChanged: (value) {
                          setState(() {
                            _answers[index] = value.round();
                          });
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Disagree', style: textTheme.bodySmall),
                            Text('Agree', style: textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => _finishReview(review.checkDue),
                child: const Text('Start the new week'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReviewData {
  const _ReviewData({
    required this.week,
    required this.bestHour,
    required this.checkDue,
  });

  final Map<String, int> week;
  final int? bestHour;
  final bool checkDue;
}
