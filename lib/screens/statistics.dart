import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lumina/services/database_services.dart';
import 'package:lumina/services/habit_services.dart';
import 'package:lumina/theme.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final DatabaseServices _databaseServices = DatabaseServices.instance;
  Future<_StatisticsViewData>? _statisticsFuture;
  final TooltipBehavior _tooltipBehavior = TooltipBehavior(enable: true);

  @override
  void initState() {
    super.initState();
    _statisticsFuture = _loadStatisticsData();
  }

  Future<_StatisticsViewData> _loadStatisticsData() async {
    final Map<String, dynamic> report = await _databaseServices
        .getProgressReportbyDateofAllBooks();
    final StreakState streakState = await HabitServices.instance
        .getStreakState();
    final DateTime now = DateTime.now();
    final Map<String, int> week = await _databaseServices.getPeriodSummary(
      HabitServices.dateKey(DateTime(now.year, now.month, now.day - 6)),
      HabitServices.dateKey(now),
    );
    final Map<String, int> lifetime = await _databaseServices
        .getLifetimeTotals();
    final int? bestHour = await _databaseServices.getBestReadingHour();
    final List<_HabitPoint> habitData =
        (await _databaseServices.getHabitChecks())
            .map(
              (row) => _HabitPoint(
                date: DateTime.parse(row['createdAt'] as String),
                score: row['score'] as int? ?? 0,
              ),
            )
            .toList();
    final int weeklyProgress = await _databaseServices.getWeeklyProgress();
    final double averageDailyProgress = await _databaseServices
        .getAverageDailyProgress();
    final int finishedBooks = await _databaseServices.getFinishedBooksCount();

    final List<String> dates = List<String>.from(
      report['dates'] as List<dynamic>? ?? <dynamic>[],
    );
    final List<int> progress = List<int>.from(
      report['progress'] as List<dynamic>? ?? <dynamic>[],
    );

    final int itemCount = dates.length < progress.length
        ? dates.length
        : progress.length;

    final List<_ReadingProgressPoint> chartData =
        List<_ReadingProgressPoint>.generate(itemCount, (int index) {
          return _ReadingProgressPoint(
            date: DateTime.parse(dates[index]),
            pagesReadPercent: progress[index],
          );
        });

    return _StatisticsViewData(
      chartData: chartData,
      streak: streakState.current,
      longestStreak: streakState.longest,
      weekSeconds: week['seconds']!,
      lifetimePages: lifetime['pages']!,
      bestHour: bestHour,
      habitData: habitData,
      weeklyProgress: weeklyProgress,
      averageDailyProgress: averageDailyProgress,
      finishedBooks: finishedBooks,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.5,
                  colors: [Color(0xFF13311F), LuminaColors.background],
                ),
              ),
            ),
          ),
          SafeArea(
            child: FutureBuilder<_StatisticsViewData>(
              future: _statisticsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Failed to load statistics.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return Center(
                    child: Text(
                      'No statistics available yet.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }

                final _StatisticsViewData stats = snapshot.data!;
                final List<_ReadingProgressPoint> data = stats.chartData;
                if (data.isEmpty) {
                  return Center(
                    child: Text(
                      'No reading progress yet.\nAdd a few book updates to see your chart.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }

                final DateTime minDate = data.first.date.subtract(
                  const Duration(days: 1),
                );
                final DateTime maxDate = data.last.date.add(
                  const Duration(days: 1),
                );

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    SizedBox(
                      child: GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.1,
                        children: [
                          _StatTile(
                            icon: Icons.local_fire_department_rounded,
                            label: 'Streak',
                            value: '${stats.streak}',
                            detail: 'days',
                          ),
                          _StatTile(
                            icon: Icons.show_chart_rounded,
                            label: '7-Day Progress',
                            value: '${stats.weeklyProgress}',
                            detail: '%',
                          ),
                          _StatTile(
                            icon: Icons.analytics_rounded,
                            label: 'Daily Average',
                            value: stats.averageDailyProgress.toStringAsFixed(
                              1,
                            ),
                            detail: '%',
                          ),
                          _StatTile(
                            icon: Icons.menu_book_rounded,
                            label: 'Books Finished',
                            value: '${stats.finishedBooks}',
                            detail: 'books',
                          ),
                          _StatTile(
                            icon: Icons.emoji_events_rounded,
                            label: 'Longest Streak',
                            value: '${stats.longestStreak}',
                            detail: 'days',
                          ),
                          _StatTile(
                            icon: Icons.timer_rounded,
                            label: '7-Day Time',
                            value: HabitServices.formatDuration(
                              stats.weekSeconds,
                            ),
                            detail: 'read',
                          ),
                          _StatTile(
                            icon: Icons.schedule_rounded,
                            label: 'Usual Hour',
                            value: stats.bestHour == null
                                ? '-'
                                : '${stats.bestHour}:00',
                            detail: 'most entries',
                          ),
                          _StatTile(
                            icon: Icons.auto_stories_rounded,
                            label: 'Lifetime',
                            value: '${stats.lifetimePages}',
                            detail: 'pages',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 320,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: LuminaDecorations.card,
                        child: SfCartesianChart(
                          backgroundColor: Colors.transparent,
                          plotAreaBorderWidth: 0,
                          tooltipBehavior: _tooltipBehavior,
                          title: ChartTitle(
                            text: 'Reading Progress by Day',
                            textStyle: Theme.of(context).textTheme.titleMedium,
                          ),
                          primaryXAxis: DateTimeAxis(
                            intervalType: DateTimeIntervalType.days,
                            minimum: minDate,
                            maximum: maxDate,
                            dateFormat: DateFormat.MMMd(),
                            edgeLabelPlacement: EdgeLabelPlacement.shift,
                            majorGridLines: const MajorGridLines(width: 0),
                            axisLine: const AxisLine(width: 0),
                            labelStyle: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: LuminaColors.neutral),
                          ),
                          primaryYAxis: NumericAxis(
                            minimum: 0,
                            axisLine: const AxisLine(width: 0),
                            majorGridLines: MajorGridLines(
                              width: 0.8,
                              color: LuminaColors.borderSoft,
                            ),
                            labelStyle: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: LuminaColors.neutral),
                            title: AxisTitle(
                              text: 'Progress Logged',
                              textStyle: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: LuminaColors.neutral),
                            ),
                          ),
                          series:
                              <
                                CartesianSeries<_ReadingProgressPoint, DateTime>
                              >[
                                LineSeries<_ReadingProgressPoint, DateTime>(
                                  dataSource: data,
                                  xValueMapper:
                                      (_ReadingProgressPoint point, _) =>
                                          point.date,
                                  yValueMapper:
                                      (_ReadingProgressPoint point, _) =>
                                          point.pagesReadPercent,
                                  color: LuminaColors.accent,
                                  width: 3,
                                  markerSettings: const MarkerSettings(
                                    isVisible: true,
                                    width: 7,
                                    height: 7,
                                    borderWidth: 2,
                                    color: LuminaColors.accent,
                                    borderColor: LuminaColors.background,
                                  ),
                                ),
                              ],
                        ),
                      ),
                    ),
                    if (stats.habitData.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        height: 260,
                        padding: const EdgeInsets.all(20),
                        decoration: LuminaDecorations.card,
                        child: SfCartesianChart(
                          backgroundColor: Colors.transparent,
                          plotAreaBorderWidth: 0,
                          title: ChartTitle(
                            text: 'Habit Strength',
                            textStyle: Theme.of(context).textTheme.titleMedium,
                          ),
                          primaryXAxis: DateTimeAxis(
                            dateFormat: DateFormat.MMMd(),
                            majorGridLines: const MajorGridLines(width: 0),
                            axisLine: const AxisLine(width: 0),
                            labelStyle: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: LuminaColors.neutral),
                          ),
                          primaryYAxis: NumericAxis(
                            minimum: 4,
                            maximum: 28,
                            axisLine: const AxisLine(width: 0),
                            majorGridLines: MajorGridLines(
                              width: 0.8,
                              color: LuminaColors.borderSoft,
                            ),
                            labelStyle: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: LuminaColors.neutral),
                          ),
                          series: <CartesianSeries<_HabitPoint, DateTime>>[
                            LineSeries<_HabitPoint, DateTime>(
                              dataSource: stats.habitData,
                              xValueMapper: (_HabitPoint point, _) =>
                                  point.date,
                              yValueMapper: (_HabitPoint point, _) =>
                                  point.score,
                              color: LuminaColors.accent,
                              width: 3,
                              markerSettings: const MarkerSettings(
                                isVisible: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadingProgressPoint {
  const _ReadingProgressPoint({
    required this.date,
    required this.pagesReadPercent,
  });

  final DateTime date;
  final int pagesReadPercent;
}

class _HabitPoint {
  const _HabitPoint({required this.date, required this.score});

  final DateTime date;
  final int score;
}

class _StatisticsViewData {
  const _StatisticsViewData({
    required this.chartData,
    required this.streak,
    required this.longestStreak,
    required this.weekSeconds,
    required this.lifetimePages,
    required this.bestHour,
    required this.habitData,
    required this.weeklyProgress,
    required this.averageDailyProgress,
    required this.finishedBooks,
  });

  final List<_ReadingProgressPoint> chartData;
  final int streak;
  final int longestStreak;
  final int weekSeconds;
  final int lifetimePages;
  final int? bestHour;
  final List<_HabitPoint> habitData;
  final int weeklyProgress;
  final double averageDailyProgress;
  final int finishedBooks;
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: LuminaDecorations.card,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: LuminaColors.accent, size: 22),
          const SizedBox(height: 14),
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          Text(detail, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
