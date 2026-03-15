class Entries {
  final int? id;
  final int bookId;
  final int percentageRead;
  final String content;
  final String? createdAt;
  Entries({
    this.id,
    required this.bookId,
    required this.percentageRead,
    required this.content,
    this.createdAt,
  });
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'percentageRead': percentageRead,
      'summary': content,
      'createdAt': createdAt,
    };
  }
}
