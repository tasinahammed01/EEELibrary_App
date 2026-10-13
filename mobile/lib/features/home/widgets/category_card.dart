import 'package:flutter/material.dart';

import '../../../core/constants/design_tokens.dart';
import '../data/mock_home_data.dart';

class CategoryCard extends StatelessWidget {
  const CategoryCard({
    super.key,
    required this.category,
    required this.onTap,
    this.warm = false,
  });
  final MockHomeCategory category;
  final VoidCallback onTap;
  final bool warm;
  @override
  Widget build(BuildContext context) => Material(
    color: warm ? AppColors.goldTint : AppColors.blueTint,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
      side: const BorderSide(color: AppColors.outline),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.xs,
          vertical: AppSpace.sm,
        ),
        child: Column(
          children: [
            Icon(category.icon, color: AppColors.blue, size: AppSpace.lg),
            const SizedBox(height: AppSpace.xs),
            Text(
              category.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ),
  );
}
