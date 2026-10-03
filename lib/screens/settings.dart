import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lumina/services/database_services.dart';
import 'package:lumina/services/habit_services.dart';
import 'package:lumina/services/home_widget_service.dart';
import 'package:lumina/services/notifications_center.dart';
import 'package:lumina/theme.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  static const List<int> _goalOptions = <int>[5, 10, 15, 20, 30, 45, 60];

  final DatabaseServices _databaseServices = DatabaseServices.instance;
  int _goalMinutes = HabitServices.defaultGoalMinutes;
  bool _remindersEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final int goalMinutes = await HabitServices.instance.getGoalMinutes();
    final bool remindersEnabled =
        await _databaseServices.getSetting('remindersEnabled') != '0';
    if (!mounted) {
      return;
    }
    setState(() {
      _goalMinutes = goalMinutes;
      _remindersEnabled = remindersEnabled;
    });
  }

  Future<void> _setGoal(int minutes) async {
    setState(() {
      _goalMinutes = minutes;
    });
    await _databaseServices.setSetting('dailyGoalMinutes', '$minutes');
    await HomeWidgetService.update();
  }

  Future<void> _setReminders(bool enabled) async {
    setState(() {
      _remindersEnabled = enabled;
    });
    await _databaseServices.setSetting('remindersEnabled', enabled ? '1' : '0');
    await NotificationsCenter.instance.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Daily goal', style: textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Keep it small. Any reading keeps your streak; the goal only fills the ring.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final int minutes in _goalOptions)
                ChoiceChip(
                  label: Text('$minutes min'),
                  selected: _goalMinutes == minutes,
                  showCheckmark: false,
                  onSelected: (_) => _setGoal(minutes),
                ),
            ],
          ),
          const SizedBox(height: 28),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Reading plan'),
            subtitle: const Text('When, where, and what to do when it slips'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => GoRouter.of(context).push('/plan'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Weekly review'),
            subtitle: const Text('Last 7 days and how automatic reading feels'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => GoRouter.of(context).push('/review'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Daily reminder'),
            subtitle: Text(
              NotificationsCenter.instance.supported
                  ? 'One a day at most, only if you have not read yet'
                  : 'Reminders only run on the phone',
            ),
            value: _remindersEnabled,
            activeThumbColor: LuminaColors.accent,
            onChanged: NotificationsCenter.instance.supported
                ? _setReminders
                : null,
          ),
          if (NotificationsCenter.instance.supported)
            TextButton(
              onPressed: () => NotificationsCenter.instance.showTest(),
              child: const Text('Send a test reminder'),
            ),
        ],
      ),
    );
  }
}
