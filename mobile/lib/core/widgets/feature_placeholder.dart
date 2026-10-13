import 'package:flutter/material.dart';

import '../constants/design_tokens.dart';
import 'page_body.dart';

class FeaturePlaceholder extends StatelessWidget {
  const FeaturePlaceholder({
    super.key,
    required this.title,
    required this.heading,
    required this.description,
    required this.icon,
    this.action,
  });
  final String title;
  final String heading;
  final String description;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: PageBody(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpace.sm),
              decoration: BoxDecoration(
                color: AppColors.blueTint,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Icon(icon, size: AppSpace.xl, color: AppColors.blue),
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              heading,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: AppColors.muted, height: 1.5),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpace.md),
              action!,
            ],
          ],
        ),
      ),
    ),
  );
}
