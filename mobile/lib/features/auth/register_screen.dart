import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/design_tokens.dart';
import '../../core/routing/app_routes.dart';
import 'presentation/auth_validators.dart';
import 'presentation/auth_scope.dart';
import 'widgets/auth_hero.dart';
import 'widgets/auth_widgets.dart';
import 'domain/auth_models.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _acceptedTerms = false;
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  void _submit() {
    if (!_acceptedTerms || _form.currentState?.validate() != true) return;
    FocusScope.of(context).unfocus();
    AuthScope.read(context)?.register(_name.text, _email.text, _password.text);
  }

  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _confirmationKey = GlobalKey<FormFieldState<String>>();
  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.clear();
    _confirmation.clear();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.maybeOf(context);
    final valid =
        _acceptedTerms &&
        AuthValidators.fullName(_name.text) == null &&
        AuthValidators.email(_email.text) == null &&
        AuthValidators.newPassword(_password.text) == null &&
        AuthValidators.confirmation(_confirmation.text, _password.text) == null;
    return AuthLayout(
      busy: auth?.busy ?? false,
      title: 'Create Your Account',
      subtitle:
          'Join EEELibrary and get access to books,\nnotes, MCQs and more.',
      artwork: AuthArtwork.register,
      form: Form(
        key: _form,
        onChanged: () => setState(() {}),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              enabled: !(auth?.busy ?? false),
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
              controller: _email,
              enabled: !(auth?.busy ?? false),
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
              enabled: !(auth?.busy ?? false),
              validator: AuthValidators.newPassword,
              isNewPassword: true,
              helperText: 'Use at least 8 characters with a mix of letters and numbers.',
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
              enabled: !(auth?.busy ?? false),
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
              onChanged: auth?.busy == true
                  ? null
                  : (value) => setState(() => _acceptedTerms = value ?? false),
              title: Text(
                'I agree to the Terms and Privacy Policy',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(height: 1.5),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            AuthFeedback(
              message: auth?.message,
              tone: auth?.feedbackTone ?? AuthFeedbackTone.error,
            ),
            AuthSubmitButton(
              label: 'Create Account',
              busy: auth?.busy ?? false,
              onPressed: auth == null || auth.busy || !valid ? null : _submit,
            ),
            const SizedBox(height: AppSpace.sm),
            const AuthDivider(),
            const SizedBox(height: AppSpace.sm),
            GoogleAuthButton(
              label: 'Sign up with Google',
              onPressed: auth == null || auth.busy || !_acceptedTerms
                  ? null
                  : auth.googleLogin,
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              auth == null
                  ? 'Account creation will be available soon.'
                  : 'Verify your email to finish setting up your account.',
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
        onPressed: auth?.busy == true
            ? null
            : () => context.pushReplacement(AppRoutes.login),
      ),
    );
  }
}
