class Books {
  final int id;
  final String title;
  final String author;
  final String coverUrl;
  final int totalPages;
  final String status;
  final String? createdAt;
  final String? abandonedAt;
  Books({
    required this.id,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.totalPages,
    required this.status,
    this.createdAt,
    this.abandonedAt,
  });
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'coverUrl': coverUrl,
      'totalPages': totalPages,
      'status': status,
      'createdAt': createdAt,
      'abandonedAt': abandonedAt,
    };
  }
}
