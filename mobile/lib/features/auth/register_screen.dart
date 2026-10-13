import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/design_tokens.dart';
import '../../core/routing/app_routes.dart';
import 'presentation/auth_validators.dart';
import 'widgets/auth_hero.dart';
import 'widgets/auth_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _acceptedTerms = false;
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _confirmationKey = GlobalKey<FormFieldState<String>>();
  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthLayout(
    title: 'Create Your Account',
    subtitle: 'Join EEELibrary and get access to books,\nnotes, MCQs and more.',
    artwork: AuthArtwork.register,
    form: Form(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            validator: AuthValidators.fullName,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            scrollPadding: const EdgeInsets.all(AppSpace.md),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(
              labelText: 'Full Name',
              hintText: 'Your full name',
              errorMaxLines: 4,
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          TextFormField(
            validator: AuthValidators.email,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            scrollPadding: const EdgeInsets.all(AppSpace.md),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              hintText: 'you@example.com',
              errorMaxLines: 4,
              prefixIcon: Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          PasswordField(
            controller: _password,
            validator: AuthValidators.newPassword,
            isNewPassword: true,
            helperText:
                'Use at least 8 characters with a mix of letters and numbers.',
            onChanged: (_) {
              if (_confirmation.text.isNotEmpty) {
                _confirmationKey.currentState?.validate();
              }
            },
          ),
          const SizedBox(height: AppSpace.sm),
          PasswordField(
            fieldKey: _confirmationKey,
            controller: _confirmation,
            validator: (value) =>
                AuthValidators.confirmation(value, _password.text),
            label: 'Confirm Password',
            isNewPassword: true,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: AppSpace.xs),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _acceptedTerms,
            onChanged: (value) =>
                setState(() => _acceptedTerms = value ?? false),
            title: Text(
              'I agree to the Terms and Privacy Policy',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(height: 1.5),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          const AuthSubmitButton(label: 'Create Account'),
          const SizedBox(height: AppSpace.sm),
          const AuthDivider(),
          const SizedBox(height: AppSpace.sm),
          const GoogleAuthButton(label: 'Sign up with Google'),
          const SizedBox(height: AppSpace.sm),
          Text(
            'Account creation will be available soon.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    ),
    accountSwitch: AuthAccountSwitch(
      prompt: 'Already have an account?',
      label: 'Sign In',
      onPressed: () => context.pushReplacement(AppRoutes.login),
    ),
  );
}
