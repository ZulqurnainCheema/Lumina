import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lumina/services/habit_services.dart';
import 'package:lumina/theme.dart';

class TodayCard extends StatefulWidget {
  const TodayCard({super.key});

  @override
  State<TodayCard> createState() => _TodayCardState();
}

class _TodayCardState extends State<TodayCard> {
  late final Future<TodayData> _todayFuture;

  @override
  void initState() {
    super.initState();
    _todayFuture = HabitServices.instance.getToday();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TodayData>(
      future: _todayFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 96);
        }
        final TodayData today = snapshot.data!;
        final StreakState streak = today.streak;
        final int minutesToday = today.secondsToday ~/ 60;
        final int goalSeconds = today.goalMinutes * 60;
        final TextTheme textTheme = Theme.of(context).textTheme;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: LuminaDecorations.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: (today.secondsToday / goalSeconds).clamp(0, 1),
                          strokeWidth: 6,
                          backgroundColor: LuminaColors.track,
                          color: LuminaColors.accent,
                        ),
                        Center(
                          child: Text(
                            '$minutesToday',
                            style: textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.local_fire_department_rounded,
                              color: streak.readToday
                                  ? LuminaColors.accent
                                  : LuminaColors.neutral,
                              size: 22,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${streak.current} day streak',
                              style: textTheme.titleMedium,
                            ),
                            const SizedBox(width: 8),
                            for (int i = 0; i < streak.freezes; i++)
                              const Icon(
                                Icons.ac_unit_rounded,
                                color: LuminaColors.neutral,
                                size: 16,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$minutesToday of ${today.goalMinutes} min today',
                          style: textTheme.bodySmall,
                        ),
                        if (!streak.readToday && streak.current > 0)
                          Text(
                            'One page keeps the streak.',
                            style: textTheme.labelMedium,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (streak.repairAvailable) ...[
                const SizedBox(height: 12),
                Text(
                  'You missed yesterday. Read ${today.goalMinutes * 2} minutes '
                  'today and your ${streak.repairableStreak} day streak comes back.',
                  style: textTheme.labelMedium,
                ),
              ],
              if (today.plan != null) ...[
                const SizedBox(height: 12),
                Text(today.plan!, style: textTheme.bodySmall),
              ],
              const SizedBox(height: 14),
              if (today.book == null)
                Text('Add a book to start reading.', style: textTheme.bodySmall)
              else ...[
                Text(
                  today.book!.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium,
                ),
                if (today.hook != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'You wanted to know: ${today.hook}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: LuminaColors.white,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (today.pagesLeft != null) ...[
                  const SizedBox(height: 4),
                  Text(_pagesLeftLabel(today), style: textTheme.bodySmall),
                ],
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    GoRouter.of(context).push('/read/${today.book!.id}');
                  },
                  child: Text(
                    today.percentage > 0 ? 'Continue reading' : 'Start reading',
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _pagesLeftLabel(TodayData today) {
    final String time = today.secondsLeft == null
        ? ''
        : ' · about ${HabitServices.formatDuration(today.secondsLeft!)} at your pace';
    if (today.percentage >= 60) {
      return 'Almost there: ${today.pagesLeft} pages to the end$time';
    }
    return '${today.pagesLeft} pages left$time';
  }
}
