import 'package:flutter/material.dart';
import 'package:lumina/services/habit_services.dart';
import 'package:lumina/theme.dart';

Future<void> showCelebration(BuildContext context, Celebration celebration) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: LuminaColors.surface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.3, end: 1),
              duration: Duration(milliseconds: celebration.big ? 900 : 500),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(scale: value, child: child);
              },
              child: Icon(
                Icons.local_fire_department_rounded,
                size: celebration.big ? 96 : 56,
                color: LuminaColors.accent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              celebration.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            Text(
              celebration.body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep going'),
          ),
        ],
      );
    },
  );
}
