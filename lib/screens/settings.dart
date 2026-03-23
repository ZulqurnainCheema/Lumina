import 'package:flutter/material.dart';
import 'package:lumina/notifications.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () {
          Notifications().showNotification(
            'Test Notification',
            'This is a test notification from Lumina!',
          );
        },
        child: Text('Test notifications'),
      ),
    );
  }
}
