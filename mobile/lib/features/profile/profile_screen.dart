import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/presentation/auth_scope.dart';
import '../auth/domain/auth_models.dart';
import '../../core/routing/app_routes.dart';
import '../../core/widgets/feature_placeholder.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.maybeOf(context);
    final user = auth?.user;
    return FeaturePlaceholder(
      title: 'Profile',
      heading: user?.displayName ?? 'Browsing as a guest',
      description:
          user?.email ?? 'Sign in to build your personal learning library.',
      icon: Icons.person_outline,
      action: OutlinedButton(
        onPressed: auth?.busy == true
            ? null
            : () async {
                if (user == null) {
                  context.push(AppRoutes.login);
                } else {
                  await auth!.signOut();
                  if (context.mounted && auth.status == AuthStatus.signedOut) {
                    context.go(AppRoutes.welcome);
                  }
                }
              },
        child: Text(user == null ? 'Sign In' : 'Sign Out'),
      ),
    );
  }
}
