import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/design_tokens.dart';
import '../../core/routing/app_routes.dart';
import '../catalog/data/catalog_repository.dart';
import '../catalog/domain/catalog_models.dart';
import '../catalog/presentation/catalog_controller.dart';
import '../catalog/widgets/catalog_widgets.dart';
import 'widgets/home_book_shelf.dart';
import 'widgets/home_header.dart';
import 'widgets/home_search_bar.dart';
import 'widgets/home_shortcuts.dart';
import 'widgets/promo_banner.dart';
import 'widgets/section_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.repository});
  final CatalogRepository? repository;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final CatalogRepository _repository = widget.repository ?? CatalogApi();
  late final CatalogController _catalog = CatalogController(
    _repository,
    pageSize: 8,
  );
  @override
  void initState() {
    super.initState();
    unawaited(_catalog.initialize());
  }

  @override
  void dispose() {
    _catalog.dispose();
    if (widget.repository == null) _repository.close();
    super.dispose();
  }

  void _unavailable(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Semantics(
            liveRegion: true,
            child: Text('$feature will be available soon.'),
          ),
        ),
      );
  }

  void _openBook(CatalogBook book) =>
      context.push(AppRoutes.bookPath(book.slug));
  void _explore() => context.go(AppRoutes.explore);
  void _openCategory(CatalogCategory category) => context.go(
    Uri(
      path: AppRoutes.explore,
      queryParameters: {'category': category.slug},
    ).toString(),
  );

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppSizes.contentWidth + AppSpace.xl,
        ),
        child: ListenableBuilder(
          listenable: _catalog,
          builder: (context, _) => RefreshIndicator(
            onRefresh: _catalog.refresh,
            child: CustomScrollView(
              key: const PageStorageKey('home-scroll'),
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(AppSpace.sm),
                  sliver: SliverList.list(
                    children: [
                      HomeHeader(
                        onNotifications: () => _unavailable('Notifications'),
                        onProfile: () => context.go(AppRoutes.profile),
                      ),
                      const SizedBox(height: AppSpace.sm),
                      HomeSearchBar(onSearch: _explore, onFilter: _explore),
                      const SizedBox(height: AppSpace.sm),
                      PromoBanner(onExplore: _explore),
                      const SizedBox(height: AppSpace.md),
                      SectionHeader(title: 'Categories', onSeeAll: _explore),
                      const SizedBox(height: AppSpace.sm),
                      if (_catalog.categoriesLoading)
                        const CatalogLoading()
                      else if (_catalog.categoryError != null)
                        CatalogNotice(
                          message: _catalog.categoryError!.message,
                          onRetry: _catalog.loadCategories,
                        )
                      else if (_catalog.categories.isEmpty)
                        const CatalogNotice(
                          message: 'New subjects are on their way.',
                        )
                      else
                        HomeCategoryGrid(
                          categories: _catalog.categories,
                          onCategory: _openCategory,
                        ),
                      const SizedBox(height: AppSpace.md),
                      SectionHeader(title: 'Latest books', onSeeAll: _explore),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        'Fresh from the catalog. Find your next chapter.',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.muted),
                      ),
                      const SizedBox(height: AppSpace.sm),
                      if (_catalog.loading)
                        const CatalogLoading()
                      else if (_catalog.bookError != null)
                        CatalogNotice(
                          message: _catalog.bookError!.message,
                          onRetry: _catalog.reload,
                        )
                      else if (_catalog.books.isEmpty)
                        const CatalogNotice(
                          message: 'The catalog is growing. Check back soon.',
                        )
                      else
                        HomeBookShelf(
                          books: _catalog.books.take(4).toList(growable: false),
                          onBook: _openBook,
                        ),
                      if (!_catalog.loading && _catalog.books.length > 4) ...[
                        const SizedBox(height: AppSpace.md),
                        SectionHeader(
                          title: 'Discover more',
                          onSeeAll: _explore,
                        ),
                        const SizedBox(height: AppSpace.xs),
                        Text(
                          'More from the latest catalog, ready to explore.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.muted),
                        ),
                        const SizedBox(height: AppSpace.sm),
                        HomeBookShelf(
                          books: _catalog.books
                              .skip(4)
                              .take(4)
                              .toList(growable: false),
                          compact: true,
                          onBook: _openBook,
                        ),
                      ],
                      const SizedBox(height: AppSpace.md),
                      const SectionHeader(title: 'Quick Access'),
                      const SizedBox(height: AppSpace.sm),
                      HomeQuickAccess(onUnavailable: _unavailable),
                      const SizedBox(height: AppSpace.sm),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
