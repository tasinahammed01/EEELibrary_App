import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/design_tokens.dart';
import '../../core/routing/app_routes.dart';
import 'presentation/auth_validators.dart';
import 'presentation/auth_scope.dart';
import 'widgets/auth_hero.dart';
import 'widgets/auth_widgets.dart';
import 'domain/auth_models.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _rememberMe = false;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _email.dispose();
    _password.clear();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState?.validate() != true) return;
    FocusScope.of(context).unfocus();
    AuthScope.read(context)?.login(_email.text, _password.text);
  }

  void _reset() {
    final auth = AuthScope.read(context);
    if (auth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password recovery will be available soon.'),
        ),
      );
      return;
    }
    if (AuthValidators.email(_email.text) != null) {
      _form.currentState?.validate();
      return;
    }
    FocusScope.of(context).unfocus();
    auth.resetPassword(_email.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.maybeOf(context);
    final valid =
        AuthValidators.email(_email.text) == null &&
        AuthValidators.loginPassword(_password.text) == null;
    return AuthLayout(
      busy: auth?.busy ?? false,
      title: 'Welcome Back!',
      subtitle: 'Sign in to your EEELibrary account\nand continue your learning journey.',
      artwork: AuthArtwork.login,
      form: Form(
        key: _form,
        onChanged: () => setState(() {}),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _email,
              enabled: !(auth?.busy ?? false),
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
            PasswordField(
              controller: _password,
              enabled: !(auth?.busy ?? false),
              validator: AuthValidators.loginPassword,
              textInputAction: TextInputAction.done,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: auth?.busy == true ? null : _reset,
                child: const Text('Forgot Password?'),
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _rememberMe,
              // UI preference only. No credentials or session state are persisted.
              onChanged: auth?.busy == true
                  ? null
                  : (value) => setState(() => _rememberMe = value ?? false),
              title: Text(
                'Remember Me',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: AppSpace.xs),
            AuthFeedback(
              message: auth?.message,
              tone: auth?.feedbackTone ?? AuthFeedbackTone.error,
            ),
            AuthSubmitButton(
              label: 'Sign In',
              busy: auth?.busy ?? false,
              onPressed: auth == null || auth.busy || !valid ? null : _submit,
            ),
            const SizedBox(height: AppSpace.sm),
            const AuthDivider(),
            const SizedBox(height: AppSpace.sm),
            GoogleAuthButton(
              label: 'Continue with Google',
              onPressed: auth == null || auth.busy ? null : auth.googleLogin,
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              auth == null
                  ? 'Sign-in will be available soon.'
                  : 'Your account is protected by Firebase sign-in.',
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
        onPressed: auth?.busy == true
            ? null
            : () => context.pushReplacement(AppRoutes.register),
      ),
    );
  }
}
