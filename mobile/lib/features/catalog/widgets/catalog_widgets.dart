import 'package:flutter/material.dart';

import '../../../core/constants/design_tokens.dart';
import '../domain/catalog_models.dart';

class CatalogNotice extends StatelessWidget {
  const CatalogNotice({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          if (onRetry != null)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
        ],
      ),
    ),
  );
}

class CatalogLoading extends StatelessWidget {
  const CatalogLoading({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(AppSpace.lg),
    child: Center(
      child: CircularProgressIndicator(semanticsLabel: 'Loading catalog'),
    ),
  );
}

class CatalogCover extends StatelessWidget {
  const CatalogCover({super.key, required this.book});
  final CatalogBook book;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Cover for ${book.title}',
    child: ExcludeSemantics(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.sm),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors:
                book.category.slug.codeUnits
                    .fold<int>(0, (a, b) => a + b)
                    .isEven
                ? const [AppColors.navy, AppColors.blue]
                : const [AppColors.blue, AppColors.navy],
          ),
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.auto_stories_rounded,
              color: AppColors.gold,
              size: AppSpace.lg,
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              book.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
    ),
  );
}

class CatalogBookCard extends StatelessWidget {
  const CatalogBookCard({super.key, required this.book, required this.onTap});
  final CatalogBook book;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CatalogCover(book: book),
            const SizedBox(height: AppSpace.sm),
            Text(
              book.category.name,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              book.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              book.priceLabel,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Natural-height lazy rows avoid estimated card heights and intrinsic passes.
class CatalogBookSliver extends StatelessWidget {
  const CatalogBookSliver({
    super.key,
    required this.books,
    required this.onBook,
  });
  final List<CatalogBook> books;
  final ValueChanged<CatalogBook> onBook;
  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.crossAxisExtent >= AppSizes.contentWidth / 2 &&
              MediaQuery.textScalerOf(context).scale(1) <= 1.3
          ? 2
          : 1;
      return SliverList.builder(
        itemCount: (books.length / columns).ceil(),
        itemBuilder: (context, row) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var column = 0; column < columns; column++) ...[
                if (column > 0) const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: row * columns + column < books.length
                      ? CatalogBookCard(
                          key: ValueKey(
                            'catalog-book-${books[row * columns + column].slug}',
                          ),
                          book: books[row * columns + column],
                          onTap: () => onBook(books[row * columns + column]),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class CatalogCategories extends StatelessWidget {
  const CatalogCategories({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
  });
  final List<CatalogCategory> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpace.xs,
    runSpacing: AppSpace.xs,
    children: [
      ChoiceChip(
        label: const Text('All'),
        selected: selected == null,
        onSelected: (_) => onSelected(null),
      ),
      for (final category in categories)
        ChoiceChip(
          key: ValueKey('catalog-category-${category.slug}'),
          label: Text(category.name),
          selected: selected == category.slug,
          onSelected: (_) => onSelected(category.slug),
        ),
    ],
  );
}
