import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/design_tokens.dart';
import '../../core/routing/app_routes.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/page_body.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(alignment: Alignment.centerLeft, child: Brand()),
          const SizedBox(height: AppSpace.lg),
          const _EducationIllustration(),
          const SizedBox(height: AppSpace.lg),
          Text(
            'Your next chapter starts here',
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: AppColors.blue),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            'Buy EEE Books, Notes\n& Job Prep Resources',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            'Build a stronger foundation in electrical and electronic engineering. Find resources for your courses, exams, and career?all in one place.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: AppSpace.md),
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: [
                for (final benefit in const [
                  (Icons.school_outlined, 'Academic Books'),
                  (Icons.work_outline, 'Job Preparation'),
                  (Icons.bolt_rounded, 'Instant Access'),
                  (Icons.shield_outlined, 'Secure Reading'),
                ])
                  SizedBox(
                    width: (constraints.maxWidth - AppSpace.sm) / 2,
                    child: _Benefit(icon: benefit.$1, label: benefit.$2),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          FilledButton(
            onPressed: () => context.push(AppRoutes.register),
            child: const Text('Get Started'),
          ),
          const SizedBox(height: AppSpace.xs),
          TextButton(
            onPressed: () => context.push(AppRoutes.login),
            child: const Text('Sign In'),
          ),
          TextButton(
            onPressed: () => context.go(AppRoutes.home),
            child: const Text('Browse as Guest'),
          ),
        ],
      ),
    ),
  );
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpace.sm),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.outline),
      borderRadius: BorderRadius.circular(AppRadius.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.blue),
        const SizedBox(height: AppSpace.xs),
        Text(label, style: Theme.of(context).textTheme.labelLarge),
      ],
    ),
  );
}

class _EducationIllustration extends StatelessWidget {
  const _EducationIllustration();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpace.md),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.blueTint, AppColors.goldTint],
      ),
      borderRadius: BorderRadius.circular(AppRadius.card),
    ),
    child: Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Icon(
              Icons.lightbulb_outline_rounded,
              color: AppColors.blue,
              size: AppSpace.lg,
            ),
            Icon(
              Icons.menu_book_rounded,
              color: AppColors.navy,
              size: AppSizes.illustrationIcon,
            ),
            Icon(
              Icons.school_rounded,
              color: AppColors.blue,
              size: AppSpace.lg,
            ),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          'A world of knowledge. One library.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ],
    ),
  );
}
