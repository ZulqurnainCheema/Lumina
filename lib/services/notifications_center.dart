import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:lumina/services/database_services.dart';
import 'package:lumina/services/habit_services.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class ReminderMessage {
  const ReminderMessage(this.title, this.body);

  final String title;
  final String body;
}

class NotificationsCenter {
  NotificationsCenter._();

  static final NotificationsCenter instance = NotificationsCenter._();

  static const int _reminderBaseId = 1000;
  static const int _daysToPreSchedule = 7;
  static const int _leadMinutes = 15;
  static const int _defaultMinuteOfDay = 20 * 60;
  static const int _responseWindowHours = 2;
  static const int _ignoredBeforeFading = 5;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final DatabaseServices _databaseServices = DatabaseServices.instance;
  bool _initialized = false;

  bool get supported {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> initialize() async {
    if (_initialized || !supported) {
      return;
    }

    tz_data.initializeTimeZones();
    await _configureLocalTimezone();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);
    await _requestPermissions();
    _initialized = true;
  }

  // Reschedules the next week of reminders: one a day at most, none today once
  // you have read, and every other day once they are being ignored.
  Future<void> refresh({DateTime? now}) async {
    if (!supported) {
      return;
    }
    try {
      await initialize();
      await _plugin.cancelAll();

      if (await _databaseServices.getSetting('remindersEnabled') == '0') {
        return;
      }

      final DateTime clock = now ?? DateTime.now();
      final List<DateTime> recentEntries = await _databaseServices
          .getRecentEntryTimes(limit: 50);
      final List<String> waiting = await _settleHistory(clock, recentEntries);
      final List<bool> history = await _loadHistory();
      final int step = countIgnored(history) >= _ignoredBeforeFading ? 2 : 1;

      final int minuteOfDay = reminderMinuteOfDay(recentEntries);
      final DateTime? lastRead = recentEntries.isEmpty
          ? null
          : recentEntries.first;
      final bool readToday =
          lastRead != null &&
          HabitServices.dateKey(lastRead) == HabitServices.dateKey(clock);
      final List<ReminderMessage> messages = buildMessages(
        await HabitServices.instance.getToday(now: clock),
        await _databaseServices.getSetting('planResponse'),
      );

      final List<String> scheduled = <String>[];
      for (
        int offset = readToday ? 1 : 0;
        offset < _daysToPreSchedule;
        offset += step
      ) {
        final DateTime time = DateTime(
          clock.year,
          clock.month,
          clock.day + offset,
          minuteOfDay ~/ 60,
          minuteOfDay % 60,
        );
        if (!time.isAfter(clock)) {
          continue;
        }
        // A reminder that fires two days after the last entry means a day
        // was missed in between.
        final bool afterMiss =
            lastRead != null &&
            time.difference(lastRead).inHours >= 48 - _responseWindowHours;
        final ReminderMessage message = afterMiss
            ? const ReminderMessage(
                'Life happened',
                'One page tonight and you are back. Coming back is the habit.',
              )
            : messages[_dayNumber(time) % messages.length];

        await _plugin.zonedSchedule(
          _reminderBaseId + offset,
          message.title,
          message.body,
          tz.TZDateTime.from(time, tz.local),
          _notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
        scheduled.add(time.toIso8601String());
      }

      await _databaseServices.setSetting(
        'reminderSchedule',
        <String>[...waiting, ...scheduled].join(','),
      );
    } catch (error) {
      debugPrint('NotificationsCenter: refresh failed: $error');
    }
  }

  Future<void> showTest() async {
    await initialize();
    final List<ReminderMessage> messages = buildMessages(
      await HabitServices.instance.getToday(),
      await _databaseServices.getSetting('planResponse'),
    );
    await _plugin.show(
      0,
      messages.first.title,
      messages.first.body,
      _notificationDetails,
    );
  }

  // Median time of day of recent entries, a little earlier.
  @visibleForTesting
  static int reminderMinuteOfDay(List<DateTime> entries) {
    if (entries.isEmpty) {
      return _defaultMinuteOfDay;
    }
    final List<int> minutes =
        entries
            .take(14)
            .map((entry) => (entry.hour * 60) + entry.minute)
            .toList()
          ..sort();
    final int median = minutes[minutes.length ~/ 2] - _leadMinutes;
    return ((median % _minutesPerDay) + _minutesPerDay) % _minutesPerDay;
  }

  // Reminders are written from your own data. Consecutive days rotate
  // through them, so the same one never fires twice in a row.
  @visibleForTesting
  static List<ReminderMessage> buildMessages(
    TodayData today,
    String? planResponse,
  ) {
    final List<ReminderMessage> messages = <ReminderMessage>[];
    final String? title = today.book?.title;
    if (title != null && today.hook != null) {
      messages.add(ReminderMessage(title, 'You wanted to know: ${today.hook}'));
    }
    if (title != null && today.pagesLeft != null) {
      final String time = today.secondsLeft == null
          ? ''
          : ', about ${HabitServices.formatDuration(today.secondsLeft!)}';
      messages.add(
        ReminderMessage(title, '${today.pagesLeft} pages left$time.'),
      );
    }
    if (today.streak.current > 0) {
      final int freezes = today.streak.freezes;
      messages.add(
        ReminderMessage(
          'Day ${today.streak.current + 1} is waiting',
          freezes > 0
              ? 'One page keeps the streak. $freezes freeze${freezes == 1 ? '' : 's'} banked.'
              : 'One page keeps the streak.',
        ),
      );
    }
    if (today.plan != null) {
      final String response = (planResponse ?? '').trim();
      messages.add(
        ReminderMessage(
          today.plan!,
          response.isEmpty ? 'This is the moment.' : 'Then: $response.',
        ),
      );
    }
    if (messages.isEmpty) {
      messages.add(
        const ReminderMessage(
          'Your book is waiting',
          'Open it and read one page.',
        ),
      );
    }
    return messages;
  }

  // Number of most recent reminders that led to no reading.
  @visibleForTesting
  static int countIgnored(List<bool> history) {
    int ignored = 0;
    for (final bool answered in history.reversed) {
      if (answered) {
        break;
      }
      ignored++;
    }
    return ignored;
  }

  // Moves reminders that already fired into the history, marking whether an
  // entry followed within the response window. Returns the ones still inside
  // that window.
  Future<List<String>> _settleHistory(
    DateTime clock,
    List<DateTime> entries,
  ) async {
    final String stored =
        await _databaseServices.getSetting('reminderSchedule') ?? '';
    final List<bool> history = await _loadHistory();
    final List<String> waiting = <String>[];

    for (final String value in stored.split(',')) {
      final DateTime? firedAt = DateTime.tryParse(value);
      if (firedAt == null || firedAt.isAfter(clock)) {
        continue;
      }
      final DateTime windowEnd = firedAt.add(
        const Duration(hours: _responseWindowHours),
      );
      final bool answered = entries.any(
        (entry) => !entry.isBefore(firedAt) && !entry.isAfter(windowEnd),
      );
      if (!answered && windowEnd.isAfter(clock)) {
        waiting.add(value);
        continue;
      }
      history.add(answered);
    }

    final List<bool> trimmed = history.length > 14
        ? history.sublist(history.length - 14)
        : history;
    await _databaseServices.setSetting(
      'reminderHistory',
      trimmed.map((answered) => answered ? '1' : '0').join(),
    );
    return waiting;
  }

  Future<List<bool>> _loadHistory() async {
    final String stored =
        await _databaseServices.getSetting('reminderHistory') ?? '';
    return stored.split('').map((value) => value == '1').toList();
  }

  int _dayNumber(DateTime time) {
    return DateTime.utc(
      time.year,
      time.month,
      time.day,
    ).difference(DateTime.utc(2020)).inDays;
  }

  Future<void> _configureLocalTimezone() async {
    try {
      final String timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
      debugPrint(
        'NotificationsCenter: timezone lookup failed, falling back to UTC',
      );
    }
  }

  Future<void> _requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();

    final IOSFlutterLocalNotificationsPlugin? iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);
  }

  NotificationDetails get _notificationDetails {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'reading_habit_channel',
          'Reading Habit',
          channelDescription:
              'One reminder a day, written from your own reading notes.',
          importance: Importance.high,
          priority: Priority.high,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    return const NotificationDetails(android: androidDetails, iOS: iosDetails);
  }
}

const int _minutesPerDay = 24 * 60;
