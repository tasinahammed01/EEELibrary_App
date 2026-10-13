import 'package:flutter/material.dart';

import '../../../core/constants/design_tokens.dart';
import '../data/mock_home_data.dart';

class QuickAccessItem extends StatelessWidget {
  const QuickAccessItem({super.key, required this.item, required this.onTap});
  final MockHomeCategory item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
      side: const BorderSide(color: AppColors.outline),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.sm),
        child: Column(
          children: [
            Icon(item.icon, color: AppColors.blue),
            const SizedBox(height: AppSpace.xs),
            Text(
              item.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
    ),
  );
}
