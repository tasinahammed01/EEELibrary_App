import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/design_tokens.dart';
import '../../core/routing/app_routes.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/page_body.dart';
import 'widgets/welcome_benefit_grid.dart';
import 'widgets/welcome_hero.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: PageBody(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push(AppRoutes.login),
              child: const Text('Sign In'),
            ),
          ),
          const Center(child: Brand(prominent: true)),
          const SizedBox(height: AppSpace.sm),
          const _WelcomeHeadline(),
          const SizedBox(height: AppSpace.xs),
          const WelcomeHero(),
          const SizedBox(height: AppSpace.sm),
          const WelcomeBenefitGrid(),
          const SizedBox(height: AppSpace.xs),
          const _WelcomePageIndicator(),
          const SizedBox(height: AppSpace.xs),
          const _WelcomeActions(),
        ],
      ),
    ),
  );
}

class _WelcomeHeadline extends StatelessWidget {
  const _WelcomeHeadline();
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        'Buy EEE Books, Notes\n& Job Prep Resources',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -.8,
          height: 1.08,
        ),
      ),
      const SizedBox(height: AppSpace.xs),
      Text(
        'Your one-stop destination for academic books, notes, exam preparation and more.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: AppColors.muted, height: 1.35),
      ),
    ],
  );
}

class _WelcomePageIndicator extends StatelessWidget {
  const _WelcomePageIndicator();
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < 3; index++)
          Container(
            width: AppSpace.xs,
            height: AppSpace.xs,
            margin: const EdgeInsets.symmetric(horizontal: AppSpace.xs / 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: index == 0 ? AppColors.blue : AppColors.outline,
            ),
          ),
      ],
    ),
  );
}

class _WelcomeActions extends StatelessWidget {
  const _WelcomeActions();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FilledButton(
        onPressed: () => context.push(AppRoutes.register),
        child: const Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpace.xs,
          children: [
            Text('Get Started'),
            Icon(Icons.arrow_forward_rounded, size: AppSpace.md),
          ],
        ),
      ),
      TextButton(
        onPressed: () => context.go(AppRoutes.home),
        child: const Text('Browse as Guest'),
      ),
    ],
  );
}
