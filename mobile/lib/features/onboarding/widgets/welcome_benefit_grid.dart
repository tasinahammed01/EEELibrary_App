import 'package:flutter/material.dart';

import '../../../core/constants/design_tokens.dart';

class WelcomeBenefitGrid extends StatelessWidget {
  const WelcomeBenefitGrid({super.key});
  // Allow readable tiles before reserving room for a second column and gap.
  static const _minimumColumnWidth = AppSpace.lg * 4;
  static const _benefits = [
    (
      Icons.school_outlined,
      'Wide Academic Collection',
      'Textbooks, references and class notes for EEE subjects.',
      AppColors.blueTint,
    ),
    (
      Icons.work_outline,
      'Job Preparation',
      'BCS, Bank, Govt. jobs and competitive exam resources.',
      AppColors.goldTint,
    ),
    (
      Icons.description_outlined,
      'Instant Access',
      'Access approved books and notes from your library.',
      AppColors.pinkTint,
    ),
    (
      Icons.shield_outlined,
      'Secure Reading',
      'Protected in-app access to purchased resources.',
      AppColors.mintTint,
    ),
  ];

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    // A horizontal/unbounded parent must not pass infinity to Expanded rows.
    constraints: const BoxConstraints(maxWidth: AppSizes.contentWidth),
    child: LayoutBuilder(
      builder: (context, constraints) {
        // Transient collapsed layouts cannot accommodate even the icon/padding.
        // Wait for usable constraints rather than laying out illegible slivers.
        if (constraints.maxWidth < AppSizes.touchTarget) {
          return const SizedBox.shrink();
        }
        final cards = [
          for (final benefit in _benefits)
            WelcomeBenefitCard(
              icon: benefit.$1,
              title: benefit.$2,
              description: benefit.$3,
              surface: benefit.$4,
            ),
        ];
        final twoColumns =
            constraints.maxWidth >= _minimumColumnWidth * 2 + AppSpace.xs;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!twoColumns)
              for (var index = 0; index < cards.length; index++) ...[
                if (index > 0) const SizedBox(height: AppSpace.xs),
                cards[index],
              ]
            else
              for (var index = 0; index < cards.length; index += 2) ...[
                if (index > 0) const SizedBox(height: AppSpace.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: cards[index]),
                    const SizedBox(width: AppSpace.xs),
                    Expanded(
                      child: index + 1 < cards.length
                          ? cards[index + 1]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ],
          ],
        );
      },
    ),
  );
}

class WelcomeBenefitCard extends StatelessWidget {
  const WelcomeBenefitCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.surface,
  });
  final IconData icon;
  final String title;
  final String description;
  final Color surface;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    child: Container(
      constraints: const BoxConstraints(
        minHeight: AppSpace.xl * 2 + AppSpace.sm,
      ),
      padding: const EdgeInsets.all(AppSpace.xs),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: AppColors.outline.withValues(alpha: .6)),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(icon, size: AppSpace.md, color: AppColors.blue),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w700, height: 1.2),
          ),
          const SizedBox(height: AppSpace.xs / 2),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.muted, height: 1.25),
          ),
        ],
      ),
    ),
  );
}
