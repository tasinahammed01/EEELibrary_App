import 'package:flutter/material.dart';

import '../../../core/constants/design_tokens.dart';
import '../../catalog/domain/catalog_models.dart';

/// Bounded, natural-height rows avoid intrinsic sizing and negative width math.
class HomeShortcutGrid extends StatelessWidget {
  const HomeShortcutGrid({
    super.key,
    required this.children,
    this.compact = false,
  });
  final List<Widget> children;
  final bool compact;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final columns = constraints.maxWidth < AppSizes.touchTarget * 4
          ? 1
          : compact
          ? (scale > 1.3 ? 2 : 3)
          : constraints.maxWidth >= (AppSizes.touchTarget + AppSpace.lg) * 4 &&
                scale <= 1.2
          ? 4
          : 2;
      return Column(
        children: [
          for (
            var row = 0;
            row < (children.length / columns).ceil();
            row++
          ) ...[
            if (row > 0) const SizedBox(height: AppSpace.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var column = 0; column < columns; column++) ...[
                  if (column > 0) const SizedBox(width: AppSpace.xs),
                  Expanded(
                    child: row * columns + column < children.length
                        ? children[row * columns + column]
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ],
        ],
      );
    },
  );
}

class HomeCategoryGrid extends StatelessWidget {
  const HomeCategoryGrid({
    super.key,
    required this.categories,
    required this.onCategory,
  });
  final List<CatalogCategory> categories;
  final ValueChanged<CatalogCategory> onCategory;
  static const _tints = [
    AppColors.blueTint,
    AppColors.goldTint,
    AppColors.mintTint,
    AppColors.pinkTint,
  ];
  IconData _icon(String slug) {
    if (slug.contains('circuit')) return Icons.account_tree_outlined;
    if (slug.contains('electronic')) return Icons.memory_outlined;
    if (slug.contains('machine')) return Icons.settings_outlined;
    if (slug.contains('power')) return Icons.bolt_rounded;
    if (slug.contains('control')) return Icons.tune_rounded;
    if (slug.contains('signal')) return Icons.graphic_eq_rounded;
    if (slug.contains('communication')) return Icons.cell_tower_outlined;
    if (slug.contains('job')) return Icons.work_outline_rounded;
    return Icons.menu_book_outlined;
  }

  @override
  Widget build(BuildContext context) => HomeShortcutGrid(
    children: [
      for (var i = 0; i < categories.take(8).length; i++)
        _Shortcut(
          key: ValueKey('catalog-category-${categories[i].slug}'),
          title: categories[i].name,
          icon: _icon(categories[i].slug),
          background: _tints[i % _tints.length],
          onTap: () => onCategory(categories[i]),
        ),
    ],
  );
}

class HomeQuickAccess extends StatelessWidget {
  const HomeQuickAccess({super.key, required this.onUnavailable});
  final ValueChanged<String> onUnavailable;
  static const _items = [
    ('Syllabus', Icons.assignment_outlined),
    ('Previous Questions', Icons.quiz_outlined),
    ('Bookmarks', Icons.bookmark_border_rounded),
    ('Free Samples', Icons.auto_stories_outlined),
    ('Wishlist', Icons.favorite_border_rounded),
    ('Downloads', Icons.download_outlined),
  ];
  @override
  Widget build(BuildContext context) => HomeShortcutGrid(
    compact: true,
    children: [
      for (final item in _items)
        _Shortcut(
          title: item.$1,
          icon: item.$2,
          background: AppColors.surface,
          comingSoon: true,
          onTap: () => onUnavailable(item.$1),
        ),
    ],
  );
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    super.key,
    required this.title,
    required this.icon,
    required this.background,
    required this.onTap,
    this.comingSoon = false,
  });
  final String title;
  final IconData icon;
  final Color background;
  final VoidCallback onTap;
  final bool comingSoon;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    onTap: onTap,
    label: comingSoon ? '$title, coming soon' : title,
    excludeSemantics: true,
    child: Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        side: const BorderSide(color: AppColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.xs,
            vertical: AppSpace.sm,
          ),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                Icon(icon, color: AppColors.blue),
                const SizedBox(height: AppSpace.xs),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        MediaQuery.textScalerOf(context).scale(
                          Theme.of(context).textTheme.labelMedium!.fontSize!,
                        ) *
                        (Theme.of(context).textTheme.labelMedium!.height ?? 1) *
                        (comingSoon ? 2 : 3),
                  ),
                  child: Center(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (comingSoon) ...[
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    'Coming soon',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: AppColors.muted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
