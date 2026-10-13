import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_routes.dart';
import '../../core/widgets/feature_placeholder.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) => FeaturePlaceholder(
    title: 'Profile',
    heading: 'Browsing as a guest',
    description: 'Create an account when sign-up becomes available to build your personal learning library.',
    icon: Icons.person_outline,
    action: OutlinedButton(
      onPressed: () => context.push(AppRoutes.login),
      child: const Text('Sign In'),
    ),
  );
}
