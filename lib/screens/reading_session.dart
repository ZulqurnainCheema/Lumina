import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lumina/models/books.dart';
import 'package:lumina/services/database_services.dart';
import 'package:lumina/theme.dart';

class ReadingSession extends StatefulWidget {
  const ReadingSession({super.key, required this.id});

  final int id;

  @override
  State<ReadingSession> createState() => _ReadingSessionState();
}

class _ReadingSessionState extends State<ReadingSession> {
  final DatabaseServices _databaseServices = DatabaseServices.instance;
  Books? _book;
  Timer? _ticker;
  DateTime? _startedAt;
  int _accumulatedSeconds = 0;

  bool get _running => _startedAt != null;

  int get _elapsedSeconds {
    final DateTime? startedAt = _startedAt;
    if (startedAt == null) {
      return _accumulatedSeconds;
    }
    return _accumulatedSeconds + DateTime.now().difference(startedAt).inSeconds;
  }

  @override
  void initState() {
    super.initState();
    _restoreOrStart();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _running) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // The session survives the app being closed while the phone is face down.
  Future<void> _restoreOrStart() async {
    final Books? book = await _databaseServices.getBook(widget.id);
    final int savedBookId = await _databaseServices.getIntSetting(
      'sessionBookId',
      -1,
    );
    DateTime? startedAt = DateTime.now();
    int accumulated = 0;
    if (savedBookId == widget.id) {
      accumulated = await _databaseServices.getIntSetting(
        'sessionAccumulated',
        0,
      );
      startedAt = DateTime.tryParse(
        await _databaseServices.getSetting('sessionStartedAt') ?? '',
      );
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _book = book;
      _startedAt = startedAt;
      _accumulatedSeconds = accumulated;
    });
    await _saveSession();
  }

  Future<void> _saveSession() async {
    await _databaseServices.setSetting('sessionBookId', '${widget.id}');
    await _databaseServices.setSetting(
      'sessionStartedAt',
      _startedAt?.toIso8601String() ?? '',
    );
    await _databaseServices.setSetting(
      'sessionAccumulated',
      '$_accumulatedSeconds',
    );
  }

  Future<void> _clearSession() async {
    await _databaseServices.setSetting('sessionBookId', '');
  }

  Future<void> _togglePause() async {
    setState(() {
      if (_running) {
        _accumulatedSeconds = _elapsedSeconds;
        _startedAt = null;
      } else {
        _startedAt = DateTime.now();
      }
    });
    await _saveSession();
  }

  Future<void> _finish() async {
    final int seconds = _elapsedSeconds;
    await _clearSession();
    if (!mounted) {
      return;
    }
    GoRouter.of(
      context,
    ).pushReplacement('/add-book-progress/${widget.id}', extra: seconds);
  }

  Future<void> _discard() async {
    if (_elapsedSeconds >= 60) {
      final bool? discard = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: LuminaColors.surface,
            title: const Text('Discard this session?'),
            content: Text(
              '${_elapsedSeconds ~/ 60} minutes of reading will not be saved.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep reading'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard'),
              ),
            ],
          );
        },
      );
      if (discard != true) {
        return;
      }
    }
    await _clearSession();
    if (!mounted) {
      return;
    }
    GoRouter.of(context).pop();
  }

  String _formatClock(int totalSeconds) {
    final int hours = totalSeconds ~/ 3600;
    final String minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(
      2,
      '0',
    );
    final String seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _discard();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: _discard,
                    tooltip: 'discard session',
                    icon: const Icon(Icons.close, color: LuminaColors.neutral),
                  ),
                ),
                const Spacer(),
                Text(
                  _book?.title ?? '',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Text(
                  _formatClock(_elapsedSeconds),
                  style: textTheme.displayLarge?.copyWith(
                    fontSize: 72,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: _running ? LuminaColors.white : LuminaColors.neutral,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Put the phone face down. The book is the screen now.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall,
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: _togglePause,
                  child: Text(_running ? 'Pause' : 'Resume'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _finish,
                  child: const Text('Done reading'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
