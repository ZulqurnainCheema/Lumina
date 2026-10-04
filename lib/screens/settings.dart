import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lumina/services/backup_services.dart';
import 'package:lumina/services/database_services.dart';
import 'package:lumina/services/habit_services.dart';
import 'package:lumina/services/home_widget_service.dart';
import 'package:lumina/services/notifications_center.dart';
import 'package:lumina/theme.dart';
import 'package:lumina/widgets/lumina_sheet.dart';
import 'package:lumina/widgets/section_header.dart';

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

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // Opens the system "save to" screen, where Google Drive is one of the
  // places the file can go.
  Future<void> _saveBackup() async {
    try {
      final String json = await BackupServices.instance.exportJson();
      final Uri? saved = await FilePicker.saveFile(
        dialogTitle: 'Save Lumina backup',
        fileName: BackupServices.instance.fileName(),
        bytes: utf8.encode(json),
        mimeType: 'application/json',
        type: FileType.custom,
        allowedExtensions: <String>['json'],
      );
      if (saved != null) {
        _showMessage('Backup saved.');
      }
    } catch (error) {
      _showMessage('Could not save the backup.');
    }
  }

  Future<void> _restoreBackup() async {
    try {
      final PlatformFile? file = await FilePicker.pickFile(
        dialogTitle: 'Choose a Lumina backup',
      );
      if (file == null) {
        return;
      }
      final String json = utf8.decode(await file.readAsBytes());
      final BackupSummary summary = BackupServices.instance.inspect(json);
      if (!mounted) {
        return;
      }
      final String date = summary.createdAt == null
          ? ''
          : ' from ${HabitServices.dateKey(summary.createdAt!)}';
      final bool? confirmed = await showLuminaSheet(
        context,
        title: 'Replace everything on this device?',
        body:
            'The backup$date has ${summary.books} books and '
            '${summary.entries} sessions. Restoring it removes what is on '
            'this device now. This cannot be undone.',
        confirm: 'Restore backup',
        dismiss: 'Cancel',
      );
      if (confirmed != true) {
        return;
      }
      await BackupServices.instance.importJson(json);
      await NotificationsCenter.instance.refresh();
      await HomeWidgetService.update();
      await _loadSettings();
      _showMessage('Backup restored.');
    } on FormatException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage('Could not read that file.');
    }
  }

  Widget _buildLink({
    required String title,
    required String subtitle,
    required String route,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => GoRouter.of(context).push(route),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool remindersSupported = NotificationsCenter.instance.supported;
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text('Settings', style: textTheme.displayLarge),
          const SizedBox(height: 28),
          const SectionHeader(label: 'Daily goal', researchKey: 'freeze'),
          const SizedBox(height: 4),
          Text(
            'Keep it small. Any reading keeps your streak; the goal only '
            'fills the ring.',
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
          const SectionHeader(label: 'Reminder', researchKey: 'oneReminder'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Daily reminder'),
            subtitle: Text(
              remindersSupported
                  ? 'One a day at most, only if you have not read yet'
                  : 'Reminders only run on the phone',
            ),
            value: _remindersEnabled,
            activeThumbColor: LuminaColors.accent,
            onChanged: remindersSupported ? _setReminders : null,
          ),
          if (remindersSupported)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => NotificationsCenter.instance.showTest(),
                child: const Text('Send a test reminder'),
              ),
            ),
          const SizedBox(height: 20),
          const SectionHeader(label: 'Your routine'),
          _buildLink(
            title: 'Reading plan',
            subtitle: 'When, where, and what to do when it slips',
            route: '/plan',
          ),
          _buildLink(
            title: 'Weekly review',
            subtitle: 'Last 7 days and how automatic reading feels',
            route: '/review',
          ),
          const SizedBox(height: 20),
          const SectionHeader(label: 'Backup'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Save a backup'),
            subtitle: const Text(
              'One file with your books, sessions, notes and streak. Save it '
              'to Google Drive or anywhere else.',
            ),
            trailing: const Icon(Icons.upload_rounded),
            onTap: _saveBackup,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Restore from a backup'),
            subtitle: const Text(
              'Pick a backup file. It replaces what is on this device.',
            ),
            trailing: const Icon(Icons.download_rounded),
            onTap: _restoreBackup,
          ),
          const SizedBox(height: 20),
          const SectionHeader(label: 'About'),
          _buildLink(
            title: 'The science',
            subtitle: 'The studies each part of Lumina is built on',
            route: '/science',
          ),
        ],
      ),
    );
  }
}
