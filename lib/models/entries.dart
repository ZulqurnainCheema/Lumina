class Entries {
  final int? id;
  final int bookId;
  final int percentageRead;
  final String summary;
  final String? createdAt;
  final int? pagesRead;
  final int? durationSeconds;
  final String? hook;
  final int? absorption;
  Entries({
    this.id,
    required this.bookId,
    required this.percentageRead,
    required this.summary,
    this.createdAt,
    this.pagesRead,
    this.durationSeconds,
    this.hook,
    this.absorption,
  });
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'percentageRead': percentageRead,
      'summary': summary,
      'createdAt': createdAt,
      'pagesRead': pagesRead,
      'durationSeconds': durationSeconds,
      'hook': hook,
      'absorption': absorption,
    };
  }
}
