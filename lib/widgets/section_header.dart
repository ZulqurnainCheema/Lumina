import 'package:flutter/material.dart';
import 'package:lumina/widgets/why_chip.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.label, this.researchKey});

  final String label;
  final String? researchKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        if (researchKey != null) WhyChip(researchKey: researchKey!),
      ],
    );
  }
}
