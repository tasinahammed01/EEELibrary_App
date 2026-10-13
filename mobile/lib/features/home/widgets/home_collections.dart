import 'package:flutter/material.dart';

import '../../../core/constants/design_tokens.dart';
import '../data/mock_home_data.dart';
import 'book_card.dart';
import 'category_card.dart';
import 'compact_book_card.dart';
import 'quick_access_item.dart';

class HomeCategoryGrid extends StatelessWidget {
  const HomeCategoryGrid({super.key, required this.onCategory});
  final ValueChanged<MockHomeCategory> onCategory;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth >= AppSizes.contentWidth - AppSpace.xl * 3 &&
              MediaQuery.textScalerOf(context).scale(1) <= 1.1
          ? 4
          : 2;
      final width =
          (constraints.maxWidth - AppSpace.xs * (columns - 1)) / columns;
      return Wrap(
        spacing: AppSpace.xs,
        runSpacing: AppSpace.sm,
        children: [
          for (var index = 0; index < MockHomeData.categories.length; index++)
            SizedBox(
              width: width,
              child: CategoryCard(
                category: MockHomeData.categories[index],
                warm: index.isOdd,
                onTap: () => onCategory(MockHomeData.categories[index]),
              ),
            ),
        ],
      );
    },
  );
}

class HomeQuickAccess extends StatelessWidget {
  const HomeQuickAccess({super.key, required this.onAction});
  final ValueChanged<MockHomeCategory> onAction;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = MediaQuery.textScalerOf(context).scale(1) > 1.2 ? 2 : 3;
      final width =
          (constraints.maxWidth - AppSpace.xs * (columns - 1)) / columns;
      return Wrap(
        spacing: AppSpace.xs,
        runSpacing: AppSpace.xs,
        children: [
          for (final item in MockHomeData.quickAccess)
            SizedBox(
              width: width,
              child: QuickAccessItem(item: item, onTap: () => onAction(item)),
            ),
        ],
      );
    },
  );
}

/// Four local fixtures per shelf: a natural-height row avoids clipping titles
/// at large text scales without intrinsic layout passes or estimated heights.
class HomeBookShelf extends StatelessWidget {
  const HomeBookShelf({
    super.key,
    required this.books,
    this.compact = false,
    required this.onFavorite,
  });
  final List<MockHomeBook> books;
  final bool compact;
  final ValueChanged<MockHomeBook> onFavorite;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < books.length; index++) ...[
          if (index > 0) const SizedBox(width: AppSpace.sm),
          SizedBox(
            width: compact
                ? AppSizes.contentWidth / 2 - AppSpace.md
                : AppSizes.contentWidth / 2,
            child: compact
                ? CompactBookCard(book: books[index])
                : BookCard(
                    book: books[index],
                    onFavorite: () => onFavorite(books[index]),
                  ),
          ),
        ],
      ],
    ),
  );
}
