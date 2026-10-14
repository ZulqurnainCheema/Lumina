import 'package:flutter/material.dart';
import 'package:lumina/widgets/book_cover.dart';

// The cover preview with its two ways of getting one: a lookup by title, or
// a photo from the gallery.
class CoverPicker extends StatelessWidget {
  const CoverPicker({
    super.key,
    required this.coverUrl,
    required this.title,
    required this.busy,
    required this.onFind,
    required this.onGallery,
  });

  final String coverUrl;
  final String title;
  final bool busy;
  final VoidCallback onFind;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ButtonStyle compact = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 16),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BookCover(coverUrl: coverUrl, title: title, width: 80),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cover', style: textTheme.titleMedium),
              Text(
                'Look it up by title, or use a photo of your own copy.',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: busy ? null : onFind,
                    style: compact,
                    child: Text(busy ? 'Finding...' : 'Find cover'),
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : onGallery,
                    style: compact,
                    child: const Text('From gallery'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
