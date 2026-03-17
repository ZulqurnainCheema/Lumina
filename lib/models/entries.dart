class Entries {
  final int? id;
  final int bookId;
  final int percentageRead;
  final String summary;
  final String? createdAt;
  Entries({
    this.id,
    required this.bookId,
    required this.percentageRead,
    required this.summary,
    this.createdAt,
  });
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'percentageRead': percentageRead,
      'summary': summary,
      'createdAt': createdAt,
    };
  }
}
