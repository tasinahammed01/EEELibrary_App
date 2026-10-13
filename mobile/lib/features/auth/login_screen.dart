import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/design_tokens.dart';
import '../../core/routing/app_routes.dart';
import 'presentation/auth_validators.dart';
import 'widgets/auth_hero.dart';
import 'widgets/auth_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _rememberMe = false;
  @override
  Widget build(BuildContext context) => AuthLayout(
    title: 'Welcome Back!',
    subtitle: 'Sign in to your EEELibrary account\nand continue your learning journey.',
    artwork: AuthArtwork.login,
    form: Form(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            validator: AuthValidators.email,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            scrollPadding: const EdgeInsets.all(AppSpace.md),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              hintText: 'you@example.com',
              errorMaxLines: 4,
              prefixIcon: Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          const PasswordField(
            validator: AuthValidators.loginPassword,
            textInputAction: TextInputAction.done,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                // TODO: Connect recovery; this notice never claims to send an email.
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Password recovery will be available soon.',
                      ),
                    ),
                  );
              },
              child: const Text('Forgot Password?'),
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _rememberMe,
            // UI preference only. No credentials or session state are persisted.
            onChanged: (value) => setState(() => _rememberMe = value ?? false),
            title: Text(
              'Remember Me',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          const AuthSubmitButton(label: 'Sign In'),
          const SizedBox(height: AppSpace.sm),
          const AuthDivider(),
          const SizedBox(height: AppSpace.sm),
          const GoogleAuthButton(label: 'Continue with Google'),
          const SizedBox(height: AppSpace.sm),
          Text(
            'Sign-in will be available soon.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    ),
    accountSwitch: AuthAccountSwitch(
      prompt: 'New to EEELibrary?',
      label: 'Create Account',
      onPressed: () => context.pushReplacement(AppRoutes.register),
    ),
  );
}
