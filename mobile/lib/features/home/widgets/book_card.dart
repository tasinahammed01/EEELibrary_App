import 'package:flutter/material.dart';

import '../../../core/constants/design_tokens.dart';
import '../data/mock_home_data.dart';

class BookCover extends StatelessWidget {
  const BookCover({super.key, required this.book, this.compact = false});
  final MockHomeBook book;
  final bool compact;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      height: compact
          ? AppSizes.illustrationIcon
          : AppSizes.illustrationIcon * 2,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, AppColors.blue],
        ),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        children: [
          Container(
            width: AppSpace.xs,
            margin: const EdgeInsets.symmetric(vertical: AppSpace.sm),
            color: AppColors.gold.withValues(alpha: .6),
          ),
          Expanded(
            child: Icon(
              book.icon,
              color: AppColors.gold,
              size: compact ? AppSpace.lg : AppSizes.illustrationIcon,
            ),
          ),
        ],
      ),
    ),
  );
}

class BookCard extends StatelessWidget {
  const BookCard({super.key, required this.book, required this.onFavorite});
  final MockHomeBook book;
  final VoidCallback onFavorite;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
      side: const BorderSide(color: AppColors.outline),
    ),
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookCover(book: book),
          const SizedBox(height: AppSpace.sm),
          Text(
            book.title,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            book.author,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpace.xs),
          Wrap(
            spacing: AppSpace.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(
                Icons.star_rounded,
                color: AppColors.gold,
                size: AppSpace.sm,
              ),
              Text(
                '${book.rating} (${book.ratingCount})',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Wrap(
            spacing: AppSpace.xs,
            runSpacing: AppSpace.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                book.price,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.blue,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(AppSpace.xs),
                decoration: BoxDecoration(
                  color: AppColors.blueTint,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Text(
                  'PDF',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: AppColors.blue),
                ),
              ),
              IconButton(
                tooltip: 'Save ${book.title} to wishlist',
                onPressed: onFavorite,
                constraints: const BoxConstraints(
                  minWidth: AppSizes.touchTarget,
                  minHeight: AppSizes.touchTarget,
                ),
                icon: const Icon(Icons.favorite_border, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
