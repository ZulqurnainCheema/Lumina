import 'dart:convert';
import 'dart:io';

import 'package:lumina/services/cover_services.dart';
import 'package:lumina/services/database_services.dart';
import 'package:sqflite/sqflite.dart';

class BackupSummary {
  const BackupSummary({
    required this.books,
    required this.entries,
    required this.createdAt,
  });

  final int books;
  final int entries;
  final DateTime? createdAt;
}

// One JSON file holding everything the app stores, so it can be kept
// anywhere (Google Drive, email, a USB stick) and restored on any device.
class BackupServices {
  static final BackupServices instance = BackupServices._constructor();

  BackupServices._constructor();

  static const String _appName = 'lumina';
  static const int _formatVersion = 1;
  static const List<String> _tables = <String>[
    'books',
    'entries',
    'settings',
    'streak_events',
    'habit_checks',
  ];

  // State that only makes sense on the device it was written on.
  static const List<String> _deviceOnlySettings = <String>[
    'sessionBookId',
    'sessionStartedAt',
    'sessionAccumulated',
    'reminderSchedule',
    'reminderHistory',
  ];

  final DatabaseServices _databaseServices = DatabaseServices.instance;

  String fileName({DateTime? now}) {
    final DateTime clock = now ?? DateTime.now();
    final String month = clock.month.toString().padLeft(2, '0');
    final String day = clock.day.toString().padLeft(2, '0');
    return 'lumina-backup-${clock.year}-$month-$day.json';
  }

  Future<String> exportJson({DateTime? now}) async {
    final Database db = await _databaseServices.database;
    final Map<String, dynamic> backup = <String, dynamic>{
      'app': _appName,
      'formatVersion': _formatVersion,
      'createdAt': (now ?? DateTime.now()).toIso8601String(),
    };
    for (final String table in _tables) {
      backup[table] = await db.query(table);
    }
    backup['settings'] = (backup['settings'] as List<Map<String, dynamic>>)
        .where((row) => !_deviceOnlySettings.contains(row['key']))
        .toList();
    // Covers chosen from the gallery live in files, so they go in too.
    final Map<String, String> covers = <String, String>{};
    for (final Map<String, dynamic> book
        in backup['books'] as List<Map<String, dynamic>>) {
      final String coverUrl = book['coverUrl'] as String? ?? '';
      if (!CoverServices.isStoredCover(coverUrl)) {
        continue;
      }
      final File file = File(coverUrl);
      if (await file.exists()) {
        covers['${book['id']}'] = base64Encode(await file.readAsBytes());
      }
    }
    backup['covers'] = covers;
    return const JsonEncoder.withIndent('  ').convert(backup);
  }

  // Checks the file is a Lumina backup and says what is in it, without
  // changing anything.
  BackupSummary inspect(String json) {
    final Map<String, dynamic> backup = _decode(json);
    return BackupSummary(
      books: (backup['books'] as List<dynamic>).length,
      entries: (backup['entries'] as List<dynamic>).length,
      createdAt: DateTime.tryParse(backup['createdAt'] as String? ?? ''),
    );
  }

  // Replaces everything on this device with the backup. Either all of it is
  // restored or nothing changes.
  Future<BackupSummary> importJson(
    String json, {
    Directory? coversDirectory,
  }) async {
    final Map<String, dynamic> backup = _decode(json);
    final Database db = await _databaseServices.database;

    // Gallery covers get a path on this device; a cover whose file was
    // missing when the backup was made is dropped rather than left dangling.
    final Map<String, dynamic> covers =
        (backup['covers'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final Map<String, File> coverFiles = <String, File>{};
    final Directory? directory = covers.isEmpty
        ? null
        : coversDirectory ?? await CoverServices.instance.coversDirectory();
    for (final Map<String, dynamic> book
        in (backup['books'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      final String coverUrl = book['coverUrl'] as String? ?? '';
      if (!CoverServices.isStoredCover(coverUrl)) {
        continue;
      }
      final String id = '${book['id']}';
      if (covers.containsKey(id)) {
        coverFiles[id] = File('${directory!.path}/restored-$id.jpg');
        book['coverUrl'] = coverFiles[id]!.path;
      } else {
        book['coverUrl'] = '';
      }
    }

    await db.transaction((txn) async {
      // Entries go first so no entry is left pointing at a missing book.
      for (final String table in _tables.reversed) {
        await txn.delete(table);
      }
      for (final String table in _tables) {
        for (final dynamic row in backup[table] as List<dynamic>? ?? []) {
          await txn.insert(table, Map<String, dynamic>.from(row as Map));
        }
      }
    });
    for (final MapEntry<String, File> entry in coverFiles.entries) {
      await entry.value.writeAsBytes(
        base64Decode(covers[entry.key] as String),
        flush: true,
      );
    }
    return inspect(json);
  }

  Map<String, dynamic> _decode(String json) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      throw const FormatException('This file is not a Lumina backup.');
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['app'] != _appName ||
        decoded['books'] is! List ||
        decoded['entries'] is! List) {
      throw const FormatException('This file is not a Lumina backup.');
    }
    final int version = decoded['formatVersion'] as int? ?? 0;
    if (version > _formatVersion) {
      throw const FormatException(
        'This backup was made by a newer version of Lumina. Update the app '
        'to restore it.',
      );
    }
    return decoded;
  }
}
