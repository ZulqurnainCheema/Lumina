import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:lumina/services/database_services.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationsCenter {
  NotificationsCenter._();

  static final NotificationsCenter instance = NotificationsCenter._();

  static const int _habitReminderBaseId = 1000;
  static const int _reengagementReminderBaseId = 2000;
  static const int _daysToPreSchedule = 30;
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
      debugPrint(
        'NotificationsCenter: scheduled reminders are disabled on this platform.',
      );
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

  Future<void> refreshHabitReminders() async {
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
      debugPrint(
        'NotificationsCenter: skipped scheduling because no reading entries exist yet.',
      );
      return;
    }

    final int reminderMinuteOfDay =
        _deriveReminderMinuteOfDay(recentEntries) - _leadMinutes;
    final int normalizedReminderMinute =
        ((reminderMinuteOfDay % _minutesPerDay) + _minutesPerDay) %
        _minutesPerDay;

    final tz.TZDateTime? firstReengagementTime = lastEntry == null
        ? null
        : _firstOccurrenceOnOrAfter(
            minuteOfDay: normalizedReminderMinute,
            notBefore: lastEntry.add(
              const Duration(hours: _staleThresholdHours),
            ),
          );

    await _scheduleHabitSeries(
      normalizedReminderMinute,
      stopBefore: firstReengagementTime,
    );

    if (firstReengagementTime != null) {
      await _scheduleReengagementSeries(
        firstScheduledTime: firstReengagementTime,
      );
    }

    await _logPendingNotifications(
      normalizedReminderMinute: normalizedReminderMinute,
      firstReengagementTime: firstReengagementTime,
    );
  }

  Future<void> scheduleDailyNotification(String title, String body) async {
    await showNotification(title, body);
  }

  Future<void> showNotification(String title, String body) async {
    await initialize();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'reading_habit_channel',
          'Reading Habit',
          channelDescription:
              'Adaptive reminders to support consistent reading and progress logging.',
          importance: Importance.max,
          priority: Priority.high,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(0, title, body, details);
  }

  Future<List<PendingNotificationRequest>> pendingNotifications() async {
    await initialize();
    return _plugin.pendingNotificationRequests();
  }

  Future<void> _configureLocalTimezone() async {
    try {
      final String timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
      debugPrint('NotificationsCenter: using timezone $timezoneName');
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
    final bool? permissionGranted =
        await androidPlugin?.requestNotificationsPermission();
    final bool? notificationsEnabled =
        await androidPlugin?.areNotificationsEnabled();
    debugPrint(
      'NotificationsCenter: Android permission granted=$permissionGranted enabled=$notificationsEnabled',
    );

    final IOSFlutterLocalNotificationsPlugin? iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> _scheduleHabitSeries(
    int reminderMinuteOfDay, {
    required tz.TZDateTime? stopBefore,
  }) async {
    final tz.TZDateTime firstScheduledTime = _firstOccurrenceOnOrAfter(
      minuteOfDay: reminderMinuteOfDay,
      notBefore: DateTime.now(),
    );

    for (int offset = 0; offset < _daysToPreSchedule; offset++) {
      final tz.TZDateTime scheduledTime = firstScheduledTime.add(
        Duration(days: offset),
      );

      if (stopBefore != null && !scheduledTime.isBefore(stopBefore)) {
        break;
      }

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

  Future<void> _scheduleReengagementSeries({
    required tz.TZDateTime firstScheduledTime,
  }) async {
    for (int offset = 0; offset < _daysToPreSchedule; offset++) {
      final tz.TZDateTime scheduledTime = firstScheduledTime.add(
        Duration(days: offset),
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

  tz.TZDateTime _firstOccurrenceOnOrAfter({
    required int minuteOfDay,
    required DateTime notBefore,
  }) {
    final tz.TZDateTime anchor = tz.TZDateTime.from(notBefore, tz.local);
    final int hour = minuteOfDay ~/ 60;
    final int minute = minuteOfDay % 60;

    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      anchor.year,
      anchor.month,
      anchor.day,
      hour,
      minute,
    );

    if (!scheduled.isAfter(anchor)) {
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
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
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

  Future<void> _logPendingNotifications({
    required int normalizedReminderMinute,
    required tz.TZDateTime? firstReengagementTime,
  }) async {
    final List<PendingNotificationRequest> pendingRequests =
        await _plugin.pendingNotificationRequests();
    final String reminderTimeLabel = _formatMinuteOfDay(
      normalizedReminderMinute,
    );
    debugPrint(
      'NotificationsCenter: scheduled ${pendingRequests.length} reminder(s); '
      'habitTime=$reminderTimeLabel; '
      'firstReengagement=${firstReengagementTime?.toLocal()}',
    );
    for (final PendingNotificationRequest request in pendingRequests.take(6)) {
      debugPrint(
        'NotificationsCenter: pending id=${request.id} title=${request.title}',
      );
    }
  }

  String _formatMinuteOfDay(int minuteOfDay) {
    final int hours = minuteOfDay ~/ 60;
    final int minutes = minuteOfDay % 60;
    final String period = hours >= 12 ? 'PM' : 'AM';
    final int displayHour = hours % 12 == 0 ? 12 : hours % 12;
    final String paddedMinutes = minutes.toString().padLeft(2, '0');
    return '$displayHour:$paddedMinutes $period';
  }
}

const int _minutesPerDay = 24 * 60;
