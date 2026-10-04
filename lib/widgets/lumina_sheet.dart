import 'package:flutter/material.dart';
import 'package:lumina/theme.dart';
import 'package:lumina/widgets/why_chip.dart';

// A prompt with one title, one line of explanation and at most two actions.
// Returns true for the main action, false for the other, null if swiped away.
Future<bool?> showLuminaSheet(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
  String? dismiss,
  String? researchKey,
  Widget? leading,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) {
      final TextTheme textTheme = Theme.of(context).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[
                Center(child: leading),
                const SizedBox(height: 16),
              ],
              Text(title, style: textTheme.headlineMedium),
              const SizedBox(height: 10),
              Text(
                body,
                style: textTheme.bodyMedium?.copyWith(
                  color: LuminaColors.textSecondary,
                ),
              ),
              if (researchKey != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: WhyChip(researchKey: researchKey),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(confirm),
              ),
              if (dismiss != null) ...[
                const SizedBox(height: 4),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(dismiss),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
