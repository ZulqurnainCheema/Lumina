import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lumina/models/books.dart';
import 'package:lumina/services/habit_services.dart';
import 'package:lumina/theme.dart';
import 'package:lumina/widgets/book_cover.dart';

// The "Lumina today" home-screen widget: the current book as it appears on
// Today, with the minutes ring and streak beside it. Drawn to an image by the
// app, so it looks the same as the app.
class TodayWidgetCard extends StatelessWidget {
  const TodayWidgetCard({super.key, required this.today, this.cover});

  static const Size size = Size(372, 250);

  final TodayData today;

  // The book's cover, decoded ahead of time.
  final ui.Image? cover;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Books? book = today.book;
    return Container(
      width: size.width,
      height: size.height,
      padding: const EdgeInsets.all(18),
      decoration: LuminaDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (book != null)
                BookCover(
                  coverUrl: book.coverUrl,
                  title: book.title,
                  width: 64,
                  decoded: cover,
                ),
              if (book != null) const SizedBox(width: 14),
              Expanded(
                child: book == null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pick your first book',
                            style: textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add one in Lumina and it shows up here.',
                            style: textTheme.bodySmall,
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.headlineMedium,
                          ),
                          Text(
                            book.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          LuminaWidgets.progressBar(today.percentage / 100),
                          const SizedBox(height: 6),
                          Text(
                            _progressLabel(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 14),
              _MiniRing(today: today),
            ],
          ),
          const Spacer(),
          if (today.hook != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: BoxDecoration(
                color: LuminaColors.tint(LuminaColors.recall),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YOU WANTED TO KNOW',
                    style: textTheme.labelMedium?.copyWith(
                      color: LuminaColors.recall,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    today.hook!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: LuminaTheme.display(
                      size: 16,
                      height: 1.3,
                      weight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              book == null
                  ? 'Tap to open Lumina'
                  : today.percentage > 0
                  ? 'Tap to continue reading'
                  : 'Tap to start reading',
              style: textTheme.labelLarge?.copyWith(color: LuminaColors.accent),
            ),
        ],
      ),
    );
  }

  String _progressLabel() {
    if (today.pagesLeft == null) {
      return '${today.percentage}% read';
    }
    final String time = today.secondsLeft == null
        ? ''
        : ' · ${HabitServices.formatDuration(today.secondsLeft!)}';
    return '${today.pagesLeft} pages left$time';
  }
}

// Minutes read today inside the goal ring, with the streak underneath.
class _MiniRing extends StatelessWidget {
  const _MiniRing({required this.today});

  final TodayData today;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final int minutes = today.secondsToday ~/ 60;
    final bool readWithoutTime =
        today.streak.readToday && today.secondsToday == 0;
    return Column(
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: (today.secondsToday / (today.goalMinutes * 60)).clamp(
                  0,
                  1,
                ),
                strokeWidth: 6,
                strokeCap: StrokeCap.round,
                backgroundColor: LuminaColors.track,
                color: LuminaColors.accent,
              ),
              Center(
                child: readWithoutTime
                    ? const Icon(
                        Icons.check_rounded,
                        size: 28,
                        color: LuminaColors.accent,
                      )
                    : Text(
                        '$minutes',
                        style: textTheme.headlineMedium?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              size: 16,
              color: today.streak.readToday
                  ? LuminaColors.streak
                  : LuminaColors.textTertiary,
            ),
            const SizedBox(width: 2),
            Text(
              '${today.streak.current}',
              style: textTheme.titleMedium?.copyWith(
                color: LuminaColors.streak,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
