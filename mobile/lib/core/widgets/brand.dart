import 'package:flutter/material.dart';

import '../constants/design_tokens.dart';

class Brand extends StatelessWidget {
  const Brand({super.key, this.prominent = false});
  final bool prominent;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.all(AppSpace.sm),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.blue, AppColors.navy],
          ),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.navy),
        ),
        child: Icon(
          Icons.auto_stories_rounded,
          color: AppColors.gold,
          size: prominent ? AppSpace.lg : AppSpace.md,
        ),
      ),
      const SizedBox(width: AppSpace.sm),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'EEELibrary',
              style:
                  (prominent
                          ? Theme.of(context).textTheme.headlineMedium
                          : Theme.of(context).textTheme.titleLarge)
                      ?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
            ),
            const SizedBox(height: AppSpace.xs / 2),
            Text(
              'Learn. Prepare. Grow.',
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
    ],
  );
}
