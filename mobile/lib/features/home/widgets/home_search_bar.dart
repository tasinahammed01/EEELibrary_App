import 'package:flutter/material.dart';

import '../../../core/constants/design_tokens.dart';

class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({
    super.key,
    required this.onSearch,
    required this.onFilter,
  });
  final VoidCallback onSearch;
  final VoidCallback onFilter;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
      side: const BorderSide(color: AppColors.outline),
    ),
    clipBehavior: Clip.antiAlias,
    child: Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onSearch,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.sm),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: AppColors.blue),
                  const SizedBox(width: AppSpace.xs),
                  Expanded(
                    child: Text(
                      'Search books, notes, MCQ, jobs...',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Filter resources',
          onPressed: onFilter,
          constraints: const BoxConstraints(
            minWidth: AppSizes.touchTarget,
            minHeight: AppSizes.touchTarget,
          ),
          icon: const Icon(Icons.tune_rounded, color: AppColors.blue),
        ),
      ],
    ),
  );
}
