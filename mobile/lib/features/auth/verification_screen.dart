import 'package:flutter/material.dart';

import '../../core/constants/design_tokens.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/page_body.dart';
import 'presentation/auth_scope.dart';
import 'widgets/auth_widgets.dart';
import 'domain/auth_models.dart';

class VerificationScreen extends StatelessWidget {
  const VerificationScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.maybeOf(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify your email'),
        automaticallyImplyLeading: false,
      ),
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: Brand(prominent: true)),
            const SizedBox(height: AppSpace.lg),
            const Icon(
              Icons.mark_email_unread_outlined,
              size: AppSizes.illustrationIcon,
              color: AppColors.blue,
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              'One more step to your library',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              'Open the verification link sent to your email. Then return here and check your status.',
              textAlign: TextAlign.center,
            ),
            if (auth?.verificationEmail case final email?) ...[
              const SizedBox(height: AppSpace.xs),
              Text(email, textAlign: TextAlign.center),
            ],
            const SizedBox(height: AppSpace.md),
            AuthFeedback(
              message: auth?.message,
              tone: auth?.feedbackTone ?? AuthFeedbackTone.error,
            ),
            AuthSubmitButton(
              label: 'I have verified my email',
              busy: auth?.busy ?? false,
              onPressed: auth == null || auth.busy
                  ? null
                  : auth.checkVerification,
            ),
            const SizedBox(height: AppSpace.sm),
            OutlinedButton(
              onPressed: auth?.canResend == true
                  ? auth!.resendVerification
                  : null,
              child: const Text('Resend verification email'),
            ),
            if (auth != null && !auth.canResend && !auth.busy)
              const Padding(
                padding: EdgeInsets.only(top: AppSpace.xs),
                child: Text(
                  'You can resend in a minute.',
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: AppSpace.sm),
            TextButton(
              onPressed: auth == null || auth.busy ? null : auth.signOut,
              child: const Text('Sign out or change account'),
            ),
          ],
        ),
      ),
    );
  }
}
