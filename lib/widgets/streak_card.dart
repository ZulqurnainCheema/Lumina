import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lumina/services/habit_services.dart';
import 'package:lumina/theme.dart';
import 'package:lumina/widgets/why_chip.dart';

// The streak, the last seven days and what to do about them. Shown on Today
// and, rendered to an image, as the home-screen widget.
class StreakCard extends StatelessWidget {
  const StreakCard({super.key, required this.today, this.showWhy = true});

  final TodayData today;

  // The home-screen widget cannot open the explanation, so it leaves it out.
  final bool showWhy;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final StreakState streak = today.streak;

    final String? status;
    if (streak.repairAvailable) {
      status =
          'You missed yesterday. Read ${today.goalMinutes * 2} minutes '
          'today and your ${streak.repairableStreak} day streak comes back.';
    } else if (!streak.readToday && streak.current > 0) {
      status = 'One page keeps the streak.';
    } else {
      status = null;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 20),
      decoration: LuminaDecorations.tinted(LuminaColors.streak),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                color: LuminaColors.streak,
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${streak.current}',
                        style: textTheme.headlineLarge?.copyWith(
                          color: LuminaColors.streak,
                        ),
                      ),
                      TextSpan(
                        text: ' day streak',
                        style: textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
              if (showWhy) const WhyChip(researchKey: 'streak'),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final WeekDay day in today.week) _DayDot(day: day),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              status ??
                  (streak.freezes == 0
                      ? 'Seven days in a row earns a freeze for a missed day.'
                      : 'Keep going. A missed day will not break it.'),
              style: status == null
                  ? textTheme.bodySmall
                  : textTheme.bodyMedium,
            ),
          ),
          if (streak.freezes > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: LuminaColors.background.withAlpha(110),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.ac_unit_rounded,
                    size: 14,
                    color: LuminaColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${streak.freezes} freeze${streak.freezes == 1 ? '' : 's'} banked',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// One day in the week strip: filled when read, ringed when it is today.
class _DayDot extends StatelessWidget {
  const _DayDot({required this.day});

  final WeekDay day;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool read = day.state == DayState.read;
    final Widget? mark = switch (day.state) {
      DayState.read => const Icon(
        Icons.check_rounded,
        size: 18,
        color: LuminaColors.background,
      ),
      DayState.saved => const Icon(
        Icons.ac_unit_rounded,
        size: 16,
        color: LuminaColors.textSecondary,
      ),
      _ => null,
    };
    return Column(
      children: [
        Text(
          DateFormat('E').format(day.date).substring(0, 1),
          style: textTheme.labelMedium,
        ),
        const SizedBox(height: 6),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: read
                ? LuminaColors.streak
                : LuminaColors.background.withAlpha(110),
            border: day.state == DayState.open
                ? Border.all(color: LuminaColors.streak, width: 2)
                : null,
          ),
          child: mark,
        ),
      ],
    );
  }
}
