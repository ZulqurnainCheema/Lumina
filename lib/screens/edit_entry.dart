import 'package:flutter/material.dart';
import 'package:lumina/models/entries.dart';
import 'package:lumina/services/database_services.dart';
import 'package:lumina/services/home_widget_service.dart';
import 'package:lumina/services/notifications_center.dart';
import 'package:lumina/theme.dart';

class EditEntry extends StatefulWidget {
  const EditEntry({super.key, required this.id});

  final int id;

  @override
  State<EditEntry> createState() => _EditEntryState();
}

class _EditEntryState extends State<EditEntry> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseServices _databaseServices = DatabaseServices.instance;
  final TextEditingController _pagesController = TextEditingController();
  final TextEditingController _minutesController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _hookController = TextEditingController();
  bool _loaded = false;

  TextStyle? get _fieldTextStyle => Theme.of(context).textTheme.bodyMedium
      ?.copyWith(color: LuminaColors.white, fontWeight: FontWeight.w500);

  @override
  void initState() {
    super.initState();
    _loadEntry();
  }

  Future<void> _loadEntry() async {
    final Entries? entry = await _databaseServices.getEntry(widget.id);
    if (!mounted || entry == null) {
      return;
    }
    setState(() {
      _pagesController.text = '${entry.pagesRead ?? 0}';
      _minutesController.text =
          '${((entry.durationSeconds ?? 0) / 60).round()}';
      _summaryController.text = entry.summary;
      _hookController.text = entry.hook ?? '';
      _loaded = true;
    });
  }

  String? _validateNumber(String? value, int max) {
    final int? number = int.tryParse((value ?? '').trim());
    if (number == null || number < 0 || number > max) {
      return 'Please enter a number between 0 and $max';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    await _databaseServices.editEntry(widget.id, {
      'pagesRead': int.parse(_pagesController.text.trim()),
      'durationSeconds': int.parse(_minutesController.text.trim()) * 60,
      'summary': _summaryController.text.trim(),
      'hook': _hookController.text.trim(),
    });
    await NotificationsCenter.instance.refresh();
    await HomeWidgetService.update();
    if (!mounted) {
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Edit session', style: textTheme.displayLarge),
                        const SizedBox(height: 8),
                        Text(
                          'Changing the pages moves your bookmark by the '
                          'same amount.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: LuminaColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _pagesController,
                          style: _fieldTextStyle,
                          decoration: const InputDecoration(
                            labelText: 'Pages read in this session',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) => _validateNumber(value, 5000),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _minutesController,
                          style: _fieldTextStyle,
                          decoration: const InputDecoration(
                            labelText: 'Minutes read',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) => _validateNumber(value, 600),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _summaryController,
                          style: _fieldTextStyle,
                          decoration: const InputDecoration(
                            labelText: 'One thing worth keeping',
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _hookController,
                          style: _fieldTextStyle,
                          decoration: const InputDecoration(
                            labelText: 'Your open question',
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: _save,
                          child: const Text('Save changes'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
