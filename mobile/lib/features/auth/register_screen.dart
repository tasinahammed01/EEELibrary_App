import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/design_tokens.dart';
import '../../core/routing/app_routes.dart';
import 'widgets/auth_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _acceptedTerms = false;
  @override
  Widget build(BuildContext context) => AuthLayout(
    title: 'Start your learning journey',
    subtitle: 'Make room for your next big idea.',
    children: [
      TextFormField(
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.name],
        decoration: const InputDecoration(
          labelText: 'Full Name',
          prefixIcon: Icon(Icons.person_outline),
        ),
      ),
      const SizedBox(height: AppSpace.sm),
      TextFormField(
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.email],
        autocorrect: false,
        decoration: const InputDecoration(
          labelText: 'Email',
          prefixIcon: Icon(Icons.mail_outline),
        ),
      ),
      const SizedBox(height: AppSpace.sm),
      const PasswordField(isNewPassword: true),
      const SizedBox(height: AppSpace.sm),
      const PasswordField(label: 'Confirm Password', isNewPassword: true),
      const SizedBox(height: AppSpace.xs),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: _acceptedTerms,
        onChanged: (value) => setState(() => _acceptedTerms = value ?? false),
        title: const Text('I agree to the Terms and Privacy Policy'),
      ),
      const SizedBox(height: AppSpace.sm),
      const FilledButton(
        // TODO: Connect registration and enforce published terms acceptance.
        onPressed: null,
        child: Text('Create Account'),
      ),
      const SizedBox(height: AppSpace.sm),
      const GoogleAuthButton(label: 'Sign up with Google'),
      const SizedBox(height: AppSpace.sm),
      const Text(
        'Account creation will be available soon.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: AppSpace.sm),
      TextButton(
        onPressed: () => context.pushReplacement(AppRoutes.login),
        child: const Text('Sign In'),
      ),
    ],
  );
}
