import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:lumina/services/habit_services.dart';

class HomeWidgetService {
  static const String _androidProvider = 'LuminaWidgetProvider';
  static const String _androidStreakProvider = 'LuminaStreakWidgetProvider';

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> update() async {
    if (!supported) {
      return;
    }
    try {
      final TodayData today = await HabitServices.instance.getToday();
      final int goalSeconds = today.goalMinutes * 60;
      await HomeWidget.saveWidgetData<String>(
        'streak',
        '${today.streak.current}',
      );
      await HomeWidget.saveWidgetData<int>(
        'progress',
        (today.secondsToday * 100 ~/ goalSeconds).clamp(0, 100),
      );
      await HomeWidget.saveWidgetData<String>(
        'minutes',
        '${today.secondsToday ~/ 60} of ${today.goalMinutes} min',
      );
      await HomeWidget.saveWidgetData<String>(
        'book',
        today.book?.title ?? 'Add a book',
      );
      await HomeWidget.saveWidgetData<String>(
        'hook',
        today.hook ?? 'Tap to read.',
      );
      await HomeWidget.saveWidgetData<String>('week', weekCode(today.week));
      await HomeWidget.saveWidgetData<String>(
        'weekLabels',
        today.week.map((day) => DateFormat('E').format(day.date)[0]).join(),
      );
      await HomeWidget.saveWidgetData<String>(
        'streakStatus',
        streakStatus(today.streak),
      );
      await HomeWidget.updateWidget(androidName: _androidProvider);
      await HomeWidget.updateWidget(androidName: _androidStreakProvider);
    } catch (error) {
      debugPrint('HomeWidgetService: update failed: $error');
    }
  }

  // One letter per day for the streak widget, oldest first:
  // r read, s saved by a freeze or repair, m missed, o still open today.
  @visibleForTesting
  static String weekCode(List<WeekDay> week) {
    return week
        .map(
          (day) => switch (day.state) {
            DayState.read => 'r',
            DayState.saved => 's',
            DayState.missed => 'm',
            DayState.open => 'o',
          },
        )
        .join();
  }

  @visibleForTesting
  static String streakStatus(StreakState streak) {
    if (streak.repairAvailable) {
      return 'Repair today';
    }
    if (!streak.readToday && streak.current > 0) {
      return 'Read today to keep it';
    }
    if (streak.freezes > 0) {
      return '${streak.freezes} freeze${streak.freezes == 1 ? '' : 's'} banked';
    }
    return '';
  }

  // True when the app was opened by tapping the "today" widget, which goes
  // straight into a reading session. The streak widget just opens the app.
  static Future<bool> launchedFromWidget() async {
    if (!supported) {
      return false;
    }
    try {
      final Uri? uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      return uri?.host == 'read';
    } catch (_) {
      return false;
    }
  }
}
