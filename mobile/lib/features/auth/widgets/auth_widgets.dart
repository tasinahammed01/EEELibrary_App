import 'package:flutter/material.dart';

import '../../../core/constants/design_tokens.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/page_body.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });
  final String title;
  final String subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: PageBody(
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(alignment: Alignment.centerLeft, child: Brand()),
            const SizedBox(height: AppSpace.lg),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpace.md),
            ...children,
          ],
        ),
      ),
    ),
  );
}

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    this.label = 'Password',
    this.isNewPassword = false,
  });
  final String label;
  final bool isNewPassword;
  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;
  @override
  Widget build(BuildContext context) => TextFormField(
    obscureText: _obscure,
    enableSuggestions: false,
    autocorrect: false,
    autofillHints: [
      widget.isNewPassword ? AutofillHints.newPassword : AutofillHints.password,
    ],
    textInputAction: widget.label == 'Confirm Password'
        ? TextInputAction.done
        : TextInputAction.next,
    decoration: InputDecoration(
      labelText: widget.label,
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: IconButton(
        tooltip: '${_obscure ? 'Show' : 'Hide'} ${widget.label.toLowerCase()}',
        onPressed: () => setState(() => _obscure = !_obscure),
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    ),
  );
}

class GoogleAuthButton extends StatelessWidget {
  const GoogleAuthButton({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    // TODO: Connect Google authentication when auth integration is ready.
    onPressed: null,
    icon: const Icon(Icons.account_circle_outlined),
    label: Text(label, textAlign: TextAlign.center),
  );
}
