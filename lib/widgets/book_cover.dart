import 'package:flutter/material.dart';
import 'package:lumina/theme.dart';

class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.coverUrl,
    required this.title,
    this.width = 64,
  });

  static const List<Color> _placeholderColors = <Color>[
    Color(0xFF3E5C4B),
    Color(0xFF6B4A3A),
    Color(0xFF4A4770),
    Color(0xFF6E5A2E),
    Color(0xFF2F5560),
    Color(0xFF6A3F52),
  ];

  final String coverUrl;
  final String title;
  final double width;

  @override
  Widget build(BuildContext context) {
    // Books without a cover get a coloured one with the title on it.
    final Color color =
        _placeholderColors[title.codeUnits.fold<int>(0, (a, b) => a + b) %
            _placeholderColors.length];
    final Widget placeholder = Container(
      color: color,
      padding: EdgeInsets.all(width * 0.1),
      alignment: Alignment.topLeft,
      child: Text(
        title,
        maxLines: 5,
        overflow: TextOverflow.ellipsis,
        style: LuminaTheme.display(size: width * 0.14, height: 1.15),
      ),
    );
    return Container(
      width: width,
      height: width * 1.5,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(LuminaTheme.radiusThumbnail),
        boxShadow: const [
          BoxShadow(
            color: LuminaColors.shadow,
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: coverUrl.startsWith('http')
          ? Image.network(
              coverUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => placeholder,
            )
          : placeholder,
    );
  }
}
