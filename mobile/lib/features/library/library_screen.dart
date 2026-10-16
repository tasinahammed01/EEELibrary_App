import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/design_tokens.dart';
import '../../core/routing/app_routes.dart';
import '../auth/presentation/auth_scope.dart';
import '../catalog/widgets/catalog_widgets.dart';
import '../purchases/data/purchase_repository.dart';
import '../purchases/presentation/purchase_controllers.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, this.repository});
  final PurchaseRepository? repository;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  LibraryController? _controller;
  String? _identity;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AuthScope.maybeOf(context);
    final key = widget.repository?.sessionKey;
    if (key == _identity && _controller != null) return;
    _controller?.dispose();
    _identity = key;
    _controller = key == null ? null : LibraryController(widget.repository!);
    if (_controller != null) unawaited(_controller!.load());
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppSizes.contentWidth + AppSpace.xl,
        ),
        child: _body(context),
      ),
    ),
  );
  Widget _body(BuildContext context) {
    final controller = _controller;
    if (controller == null || widget.repository?.sessionKey != _identity) {
      return ListView(
        padding: const EdgeInsets.all(AppSpace.md),
        children: [
          Text('My Library', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpace.md),
          const CatalogNotice(message: 'Sign in to see books in your library.'),
          const SizedBox(height: AppSpace.sm),
          FilledButton(
            onPressed: () => context.push(AppRoutes.login),
            child: const Text('Sign In'),
          ),
        ],
      );
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => RefreshIndicator(
        onRefresh: controller.load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(AppSpace.md),
              sliver: SliverList.list(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'My Library',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push(AppRoutes.orders),
                        child: const Text('Orders'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.sm),
                  const Text(
                    'Your acquired resources. Secure reading is coming in a later phase.',
                  ),
                  const SizedBox(height: AppSpace.md),
                  if (controller.loading) const CatalogLoading(),
                  if (controller.error != null)
                    CatalogNotice(
                      message: controller.error!.message,
                      onRetry: controller.books.isEmpty
                          ? controller.load
                          : controller.more,
                    ),
                  if (!controller.loading &&
                      controller.error == null &&
                      controller.books.isEmpty)
                    const CatalogNotice(
                      message: 'Your library is empty. Acquire a free resource or wait for payment approval to add your first book.',
                    ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
              sliver: CatalogBookSliver(
                books: controller.books,
                inLibrary: true,
                onBook: (book) async {
                  await context.push(AppRoutes.bookPath(book.slug));
                  if (mounted) await controller.load();
                },
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(AppSpace.md),
              sliver: SliverList.list(
                children: [
                  if (controller.loadingMore)
                    const CatalogLoading()
                  else if (controller.hasMore)
                    OutlinedButton(
                      onPressed: controller.more,
                      child: const Text('Load more'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
