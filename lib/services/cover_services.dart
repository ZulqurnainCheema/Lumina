import 'package:dio/dio.dart';

// Looks up a book's cover on Open Library (openlibrary.org), which is free
// and needs no account.
class CoverServices {
  static final CoverServices instance = CoverServices._constructor();

  CoverServices._constructor();

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
