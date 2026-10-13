import 'package:flutter/material.dart';

import '../../../core/constants/design_tokens.dart';

class PromoBanner extends StatelessWidget {
  const PromoBanner({super.key, required this.onExplore});
  final VoidCallback onExplore;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpace.md),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.navy, AppColors.blue],
      ),
      borderRadius: BorderRadius.circular(AppRadius.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _OfferBadge(),
            ExcludeSemantics(
              child: Icon(
                Icons.auto_stories_rounded,
                color: AppColors.gold,
                size: AppSpace.xl,
              ),
            ),
            ExcludeSemantics(
              child: Icon(
                Icons.electric_bolt_outlined,
                color: AppColors.gold,
                size: AppSpace.md,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          'Get Up to 50% OFF',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.surface,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          'on EEE Books & Notes',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: AppColors.surface),
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          'Academic • Job Preparation • Exam Resources',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.surface, height: 1.5),
        ),
        const SizedBox(height: AppSpace.md),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.navy,
          ),
          onPressed: onExplore,
          child: const Wrap(
            spacing: AppSpace.xs,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [Text('Explore Now'), Icon(Icons.arrow_forward_rounded)],
          ),
        ),
      ],
    ),
  );
}

class _OfferBadge extends StatelessWidget {
  const _OfferBadge();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpace.xs,
      vertical: AppSpace.xs,
    ),
    decoration: BoxDecoration(
      color: AppColors.surface.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(AppRadius.control),
    ),
    child: Text(
      'SPECIAL OFFER',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.gold,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      ),
    ),
  );
}
