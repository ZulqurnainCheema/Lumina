import 'package:flutter/material.dart';
import 'package:lumina/research.dart';
import 'package:lumina/theme.dart';
import 'package:lumina/widgets/section_header.dart';
import 'package:lumina/widgets/why_chip.dart';

class Science extends StatelessWidget {
  const Science({super.key});

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final List<Research> used = researchEntries
        .where((entry) => entry.used)
        .toList();
    final List<Research> leftOut = researchEntries
        .where((entry) => !entry.used)
        .toList();
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text('The science', style: textTheme.displayLarge),
          const SizedBox(height: 8),
          Text(
            'Every part of Lumina is built on a published finding. Here is '
            'each one, with its source and its limits.',
            style: textTheme.bodyMedium?.copyWith(
              color: LuminaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 28),
          const SectionHeader(label: 'What Lumina uses'),
          const SizedBox(height: 8),
          for (final Research research in used) _ResearchTile(research),
          const SizedBox(height: 28),
          const SectionHeader(label: 'What it leaves out on purpose'),
          const SizedBox(height: 8),
          for (final Research research in leftOut) _ResearchTile(research),
        ],
      ),
    );
  }
}

class _ResearchTile extends StatelessWidget {
  const _ResearchTile(this.research);

  final Research research;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: LuminaColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LuminaTheme.radiusCard),
          side: const BorderSide(color: LuminaColors.borderSubtle),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: Text(
              research.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            iconColor: LuminaColors.textSecondary,
            collapsedIconColor: LuminaColors.textTertiary,
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [ResearchBody(research: research, showTitle: false)],
          ),
        ),
      ),
    );
  }
}
