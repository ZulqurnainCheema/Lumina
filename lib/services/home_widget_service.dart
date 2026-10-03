import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:lumina/services/habit_services.dart';

class HomeWidgetService {
  static const String _androidProvider = 'LuminaWidgetProvider';

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
      await HomeWidget.updateWidget(androidName: _androidProvider);
    } catch (error) {
      debugPrint('HomeWidgetService: update failed: $error');
    }
  }

  // True when the app was opened by tapping the home-screen widget.
  static Future<bool> launchedFromWidget() async {
    if (!supported) {
      return false;
    }
    try {
      return await HomeWidget.initiallyLaunchedFromHomeWidget() != null;
    } catch (_) {
      return false;
    }
  }
}
