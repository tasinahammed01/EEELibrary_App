import 'package:flutter/material.dart';

import '../constants/design_tokens.dart';

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.contentWidth),
          child: child,
        ),
      ),
    ),
  );
}
