import 'package:flutter/material.dart';

import '../core/constants/design_tokens.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/brand.dart';

class InitializationFailureApp extends StatelessWidget {
  const InitializationFailureApp({super.key, required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'EEELibrary',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Brand(prominent: true),
                const SizedBox(height: AppSpace.md),
                const Text(
                  'EEELibrary could not start sign-in safely. Check your connection and try again.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpace.md),
                FilledButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
