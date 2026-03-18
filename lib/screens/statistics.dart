import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reading_assist/services/database_services.dart';
import 'package:reading_assist/theme.dart';
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
    final int streak = await _databaseServices.getDaysStreak();
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
      streak: streak,
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
                final DateTime minDate = data.first.date.subtract(
                  const Duration(days: 1),
                );
                final DateTime maxDate = data.last.date.add(
                  const Duration(days: 1),
                );

                if (data.isEmpty) {
                  return Center(
                    child: Text(
                      'No reading progress yet.\nAdd a few book updates to see your chart.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: GridView.count(
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.35,
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        flex: 4,
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
                              textStyle: Theme.of(
                                context,
                              ).textTheme.titleMedium,
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
                                  CartesianSeries<
                                    _ReadingProgressPoint,
                                    DateTime
                                  >
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
                    ],
                  ),
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

class _StatisticsViewData {
  const _StatisticsViewData({
    required this.chartData,
    required this.streak,
    required this.weeklyProgress,
    required this.averageDailyProgress,
    required this.finishedBooks,
  });

  final List<_ReadingProgressPoint> chartData;
  final int streak;
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
