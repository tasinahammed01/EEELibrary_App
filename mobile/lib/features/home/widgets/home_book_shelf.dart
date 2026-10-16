import 'package:flutter/material.dart';

import '../../../core/constants/design_tokens.dart';
import '../../catalog/domain/catalog_models.dart';

/// Each shelf is capped at four API records. Natural-height children support
/// large text without guessed heights, intrinsic passes or nested vertical lists.
class HomeBookShelf extends StatelessWidget {
  const HomeBookShelf({
    super.key,
    required this.books,
    required this.onBook,
    this.compact = false,
  });
  final List<CatalogBook> books;
  final ValueChanged<CatalogBook> onBook;
  final bool compact;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final preferredWidth = compact
          ? AppSizes.contentWidth / 3
          : AppSizes.contentWidth / 3 + AppSpace.lg;
      final width = constraints.maxWidth.isFinite
          ? preferredWidth.clamp(0.0, constraints.maxWidth)
          : preferredWidth;
      return SingleChildScrollView(
        key: PageStorageKey(
          compact ? 'home-discover-shelf' : 'home-latest-shelf',
        ),
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < books.take(4).length; index++) ...[
              if (index > 0) const SizedBox(width: AppSpace.sm),
              SizedBox(
                width: width,
                child: HomeBookCard(
                  key: ValueKey('catalog-book-${books[index].slug}'),
                  book: books[index],
                  compact: compact,
                  onTap: () => onBook(books[index]),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class HomeBookCard extends StatelessWidget {
  const HomeBookCard({
    super.key,
    required this.book,
    required this.onTap,
    this.compact = false,
  });
  final CatalogBook book;
  final VoidCallback onTap;
  final bool compact;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    onTap: onTap,
    label: '${book.title}, ${book.category.name}, ${book.priceLabel}',
    excludeSemantics: true,
    child: Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HomeBookCover(book: book, compact: compact),
              const SizedBox(height: AppSpace.sm),
              Text(
                book.category.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                book.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style:
                    (compact
                            ? Theme.of(context).textTheme.labelLarge
                            : Theme.of(context).textTheme.titleSmall)
                        ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                book.priceLabel,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.blue,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpace.xs),
            ],
          ),
        ),
      ),
    ),
  );
}

class HomeBookCover extends StatelessWidget {
  const HomeBookCover({super.key, required this.book, this.compact = false});
  final CatalogBook book;
  final bool compact;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    constraints: BoxConstraints(
      minHeight: compact ? AppSpace.xl * 3 : AppSpace.xl * 4,
    ),
    padding: EdgeInsets.all(compact ? AppSpace.xs : AppSpace.sm),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors:
            book.category.slug.codeUnits.fold<int>(0, (a, b) => a + b).isEven
            ? const [AppColors.navy, AppColors.blue]
            : const [AppColors.blue, AppColors.navy],
      ),
      borderRadius: BorderRadius.circular(AppRadius.control),
      border: const Border(
        left: BorderSide(color: AppColors.gold, width: AppSpace.xs),
      ),
    ),
    child: ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.auto_stories_rounded,
            color: AppColors.gold,
            size: AppSpace.lg,
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            book.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style:
                (compact
                        ? Theme.of(context).textTheme.labelLarge
                        : Theme.of(context).textTheme.titleMedium)
                    ?.copyWith(
                      color: AppColors.surface,
                      fontWeight: FontWeight.w800,
                    ),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            'EEELibrary',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: AppColors.gold),
          ),
        ],
      ),
    ),
  );
}
