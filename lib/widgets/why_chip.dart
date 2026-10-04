import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lumina/research.dart';
import 'package:lumina/theme.dart';

class WhyChip extends StatelessWidget {
  const WhyChip({super.key, required this.researchKey});

  final String researchKey;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => showWhySheet(context, researchKey),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 15,
              color: LuminaColors.textTertiary,
            ),
            const SizedBox(width: 4),
            Text(
              'Why?',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: LuminaColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showWhySheet(BuildContext context, String researchKey) {
  final Research research = researchFor(researchKey);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WHY THIS WORKS',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              ResearchBody(research: research),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    GoRouter.of(context).push('/science');
                  },
                  child: const Text('See all the science'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// Title, finding, source and evidence note for one research entry.
class ResearchBody extends StatelessWidget {
  const ResearchBody({
    super.key,
    required this.research,
    this.showTitle = true,
  });

  final Research research;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Text(research.title, style: textTheme.headlineMedium),
          const SizedBox(height: 12),
        ],
        Text(research.finding, style: textTheme.bodyMedium),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: LuminaColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SOURCE', style: textTheme.labelMedium),
              const SizedBox(height: 6),
              Text(
                research.citation.isEmpty
                    ? 'No study behind this one.'
                    : research.citation,
                style: textTheme.bodySmall,
              ),
              if (research.note != null) ...[
                const SizedBox(height: 8),
                Text(
                  research.note!,
                  style: textTheme.bodySmall?.copyWith(
                    color: LuminaColors.streak,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
