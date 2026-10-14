import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:lumina/services/cover_services.dart';
import 'package:lumina/services/habit_services.dart';
import 'package:lumina/theme.dart';
import 'package:lumina/widgets/streak_card.dart';
import 'package:lumina/widgets/today_widget_card.dart';

class HomeWidgetService {
  static const String _androidProvider = 'LuminaWidgetProvider';
  static const String _androidStreakProvider = 'LuminaStreakWidgetProvider';
  static const Size _streakCardSize = Size(372, 236);

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
        today.streak.readToday && today.secondsToday == 0
            ? 'Read today'
            : '${today.secondsToday ~/ 60} of ${today.goalMinutes} min',
      );
      await HomeWidget.saveWidgetData<String>(
        'book',
        today.book?.title ?? 'Add a book',
      );
      await HomeWidget.saveWidgetData<String>(
        'hook',
        today.hook ?? 'Tap to read.',
      );
      // The day this was written, so the widgets can tell when it is stale.
      await HomeWidget.saveWidgetData<String>(
        'widgetDate',
        HabitServices.dateKey(DateTime.now()),
      );
      await HomeWidget.saveWidgetData<int>('goalMinutes', today.goalMinutes);
      await HomeWidget.saveWidgetData<String>('week', weekCode(today.week));
      await HomeWidget.saveWidgetData<String>(
        'weekLabels',
        today.week.map((day) => DateFormat('E').format(day.date)[0]).join(),
      );
      await HomeWidget.saveWidgetData<String>(
        'streakStatus',
        streakStatus(today.streak),
      );
      await _renderStreakCard(today);
      await _renderTodayCard(today);
      await HomeWidget.updateWidget(androidName: _androidProvider);
      await HomeWidget.updateWidget(androidName: _androidStreakProvider);
    } catch (error) {
      debugPrint('HomeWidgetService: update failed: $error');
    }
  }

  // Home-screen widgets cannot run Flutter, so the real streak card is drawn
  // to an image here and the widget shows that image.
  static Future<void> _renderStreakCard(TodayData today) async {
    try {
      await GoogleFonts.pendingFonts();
      await HomeWidget.renderFlutterWidget(
        Theme(
          data: LuminaTheme.dark(),
          child: SizedBox(
            width: _streakCardSize.width,
            child: StreakCard(today: today, showWhy: false),
          ),
        ),
        key: 'streakCard',
        logicalSize: _streakCardSize,
        pixelRatio: 3,
      );
    } catch (error) {
      // The widget falls back to its plain layout when there is no image.
      debugPrint('HomeWidgetService: streak card render failed: $error');
    }
  }

  static Future<void> _renderTodayCard(TodayData today) async {
    try {
      await GoogleFonts.pendingFonts();
      final ui.Image? cover = today.book == null
          ? null
          : await loadCover(today.book!.coverUrl);
      await HomeWidget.renderFlutterWidget(
        Theme(
          data: LuminaTheme.dark(),
          child: TodayWidgetCard(today: today, cover: cover),
        ),
        key: 'todayCard',
        logicalSize: TodayWidgetCard.size,
        pixelRatio: 3,
      );
    } catch (error) {
      debugPrint('HomeWidgetService: today card render failed: $error');
    }
  }

  // The cover as a decoded image. Web covers are fetched once and kept in
  // the covers folder; stored covers are read from disk. Null when there is
  // no usable image, in which case the generated cover is drawn instead.
  static Future<ui.Image?> loadCover(String coverUrl) async {
    try {
      final Uint8List? bytes = await _coverBytes(coverUrl);
      if (bytes == null) {
        return null;
      }
      return await decodeImageFromList(bytes);
    } catch (error) {
      debugPrint('HomeWidgetService: cover load failed: $error');
      return null;
    }
  }

  static Future<Uint8List?> _coverBytes(String coverUrl) async {
    if (CoverServices.isStoredCover(coverUrl)) {
      final File file = File(coverUrl);
      return await file.exists() ? file.readAsBytes() : null;
    }
    if (!coverUrl.startsWith('http')) {
      return null;
    }
    final Directory directory = await CoverServices.instance.coversDirectory();
    final File cached = File(
      '${directory.path}/remote-${cacheName(coverUrl)}.jpg',
    );
    if (await cached.exists()) {
      return cached.readAsBytes();
    }
    final Response<List<int>> response = await Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        responseType: ResponseType.bytes,
      ),
    ).get<List<int>>(coverUrl);
    final Uint8List bytes = Uint8List.fromList(response.data ?? <int>[]);
    if (bytes.isEmpty) {
      return null;
    }
    await cached.writeAsBytes(bytes, flush: true);
    return bytes;
  }

  // A short, stable file name for a web address.
  @visibleForTesting
  static String cacheName(String url) {
    final int hash = url.codeUnits.fold<int>(
      5381,
      (int hash, int unit) => ((hash * 33) ^ unit) & 0xFFFFFFFF,
    );
    return '${url.length}-${hash.toRadixString(16)}';
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
