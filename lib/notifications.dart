import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class Notifications {
  bool _initialized = false;

  bool get initialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('/assets/app_icon.png');

    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await FlutterLocalNotificationsPlugin().initialize(initializationSettings);
    _initialized = true;
  }

// notifications details 
  Future<NotificationDetails> _notificationDetails() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'your_channel_id',
      'your_channel_name',
      channelDescription: 'your_channel_description',
      importance: Importance.max,
      priority: Priority.high,
    );

    return const NotificationDetails(android: androidPlatformChannelSpecifics);
  }

  Future<void> showNotification(String title, String body) async {
    if (!_initialized) {
      await init();
    }

    final details = await _notificationDetails();
    await FlutterLocalNotificationsPlugin().show(0, title, body, details);
  }

  
}
