import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/design_tokens.dart';
import '../../core/routing/app_routes.dart';
import 'data/mock_home_data.dart';
import 'widgets/home_collections.dart';
import 'widgets/home_header.dart';
import 'widgets/home_search_bar.dart';
import 'widgets/promo_banner.dart';
import 'widgets/section_header.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // TODO: Replace these availability notices when the corresponding features
  // are connected. These callbacks never grant access or mutate mock data.
  void _showUnavailable(BuildContext context, String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('$feature will be available soon.')),
      );
  }

  void _openQuickAccess(BuildContext context, MockHomeCategory item) {
    if (item.title == 'Bookmarks' || item.title == 'Downloads') {
      context.go(AppRoutes.library);
    } else {
      _showUnavailable(context, item.title);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppSizes.contentWidth + AppSpace.xl,
        ),
        child: CustomScrollView(
          key: const PageStorageKey('home-scroll'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(AppSpace.md),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  HomeHeader(
                    onNotifications: () =>
                        _showUnavailable(context, 'Notifications'),
                    onProfile: () => context.go(AppRoutes.profile),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  HomeSearchBar(
                    onSearch: () => _showUnavailable(context, 'Search'),
                    onFilter: () => _showUnavailable(context, 'Filters'),
                  ),
                  const SizedBox(height: AppSpace.md),
                  Text(
                    'A little learning. A bigger future.',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    'Preview collection • sample prices and ratings',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  PromoBanner(onExplore: () => context.go(AppRoutes.explore)),
                  const SizedBox(height: AppSpace.lg),
                  const SectionHeader(title: 'Categories'),
                  const SizedBox(height: AppSpace.sm),
                  HomeCategoryGrid(
                    onCategory: (_) => context.go(AppRoutes.explore),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  SectionHeader(
                    title: 'Featured Books',
                    onSeeAll: () => context.go(AppRoutes.explore),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  HomeBookShelf(
                    books: MockHomeData.featured,
                    onFavorite: (_) => _showUnavailable(context, 'Wishlist'),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  SectionHeader(
                    title: 'Recommended for You',
                    onSeeAll: () => context.go(AppRoutes.explore),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  HomeBookShelf(
                    books: MockHomeData.recommended,
                    compact: true,
                    onFavorite: (_) => _showUnavailable(context, 'Wishlist'),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  const SectionHeader(title: 'Quick Access'),
                  const SizedBox(height: AppSpace.sm),
                  HomeQuickAccess(
                    onAction: (item) => _openQuickAccess(context, item),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
