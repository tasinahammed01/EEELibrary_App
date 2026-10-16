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
    child: LayoutBuilder(
      builder: (context, constraints) {
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'YOUR NEXT CHAPTER',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.gold,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              'Build your EEE bookshelf',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.surface,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              'Big ideas. Clearer concepts.\nResources for your next step.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.surface, height: 1.5),
            ),
          ],
        );
        final showArt =
            constraints.maxWidth >= AppSizes.contentWidth / 2 &&
            MediaQuery.textScalerOf(context).scale(1) <= 1.3;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showArt)
              Row(
                children: [
                  Expanded(child: copy),
                  const SizedBox(width: AppSpace.sm),
                  const _BookArtwork(),
                ],
              )
            else
              copy,
            const SizedBox(height: AppSpace.sm),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(
                  AppSizes.touchTarget,
                  AppSizes.touchTarget,
                ),
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.navy,
                elevation: 0,
              ),
              onPressed: onExplore,
              child: const Wrap(
                spacing: AppSpace.xs,
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Explore Now'),
                  Icon(Icons.arrow_forward_rounded),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _BookArtwork extends StatelessWidget {
  const _BookArtwork();
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: AppSpace.xl * 2,
      height: AppSpace.xl * 3,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: -.14,
            child: Container(
              width: AppSpace.xl + AppSpace.lg,
              height: AppSpace.xl * 2 + AppSpace.sm,
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
            ),
          ),
          Transform.rotate(
            angle: .10,
            child: Container(
              width: AppSpace.xl + AppSpace.lg,
              height: AppSpace.xl * 2 + AppSpace.sm,
              padding: const EdgeInsets.all(AppSpace.sm),
              decoration: BoxDecoration(
                color: AppColors.blueTint,
                borderRadius: BorderRadius.circular(AppRadius.control),
                border: const Border(
                  left: BorderSide(
                    color: AppColors.surface,
                    width: AppSpace.xs,
                  ),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    color: AppColors.blue,
                    size: AppSpace.lg,
                  ),
                  Spacer(),
                  Icon(Icons.graphic_eq, color: AppColors.blue),
                  SizedBox(height: AppSpace.xs),
                  Divider(color: AppColors.blue),
                ],
              ),
            ),
          ),
          const Align(
            alignment: Alignment.topRight,
            child: Icon(Icons.auto_awesome, color: AppColors.gold),
          ),
        ],
      ),
    ),
  );
}
