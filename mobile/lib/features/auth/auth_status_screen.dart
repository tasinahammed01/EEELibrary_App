import 'package:flutter/material.dart';

import '../../core/constants/design_tokens.dart';
import '../../core/widgets/page_body.dart';
import 'presentation/auth_scope.dart';
import 'widgets/auth_widgets.dart';
import 'domain/auth_models.dart';

class AuthStatusScreen extends StatelessWidget {
  const AuthStatusScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.maybeOf(context);
    final heading = switch (auth?.failureKind) {
      AuthFailureKind.unavailable => 'Temporarily unavailable',
      AuthFailureKind.network => 'Connection unavailable',
      AuthFailureKind.denied ||
      AuthFailureKind.disabled => 'Account access unavailable',
      AuthFailureKind.conflict => 'Account sign-in needs attention',
      _ => 'We could not complete sign-in',
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account access'),
        automaticallyImplyLeading: false,
      ),
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.account_circle_outlined,
              size: AppSizes.illustrationIcon,
              color: AppColors.blue,
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              heading,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpace.sm),
            AuthFeedback(
              message: auth?.message,
              tone: auth?.feedbackTone ?? AuthFeedbackTone.error,
            ),
            AuthSubmitButton(
              label: 'Try again',
              busy: auth?.busy ?? false,
              onPressed: auth == null || auth.busy ? null : auth.retry,
            ),
            const SizedBox(height: AppSpace.sm),
            OutlinedButton(
              onPressed: auth == null || auth.busy ? null : auth.signOut,
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
