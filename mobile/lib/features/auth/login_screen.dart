import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/design_tokens.dart';
import '../../core/routing/app_routes.dart';
import 'widgets/auth_widgets.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) => AuthLayout(
    title: 'Welcome back',
    subtitle: 'Your next chapter is waiting.',
    children: [
      TextFormField(
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        textInputAction: TextInputAction.next,
        autocorrect: false,
        decoration: const InputDecoration(
          labelText: 'Email',
          prefixIcon: Icon(Icons.mail_outline),
        ),
      ),
      const SizedBox(height: AppSpace.sm),
      const PasswordField(),
      const Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          // TODO: Connect password recovery.
          onPressed: null,
          child: Text('Forgot Password'),
        ),
      ),
      const FilledButton(
        // TODO: Connect authentication; never grant access from this UI alone.
        onPressed: null,
        child: Text('Sign In'),
      ),
      const SizedBox(height: AppSpace.sm),
      const GoogleAuthButton(label: 'Continue with Google'),
      const SizedBox(height: AppSpace.sm),
      const Text(
        'Sign-in will be available soon.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: AppSpace.sm),
      TextButton(
        onPressed: () => context.pushReplacement(AppRoutes.register),
        child: const Text('Create Account'),
      ),
    ],
  );
}
