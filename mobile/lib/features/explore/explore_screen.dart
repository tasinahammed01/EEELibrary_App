import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/design_tokens.dart';
import '../../core/routing/app_routes.dart';
import '../catalog/data/catalog_repository.dart';
import '../catalog/presentation/catalog_controller.dart';
import '../catalog/widgets/catalog_widgets.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key, this.repository, this.initialCategory});
  final CatalogRepository? repository;
  final String? initialCategory;
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late final CatalogRepository _repository = widget.repository ?? CatalogApi();
  late final CatalogController _catalog = CatalogController(_repository)
    ..category = widget.initialCategory;
  @override
  void initState() {
    super.initState();
    unawaited(_catalog.initialize());
  }

  @override
  void didUpdateWidget(covariant ExploreScreen old) {
    super.didUpdateWidget(old);
    if (old.initialCategory != widget.initialCategory) {
      _catalog.setCategory(widget.initialCategory);
    }
  }

  @override
  void dispose() {
    _catalog.dispose();
    if (widget.repository == null) _repository.close();
    super.dispose();
  }

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
              key: const PageStorageKey('explore-scroll'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(AppSpace.md),
                  sliver: SliverList.list(
                    children: [
                      Text(
                        'Explore',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpace.xs),
                      const Text('Find your next resource'),
                      const SizedBox(height: AppSpace.md),
                      TextField(
                        maxLength: 120,
                        onChanged: _catalog.setSearch,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _catalog.reload(),
                        decoration: const InputDecoration(
                          labelText: 'Search books',
                          prefixIcon: Icon(Icons.search),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: AppSpace.sm),
                      if (_catalog.categoriesLoading)
                        const CatalogLoading()
                      else if (_catalog.categoryError != null)
                        CatalogNotice(
                          message: _catalog.categoryError!.message,
                          onRetry: _catalog.loadCategories,
                        )
                      else
                        CatalogCategories(
                          categories: _catalog.categories,
                          selected: _catalog.category,
                          onSelected: _catalog.setCategory,
                        ),
                      const SizedBox(height: AppSpace.sm),
                      DropdownButtonFormField<String>(
                        initialValue: _catalog.sort,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Sort books',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'newest',
                            child: Text('Newest first'),
                          ),
                          DropdownMenuItem(
                            value: 'title',
                            child: Text('Title A to Z'),
                          ),
                          DropdownMenuItem(
                            value: 'price-asc',
                            child: Text('Price: low to high'),
                          ),
                          DropdownMenuItem(
                            value: 'price-desc',
                            child: Text('Price: high to low'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) _catalog.setSort(value);
                        },
                      ),
                      const SizedBox(height: AppSpace.md),
                      if (_catalog.loading)
                        const CatalogLoading()
                      else if (_catalog.books.isEmpty &&
                          _catalog.bookError == null)
                        const CatalogNotice(
                          message: 'No books match your search. Try another title or subject.',
                        ),
                    ],
                  ),
                ),
                if (!_catalog.loading)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.md,
                    ),
                    sliver: CatalogBookSliver(
                      books: _catalog.books,
                      onBook: (book) =>
                          context.push(AppRoutes.bookPath(book.slug)),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.all(AppSpace.md),
                  sliver: SliverList.list(
                    children: [
                      if (_catalog.bookError != null)
                        CatalogNotice(
                          message: _catalog.bookError!.message,
                          onRetry: _catalog.books.isEmpty
                              ? _catalog.reload
                              : _catalog.loadMore,
                        ),
                      if (_catalog.loadingMore)
                        const CatalogLoading()
                      else if (_catalog.hasMore)
                        OutlinedButton(
                          onPressed: _catalog.loadMore,
                          child: const Text('Load more'),
                        ),
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
