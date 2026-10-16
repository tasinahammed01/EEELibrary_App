import '../purchases/data/purchase_repository.dart';
import '../purchases/presentation/book_purchase_panel.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/design_tokens.dart';
import '../../core/routing/app_routes.dart';
import 'data/catalog_repository.dart';
import 'presentation/catalog_controller.dart';
import 'widgets/catalog_widgets.dart';

class BookDetailsScreen extends StatefulWidget {
  const BookDetailsScreen({
    super.key,
    required this.slug,
    this.repository,
    this.purchases,
  });
  final String slug;
  final PurchaseRepository? purchases;
  final CatalogRepository? repository;
  @override
  State<BookDetailsScreen> createState() => _BookDetailsScreenState();
}

class _BookDetailsScreenState extends State<BookDetailsScreen> {
  late final CatalogRepository _repository = widget.repository ?? CatalogApi();
  late BookDetailsController _details;
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _initialize() {
    _details = BookDetailsController(_repository, widget.slug);
    unawaited(_details.load());
  }

  @override
  void didUpdateWidget(covariant BookDetailsScreen old) {
    super.didUpdateWidget(old);
    if (old.slug != widget.slug) {
      _details.dispose();
      _initialize();
    }
  }

  @override
  void dispose() {
    _details.dispose();
    if (widget.repository == null) _repository.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Book details'),
      leading: IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.explore);
          }
        },
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.contentWidth),
          child: ListenableBuilder(
            listenable: _details,
            builder: (context, _) {
              if (_details.loading) return const CatalogLoading();
              if (_details.error != null) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpace.md),
                  child: CatalogNotice(
                    message: _details.error!.message,
                    onRetry: _details.load,
                  ),
                );
              }
              final book = _details.book!;
              return RefreshIndicator(
                onRefresh: _details.load,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpace.md),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    CatalogCover(book: book),
                    const SizedBox(height: AppSpace.md),
                    Text(
                      book.category.name,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      book.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      book.priceLabel,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    if (book.pageCount != null) ...[
                      const SizedBox(height: AppSpace.sm),
                      Text('${book.pageCount} pages'),
                    ],
                    const SizedBox(height: AppSpace.md),
                    Text(
                      'About this book',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(book.description),
                    const SizedBox(height: AppSpace.md),
                    BookPurchasePanel(
                      slug: book.slug,
                      free: double.parse(book.price) == 0,
                      repository: widget.purchases,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}
