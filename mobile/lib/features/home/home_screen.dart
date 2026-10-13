import 'package:flutter/material.dart';

import '../../core/widgets/feature_placeholder.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) => const FeaturePlaceholder(
    title: 'EEELibrary',
    heading: 'Welcome to your next chapter',
    description: 'Academic books, notes, and job preparation resources will appear here as the catalog becomes available.',
    icon: Icons.auto_stories_outlined,
  );
}
