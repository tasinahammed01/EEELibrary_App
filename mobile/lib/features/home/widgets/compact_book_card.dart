import 'package:flutter/material.dart';

import '../../../core/constants/design_tokens.dart';
import '../data/mock_home_data.dart';
import 'book_card.dart';

class CompactBookCard extends StatelessWidget {
  const CompactBookCard({super.key, required this.book});
  final MockHomeBook book;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpace.sm),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(color: AppColors.outline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BookCover(book: book, compact: true),
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
        const SizedBox(height: AppSpace.sm),
        Text(
          book.price,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: AppColors.blue, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}
