import 'package:flutter/material.dart';
import 'package:lumina/theme.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.coverUrl,
    this.width = 56,
    this.height = 80,
  });

  final String coverUrl;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    const Widget placeholder = Center(
      child: Icon(Symbols.menu_book_rounded, color: LuminaColors.textTertiary),
    );
    return Container(
      width: width,
      height: height,
      decoration: LuminaDecorations.thumbnail,
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
