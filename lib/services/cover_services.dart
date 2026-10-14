import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

// Finds or stores a book's cover: looked up on Open Library (openlibrary.org,
// free, no account), or a photo picked from the gallery and kept in the app's
// own folder.
class CoverServices {
  static final CoverServices instance = CoverServices._constructor();

  CoverServices._constructor();

  // Covers are shrunk to this width so they stay small enough to travel in a
  // backup.
  static const int coverWidth = 480;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  // Returns the cover's address, or null when no edition has one.
  Future<String?> findCover(String title, String author) async {
    for (final String variant in titleVariants(title)) {
      for (final String? byAuthor in <String?>[author.trim(), null]) {
        if (byAuthor != null && byAuthor.isEmpty) {
          continue;
        }
        final Response<dynamic> response = await _dio.get<dynamic>(
          'https://openlibrary.org/search.json',
          queryParameters: <String, dynamic>{
            'title': variant,
            'author': ?byAuthor,
            'fields': 'cover_i',
            'limit': 5,
          },
        );
        final String? cover = coverFromSearch(response.data);
        if (cover != null) {
          return cover;
        }
      }
    }
    return null;
  }

  // Opens the system picker (which includes the gallery), stores the chosen
  // photo as a cover and returns its path. Null if nothing was chosen.
  Future<String?> pickCoverFromGallery() async {
    final PlatformFile? file = await FilePicker.pickFile(
      dialogTitle: 'Choose a cover',
      type: FileType.image,
    );
    if (file == null) {
      return null;
    }
    return saveCover(await file.readAsBytes());
  }

  Future<Directory> coversDirectory() async {
    final Directory directory = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/covers',
    );
    await directory.create(recursive: true);
    return directory;
  }

  // Shrinks an image and writes it to the covers folder. Returns the file's
  // path, or null if the bytes are not an image.
  Future<String?> saveCover(
    Uint8List bytes, {
    Directory? directory,
    String? name,
  }) async {
    // Decoding a phone photo takes a moment, so it runs off the UI thread.
    final Uint8List? shrunk = await compute(shrinkToCover, bytes);
    if (shrunk == null) {
      return null;
    }
    final Directory target = directory ?? await coversDirectory();
    final File file = File(
      '${target.path}/${name ?? DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(shrunk, flush: true);
    return file.path;
  }

  // Deletes a cover file the app stored. Web addresses and the placeholder
  // are left alone.
  static Future<void> deleteStoredCover(String coverUrl) async {
    if (!isStoredCover(coverUrl)) {
      return;
    }
    final File file = File(coverUrl);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static bool isStoredCover(String coverUrl) => coverUrl.startsWith('/');

  // Resizes to the cover width and re-encodes as JPEG.
  static Uint8List? shrinkToCover(Uint8List bytes) {
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return null;
    }
    final img.Image resized = decoded.width > coverWidth
        ? img.copyResize(
            decoded,
            width: coverWidth,
            interpolation: img.Interpolation.average,
          )
        : decoded;
    return img.encodeJpg(resized, quality: 82);
  }

  // The full title first, then without its subtitle, which catalogues often
  // leave out ("Ancient Philosophy: A New History..." -> "Ancient Philosophy").
  static List<String> titleVariants(String title) {
    final String full = title.trim();
    final String short = full.split(RegExp(r'[:(\-–—]')).first.trim();
    return <String>[
      if (full.isNotEmpty) full,
      if (short.isNotEmpty && short != full) short,
    ];
  }

  // The first result that has a cover image.
  static String? coverFromSearch(dynamic data) {
    if (data is! Map || data['docs'] is! List) {
      return null;
    }
    for (final dynamic doc in data['docs'] as List<dynamic>) {
      if (doc is Map && doc['cover_i'] is int) {
        return 'https://covers.openlibrary.org/b/id/${doc['cover_i']}-L.jpg';
      }
    }
    return null;
  }
}
