import 'package:flutter/material.dart';

import '../../core/widgets/feature_placeholder.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});
  @override
  Widget build(BuildContext context) => const FeaturePlaceholder(
    title: 'Explore',
    heading: 'Find your next resource',
    description: 'Discover EEE subjects and career preparation materials here when the catalog is ready.',
    icon: Icons.explore_outlined,
  );
}
