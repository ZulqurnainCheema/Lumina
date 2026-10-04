import 'package:flutter/material.dart';
import 'package:lumina/services/habit_services.dart';
import 'package:lumina/theme.dart';
import 'package:lumina/widgets/lumina_sheet.dart';

Future<void> showCelebration(BuildContext context, Celebration celebration) {
  return showLuminaSheet(
    context,
    title: celebration.title,
    body: celebration.body,
    confirm: 'Keep going',
    researchKey: celebration.researchKey,
    leading: TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.3, end: 1),
      duration: Duration(milliseconds: celebration.big ? 900 : 500),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      // The one place a glow is used: a milestone.
      child: Container(
        width: celebration.big ? 136 : 96,
        height: celebration.big ? 136 : 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              LuminaColors.streak.withAlpha(90),
              LuminaColors.streak.withAlpha(0),
            ],
          ),
        ),
        child: Icon(
          Icons.local_fire_department_rounded,
          size: celebration.big ? 80 : 52,
          color: LuminaColors.streak,
        ),
      ),
    ),
  );
}
