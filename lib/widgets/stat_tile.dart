import 'package:flutter/material.dart';
import 'package:lumina/theme.dart';

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.valueColor,
  });

  final String label;
  final String value;
  final String? unit;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: LuminaDecorations.card,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          // Long values shrink to fit instead of being cut off.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: textTheme.headlineMedium?.copyWith(
                      color: valueColor,
                    ),
                  ),
                  if (unit != null)
                    TextSpan(text: ' $unit', style: textTheme.bodySmall),
                ],
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
