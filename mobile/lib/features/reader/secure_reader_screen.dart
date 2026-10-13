import 'package:flutter/material.dart';

import '../../core/widgets/feature_placeholder.dart';

class SecureReaderScreen extends StatelessWidget {
  const SecureReaderScreen({super.key});
  @override
  Widget build(BuildContext context) => const FeaturePlaceholder(
    title: 'Secure Reader',
    heading: 'Your reading space is taking shape',
    description: 'The reader is not available yet. Reading and document security will be implemented in a future phase.',
    icon: Icons.menu_book_outlined,
  );
}
