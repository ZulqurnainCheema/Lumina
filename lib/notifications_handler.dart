import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:lumina/services/database_services.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationsHandler {
  NotificationsHandler._();

  static final NotificationsHandler instance = NotificationsHandler._();

  static const int _habitReminderBaseId = 1000;
  static const int _reengagementReminderBaseId = 2000;
  static const int _daysToPreSchedule = 7;
  static const int _staleThresholdHours = 24;
  static const int _leadMinutes = 90;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  bool get _supportsScheduledNotifications {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> initialize() async {
    if (_initialized || !_supportsScheduledNotifications) {
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

  Future<void> refreshSchedules() async {
    if (!_supportsScheduledNotifications) {
      return;
    }

    await initialize();
    await _plugin.cancelAll();

    final List<DateTime> recentEntries = await DatabaseServices.instance
        .getRecentEntryTimes();
    final DateTime? lastEntry = await DatabaseServices.instance
        .getLastEntryTime();

    if (recentEntries.isEmpty) {
      return;
    }

    final int reminderMinuteOfDay =
        _deriveReminderMinuteOfDay(recentEntries) - _leadMinutes;
    final int normalizedReminderMinute =
        ((reminderMinuteOfDay % _minutesPerDay) + _minutesPerDay) %
        _minutesPerDay;

    if (lastEntry == null ||
        DateTime.now().difference(lastEntry).inHours >= _staleThresholdHours) {
      await _scheduleReengagementSeries(normalizedReminderMinute);
      return;
    }

    await _scheduleHabitSeries(normalizedReminderMinute);
  }

  Future<void> _configureLocalTimezone() async {
    try {
      final String timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
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

  Future<void> _scheduleHabitSeries(int reminderMinuteOfDay) async {
    for (int offset = 0; offset < _daysToPreSchedule; offset++) {
      final tz.TZDateTime scheduledTime = _nextOccurrence(
        minuteOfDay: reminderMinuteOfDay,
        dayOffset: offset,
      );

      await _plugin.zonedSchedule(
        _habitReminderBaseId + offset,
        'Reading window is coming up',
        _habitMessageFor(offset),
        scheduledTime,
        _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> _scheduleReengagementSeries(int reminderMinuteOfDay) async {
    for (int offset = 0; offset < _daysToPreSchedule; offset++) {
      final tz.TZDateTime scheduledTime = _nextOccurrence(
        minuteOfDay: reminderMinuteOfDay,
        dayOffset: offset,
      );

      await _plugin.zonedSchedule(
        _reengagementReminderBaseId + offset,
        'A few pages is enough today',
        _reengagementMessageFor(offset),
        scheduledTime,
        _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  tz.TZDateTime _nextOccurrence({
    required int minuteOfDay,
    required int dayOffset,
  }) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    final int hour = minuteOfDay ~/ 60;
    final int minute = minuteOfDay % 60;

    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + dayOffset,
      hour,
      minute,
    );

    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  int _deriveReminderMinuteOfDay(List<DateTime> entries) {
    final List<int> minutes =
        entries.map((entry) => (entry.hour * 60) + entry.minute).toList()
          ..sort();
    return minutes[minutes.length ~/ 2];
  }

  String _habitMessageFor(int seed) {
    const List<String> messages = <String>[
      'Your usual reading window is getting close. Even ten minutes keeps the rhythm alive.',
      'This is a good time to open your book before the day gets crowded.',
      'A short reading session now makes tomorrow easier to return to.',
      'Pick up where you left off. You only need a small start today.',
    ];
    return messages[seed % messages.length];
  }

  String _reengagementMessageFor(int seed) {
    const List<String> messages = <String>[
      'You do not need a perfect session today. A few pages is enough to restart the habit.',
      'The hardest part is beginning again. Open the book and let the next minute do the rest.',
      'Reading momentum comes back through return, not pressure. Start small today.',
      'A single check-in today is enough to reconnect with your reading rhythm.',
    ];
    return messages[seed % messages.length];
  }

  NotificationDetails get _notificationDetails {
    const AndroidNotificationDetails
    androidDetails = AndroidNotificationDetails(
      'reading_habit_channel',
      'Reading Habit',
      channelDescription:
          'Adaptive reminders to support consistent reading and progress logging.',
      importance: Importance.high,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    return const NotificationDetails(android: androidDetails, iOS: iosDetails);
  }
}

const int _minutesPerDay = 24 * 60;
