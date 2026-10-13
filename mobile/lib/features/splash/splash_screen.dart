import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/design_tokens.dart';
import '../../core/routing/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) context.go(AppRoutes.welcome);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.navy,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_stories_rounded,
                size: AppSizes.illustrationIcon,
                color: AppColors.gold,
              ),
              const SizedBox(height: AppSpace.md),
              Text(
                'EEELibrary',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: AppColors.surface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                'Learn ? Prepare ? Grow',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: AppColors.surface),
              ),
              const SizedBox(height: AppSpace.xl),
              const SizedBox(
                width: AppSpace.md,
                height: AppSpace.md,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.gold,
                  semanticsLabel: 'Loading EEELibrary',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
