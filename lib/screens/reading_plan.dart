import 'package:flutter/material.dart';
import 'package:lumina/services/database_services.dart';
import 'package:lumina/theme.dart';
import 'package:lumina/widgets/section_header.dart';

class ReadingPlan extends StatefulWidget {
  const ReadingPlan({super.key});

  @override
  State<ReadingPlan> createState() => _ReadingPlanState();
}

class _ReadingPlanState extends State<ReadingPlan> {
  final DatabaseServices _databaseServices = DatabaseServices.instance;
  final TextEditingController _cueController = TextEditingController();
  final TextEditingController _placeController = TextEditingController();
  final TextEditingController _obstacleController = TextEditingController();
  final TextEditingController _responseController = TextEditingController();

  TextStyle? get _fieldTextStyle => Theme.of(context).textTheme.bodyMedium
      ?.copyWith(color: LuminaColors.white, fontWeight: FontWeight.w500);

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    _cueController.text = await _databaseServices.getSetting('planCue') ?? '';
    _placeController.text =
        await _databaseServices.getSetting('planPlace') ?? '';
    _obstacleController.text =
        await _databaseServices.getSetting('planObstacle') ?? '';
    _responseController.text =
        await _databaseServices.getSetting('planResponse') ?? '';
  }

  Future<void> _savePlan() async {
    await _databaseServices.setSetting('planCue', _cueController.text.trim());
    await _databaseServices.setSetting(
      'planPlace',
      _placeController.text.trim(),
    );
    await _databaseServices.setSetting(
      'planObstacle',
      _obstacleController.text.trim(),
    );
    await _databaseServices.setSetting(
      'planResponse',
      _responseController.text.trim(),
    );
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
      body: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('When will you read?', style: textTheme.displayLarge),
                const SizedBox(height: 8),
                Text(
                  'Pick something you already do every day and read right '
                  'after it.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: LuminaColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                const SectionHeader(label: 'Your moment', researchKey: 'cue'),
                const SizedBox(height: 8),
                TextField(
                  controller: _cueController,
                  style: _fieldTextStyle,
                  decoration: const InputDecoration(
                    labelText: 'After I...',
                    hintText: 'finish dinner, get into bed, make coffee',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _placeController,
                  style: _fieldTextStyle,
                  decoration: const InputDecoration(
                    labelText: 'I read in...',
                    hintText: 'the armchair, bed, the train',
                  ),
                ),
                const SizedBox(height: 28),
                const SectionHeader(
                  label: 'When something gets in the way',
                  researchKey: 'plan',
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _obstacleController,
                  style: _fieldTextStyle,
                  decoration: const InputDecoration(
                    labelText: 'If...',
                    hintText: 'I pick up my phone in bed',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _responseController,
                  style: _fieldTextStyle,
                  decoration: const InputDecoration(
                    labelText: 'Then I...',
                    hintText: 'put it on the desk and open the book',
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _savePlan,
                  child: const Text('Save plan'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
