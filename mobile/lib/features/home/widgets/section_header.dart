import 'package:flutter/material.dart';

import '../../../core/constants/design_tokens.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.onSeeAll});
  final String title;
  final VoidCallback? onSeeAll;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      if (onSeeAll != null) ...[
        const SizedBox(width: AppSpace.xs),
        TextButton(onPressed: onSeeAll, child: const Text('See All')),
      ],
    ],
  );
}
