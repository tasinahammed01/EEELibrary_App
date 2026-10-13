import 'package:flutter/material.dart';

import '../../core/widgets/feature_placeholder.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});
  @override
  Widget build(BuildContext context) => const FeaturePlaceholder(
    title: 'My Library',
    heading: 'A home for your learning',
    description: 'Your books and saved resources will appear here once accounts and the catalog are connected.',
    icon: Icons.bookmarks_outlined,
  );
}
