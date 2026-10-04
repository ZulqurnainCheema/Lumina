import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lumina/services/database_services.dart';
import 'package:lumina/services/habit_services.dart';
import 'package:lumina/theme.dart';
import 'package:lumina/widgets/empty_state.dart';
import 'package:lumina/widgets/route_refresh.dart';
import 'package:lumina/widgets/section_header.dart';
import 'package:lumina/widgets/stat_tile.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with RouteRefresh<StatisticsScreen> {
  static const int _chartDays = 14;

  final DatabaseServices _databaseServices = DatabaseServices.instance;
  late Future<_StatisticsViewData> _statisticsFuture;

  @override
  String get routePath => '/statistics';

  @override
  void onRouteShown() {
    setState(() {
      _statisticsFuture = _loadStatisticsData();
    });
  }

  @override
  void initState() {
    super.initState();
    _statisticsFuture = _loadStatisticsData();
  }

  Future<_StatisticsViewData> _loadStatisticsData() async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final StreakState streakState = await HabitServices.instance
        .getStreakState();
    final Map<String, int> week = await _databaseServices.getPeriodSummary(
      HabitServices.dateKey(DateTime(now.year, now.month, now.day - 6)),
      HabitServices.dateKey(now),
    );
    final Map<String, int> lifetime = await _databaseServices
        .getLifetimeTotals();
    final int finishedBooks = await _databaseServices.getFinishedBooksCount();
    final bool hasEntries = await _databaseServices.getLastEntryTime() != null;

    final Map<String, int> minutesByDate = await _databaseServices
        .getMinutesByDate(
          HabitServices.dateKey(
            DateTime(now.year, now.month, now.day - (_chartDays - 1)),
          ),
        );
    final List<_MinutesPoint> minutes = <_MinutesPoint>[
      for (int offset = _chartDays - 1; offset >= 0; offset--)
        _MinutesPoint(
          date: DateTime(today.year, today.month, today.day - offset),
          minutes:
              minutesByDate[HabitServices.dateKey(
                DateTime(today.year, today.month, today.day - offset),
              )] ??
              0,
        ),
    ];

    final List<_HabitPoint> habitData =
        (await _databaseServices.getHabitChecks())
            .map(
              (row) => _HabitPoint(
                date: DateTime.parse(row['createdAt'] as String),
                score: row['score'] as int? ?? 0,
              ),
            )
            .toList();

    return _StatisticsViewData(
      hasEntries: hasEntries,
      streak: streakState.current,
      longestStreak: streakState.longest,
      week: week,
      lifetimePages: lifetime['pages']!,
      lifetimeSeconds: lifetime['seconds']!,
      finishedBooks: finishedBooks,
      minutes: minutes,
      habitData: habitData,
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final TextStyle? axisStyle = textTheme.bodySmall?.copyWith(
      fontSize: 11,
      color: LuminaColors.textTertiary,
    );
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<_StatisticsViewData>(
          future: _statisticsFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Failed to load statistics.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium,
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final _StatisticsViewData stats = snapshot.data!;
            if (!stats.hasEntries) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Text('Stats', style: textTheme.displayLarge),
                  ),
                  const Expanded(
                    child: EmptyState(
                      icon: Symbols.bar_chart,
                      message:
                          'No reading yet. Your streak, reading time and '
                          'habit strength show up here after your first '
                          'session.',
                    ),
                  ),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              children: [
                Text('Stats', style: textTheme.displayLarge),
                const SizedBox(height: 24),
                // The hero tile: days read this week, with the daily bars.
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
                  decoration: LuminaDecorations.card,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        label: 'This week',
                        researchKey: 'tracking',
                      ),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${stats.week['days']}',
                              style: textTheme.displayMedium?.copyWith(
                                color: LuminaColors.accent,
                              ),
                            ),
                            TextSpan(
                              text: ' of 7 days',
                              style: textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 130,
                        child: SfCartesianChart(
                          backgroundColor: Colors.transparent,
                          plotAreaBorderWidth: 0,
                          margin: EdgeInsets.zero,
                          primaryXAxis: DateTimeCategoryAxis(
                            dateFormat: DateFormat.d(),
                            majorGridLines: const MajorGridLines(width: 0),
                            majorTickLines: const MajorTickLines(size: 0),
                            axisLine: const AxisLine(width: 0),
                            labelStyle: axisStyle,
                          ),
                          primaryYAxis: const NumericAxis(
                            minimum: 0,
                            isVisible: false,
                          ),
                          series: <CartesianSeries<_MinutesPoint, DateTime>>[
                            ColumnSeries<_MinutesPoint, DateTime>(
                              dataSource: stats.minutes,
                              xValueMapper: (_MinutesPoint point, _) =>
                                  point.date,
                              yValueMapper: (_MinutesPoint point, _) =>
                                  point.minutes,
                              color: LuminaColors.accent,
                              width: 0.6,
                              borderRadius: BorderRadius.circular(6),
                              animationDuration: 0,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Minutes per day, last $_chartDays days',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Read this week',
                        value: HabitServices.formatDuration(
                          stats.week['seconds']!,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatTile(
                        label: 'Pages this week',
                        value: '${stats.week['pages']}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const SectionHeader(label: 'All time', researchKey: 'streak'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Current streak',
                        value: '${stats.streak}',
                        unit: 'days',
                        color: LuminaColors.streak,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatTile(
                        label: 'Longest streak',
                        value: '${stats.longestStreak}',
                        unit: 'days',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Books finished',
                        value: '${stats.finishedBooks}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatTile(
                        label: 'Pages read',
                        value: '${stats.lifetimePages}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                StatTile(
                  label: 'Total reading time',
                  value: HabitServices.formatDuration(stats.lifetimeSeconds),
                ),
                const SizedBox(height: 28),
                const SectionHeader(
                  label: 'Habit strength',
                  researchKey: 'habitStrength',
                ),
                const SizedBox(height: 8),
                if (stats.habitData.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: LuminaDecorations.card,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Answer four questions in the weekly review and '
                          'this becomes a line showing how automatic reading '
                          'is getting.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: LuminaColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton(
                          onPressed: () => GoRouter.of(context).push('/review'),
                          child: const Text('Do the weekly review'),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    height: 240,
                    padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
                    decoration: LuminaDecorations.card,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            '4 means reading takes effort every time. 28 '
                            'means it happens without thinking.',
                            style: textTheme.bodySmall,
                          ),
                        ),
                        Expanded(
                          child: SfCartesianChart(
                            backgroundColor: Colors.transparent,
                            plotAreaBorderWidth: 0,
                            margin: const EdgeInsets.only(top: 12),
                            primaryXAxis: DateTimeAxis(
                              dateFormat: DateFormat.MMMd(),
                              majorGridLines: const MajorGridLines(width: 0),
                              majorTickLines: const MajorTickLines(size: 0),
                              axisLine: const AxisLine(width: 0),
                              labelStyle: axisStyle,
                            ),
                            primaryYAxis: NumericAxis(
                              minimum: 4,
                              maximum: 28,
                              interval: 8,
                              axisLine: const AxisLine(width: 0),
                              majorTickLines: const MajorTickLines(size: 0),
                              majorGridLines: const MajorGridLines(
                                width: 0.8,
                                color: LuminaColors.borderSubtle,
                              ),
                              labelStyle: axisStyle,
                            ),
                            series: <CartesianSeries<_HabitPoint, DateTime>>[
                              LineSeries<_HabitPoint, DateTime>(
                                dataSource: stats.habitData,
                                xValueMapper: (_HabitPoint point, _) =>
                                    point.date,
                                yValueMapper: (_HabitPoint point, _) =>
                                    point.score,
                                width: 3,
                                animationDuration: 0,
                                color: LuminaColors.recall,
                                markerSettings: const MarkerSettings(
                                  isVisible: true,
                                  color: LuminaColors.recall,
                                  borderColor: LuminaColors.surface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MinutesPoint {
  const _MinutesPoint({required this.date, required this.minutes});

  final DateTime date;
  final int minutes;
}

class _HabitPoint {
  const _HabitPoint({required this.date, required this.score});

  final DateTime date;
  final int score;
}

class _StatisticsViewData {
  const _StatisticsViewData({
    required this.hasEntries,
    required this.streak,
    required this.longestStreak,
    required this.week,
    required this.lifetimePages,
    required this.lifetimeSeconds,
    required this.finishedBooks,
    required this.minutes,
    required this.habitData,
  });

  final bool hasEntries;
  final int streak;
  final int longestStreak;
  final Map<String, int> week;
  final int lifetimePages;
  final int lifetimeSeconds;
  final int finishedBooks;
  final List<_MinutesPoint> minutes;
  final List<_HabitPoint> habitData;
}
