import 'package:flutter/material.dart';

import '../constants/design_tokens.dart';

class Brand extends StatelessWidget {
  const Brand({super.key});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.all(AppSpace.xs),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: const Icon(Icons.auto_stories_rounded, color: AppColors.gold),
      ),
      const SizedBox(width: AppSpace.xs),
      Flexible(
        child: Text(
          'EEELibrary',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );
}
