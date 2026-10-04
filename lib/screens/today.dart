import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lumina/models/books.dart';
import 'package:lumina/services/database_services.dart';
import 'package:lumina/services/habit_services.dart';
import 'package:lumina/services/home_widget_service.dart';
import 'package:lumina/services/notifications_center.dart';
import 'package:lumina/theme.dart';
import 'package:lumina/widgets/book_cover.dart';
import 'package:lumina/widgets/empty_state.dart';
import 'package:lumina/widgets/lumina_sheet.dart';
import 'package:lumina/widgets/route_refresh.dart';
import 'package:lumina/widgets/section_header.dart';
import 'package:lumina/widgets/why_chip.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

class Today extends StatefulWidget {
  const Today({super.key});

  @override
  State<Today> createState() => _TodayState();
}

class _TodayState extends State<Today> with RouteRefresh<Today> {
  final DatabaseServices _databaseServices = DatabaseServices.instance;
  late Future<TodayData> _todayFuture;

  @override
  String get routePath => '/';

  @override
  void onRouteShown() {
    setState(() {
      _todayFuture = HabitServices.instance.getToday();
    });
  }

  @override
  void initState() {
    super.initState();
    _todayFuture = HabitServices.instance.getToday();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onAppOpened();
    });
  }

  Future<void> _onAppOpened() async {
    await NotificationsCenter.instance.refresh();
    await HomeWidgetService.update();
    if (!mounted) {
      return;
    }
    final int sessionBookId = await _databaseServices.getIntSetting(
      'sessionBookId',
      -1,
    );
    if (!mounted) {
      return;
    }
    if (sessionBookId >= 0) {
      GoRouter.of(context).push('/read/$sessionBookId');
      return;
    }
    if (await HomeWidgetService.launchedFromWidget()) {
      final Books? book = await _databaseServices.getCurrentBook();
      if (book != null && mounted) {
        GoRouter.of(context).push('/read/${book.id}');
      }
      return;
    }
    await _showOpenPrompt();
  }

  // At most one prompt per app open, most useful first.
  Future<void> _showOpenPrompt() async {
    final DateTime now = DateTime.now();
    final String today = HabitServices.dateKey(now);

    if (await _databaseServices.getSetting('planPrompted') == null) {
      await _databaseServices.setSetting('planPrompted', today);
      if (!mounted) {
        return;
      }
      GoRouter.of(context).push('/plan');
      return;
    }

    final bool freshStart = now.weekday == DateTime.monday || now.day == 1;
    if (freshStart &&
        await _databaseServices.getSetting('reviewOffered') != today &&
        await _databaseServices.getSetting('lastReviewDate') != today &&
        await _databaseServices.getLastEntryTime() != null) {
      await _databaseServices.setSetting('reviewOffered', today);
      if (!mounted) {
        return;
      }
      final bool? review = await showLuminaSheet(
        context,
        title: 'New week, clean slate',
        body: 'Take two minutes to look at last week before this one starts.',
        confirm: 'Review my week',
        dismiss: 'Later',
        researchKey: 'freshStart',
      );
      if (review == true && mounted) {
        GoRouter.of(context).push('/review');
      }
      return;
    }

    for (final Books book in await _databaseServices.getStaleBooks(today)) {
      if (await _databaseServices.getSetting('staleAsked_${book.id}') ==
          today.substring(0, 7)) {
        continue;
      }
      await _databaseServices.setSetting(
        'staleAsked_${book.id}',
        today.substring(0, 7),
      );
      if (!mounted) {
        return;
      }
      final bool? keep = await showLuminaSheet(
        context,
        title: 'Still into ${book.title}?',
        body:
            'You have not opened it in a week. Dropping a book you are not '
            'enjoying is not failing. The pages you read still count.',
        confirm: 'Keep it',
        dismiss: 'Drop it',
        researchKey: 'dropBook',
      );
      if (keep == false) {
        await _databaseServices.updateBook(book.id, {
          'abandonedAt': now.toIso8601String(),
        });
        if (mounted) {
          onRouteShown();
        }
      }
      return;
    }

    if (await _databaseServices.getSetting('recallShown') == today) {
      return;
    }
    final Map<String, dynamic>? recall = await _databaseServices.getRecallEntry(
      today,
    );
    if (recall == null || !mounted) {
      return;
    }
    await _databaseServices.setSetting('recallShown', today);
    if (!mounted) {
      return;
    }
    final bool? reveal = await showLuminaSheet(
      context,
      title: 'What do you remember?',
      body:
          'You wrote a note about ${recall['title']}. Try to recall it before '
          'you look.',
      confirm: 'Show my note',
      dismiss: 'Skip',
      researchKey: 'recall',
    );
    if (reveal == true && mounted) {
      await showLuminaSheet(
        context,
        title: recall['title'] as String,
        body: recall['summary'] as String,
        confirm: 'Got it',
      );
    }
  }

  String _greeting(DateTime now) {
    if (now.hour < 12) {
      return 'Good morning';
    }
    if (now.hour < 18) {
      return 'Good afternoon';
    }
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final DateTime now = DateTime.now();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<TodayData>(
          future: _todayFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final TodayData today = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEEE d MMM').format(now).toUpperCase(),
                            style: textTheme.labelMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(_greeting(now), style: textTheme.displayLarge),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => GoRouter.of(context).push('/settings'),
                      tooltip: 'Settings',
                      style: IconButton.styleFrom(
                        backgroundColor: LuminaColors.surface,
                      ),
                      icon: const Icon(Symbols.settings),
                      color: LuminaColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _Hero(today: today),
                const SizedBox(height: 20),
                SectionHeader(
                  label: 'Now reading',
                  researchKey: today.pagesLeft == null ? null : 'finishLine',
                ),
                const SizedBox(height: 8),
                if (today.book == null)
                  Container(
                    decoration: LuminaDecorations.card,
                    child: EmptyState(
                      icon: Symbols.menu_book,
                      title: 'Pick your first book',
                      message:
                          'It shows up here with one button to start reading.',
                      actionLabel: 'Add your first book',
                      onAction: () => GoRouter.of(context).push('/add-books'),
                    ),
                  )
                else
                  _BookCard(today: today),
                const SizedBox(height: 12),
                _StreakCard(today: today),
                const SizedBox(height: 12),
                _PlanLine(plan: today.plan),
              ],
            );
          },
        ),
      ),
    );
  }
}

// The one big thing on the screen: minutes read today, inside the goal ring.
class _Hero extends StatelessWidget {
  const _Hero({required this.today});

  final TodayData today;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final int minutesToday = today.secondsToday ~/ 60;
    final double progress = (today.secondsToday / (today.goalMinutes * 60))
        .clamp(0, 1);
    return Center(
      child: SizedBox(
        width: 176,
        height: 176,
        child: Stack(
          fit: StackFit.expand,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return CircularProgressIndicator(
                  value: value,
                  strokeWidth: 12,
                  strokeCap: StrokeCap.round,
                  backgroundColor: LuminaColors.surface,
                  color: LuminaColors.accent,
                );
              },
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$minutesToday',
                    style: textTheme.displayMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'of ${today.goalMinutes} min today',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.today});

  final TodayData today;

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
              const WhyChip(researchKey: 'streak'),
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

class _BookCard extends StatelessWidget {
  const _BookCard({required this.today});

  final TodayData today;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Books book = today.book!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: LuminaDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookCover(coverUrl: book.coverUrl, title: book.title, width: 72),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(book.author, style: textTheme.bodySmall),
                    const SizedBox(height: 12),
                    LuminaWidgets.progressBar(today.percentage / 100),
                    const SizedBox(height: 8),
                    Text(_progressLabel(), style: textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          if (today.hook != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 8, 6, 16),
              decoration: BoxDecoration(
                color: LuminaColors.tint(LuminaColors.recall),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'YOU WANTED TO KNOW',
                          style: textTheme.labelMedium?.copyWith(
                            color: LuminaColors.recall,
                          ),
                        ),
                      ),
                      const WhyChip(researchKey: 'hook'),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Text(
                      today.hook!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: LuminaTheme.display(
                        size: 18,
                        height: 1.3,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => GoRouter.of(context).push('/read/${book.id}'),
            child: Text(
              today.percentage > 0 ? 'Continue reading' : 'Start reading',
            ),
          ),
        ],
      ),
    );
  }

  String _progressLabel() {
    if (today.pagesLeft == null) {
      return '${today.percentage}% read';
    }
    final String time = today.secondsLeft == null
        ? ''
        : ' · about ${HabitServices.formatDuration(today.secondsLeft!)}';
    return '${today.pagesLeft} pages left$time';
  }
}

class _PlanLine extends StatelessWidget {
  const _PlanLine({required this.plan});

  final String? plan;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(LuminaTheme.radiusCard),
      onTap: () => GoRouter.of(context).push('/plan'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: LuminaDecorations.card,
        child: Row(
          children: [
            const Icon(
              Symbols.schedule,
              size: 20,
              color: LuminaColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                plan ?? 'Set when and where you read',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: LuminaColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
