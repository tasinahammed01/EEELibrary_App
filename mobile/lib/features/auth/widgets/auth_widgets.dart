import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/design_tokens.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/page_body.dart';
import 'auth_hero.dart';

export 'auth_feedback.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.artwork,
    required this.form,
    required this.accountSwitch,
    this.busy = false,
  });
  final bool busy;
  final String title;
  final String subtitle;
  final AuthArtwork artwork;
  final Widget form;
  final Widget accountSwitch;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        toolbarHeight: AppSizes.touchTarget,
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: busy
              ? null
              : () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(AppRoutes.welcome);
                  }
                },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: PageBody(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: AppSpace.xs,
        ),
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: Brand(prominent: true)),
              const SizedBox(height: AppSpace.sm),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.8,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.muted, height: 1.4),
              ),
              const SizedBox(height: AppSpace.xs),
              AuthHero(artwork: artwork),
              const SizedBox(height: AppSpace.sm),
              Material(
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: AppColors.outline),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.sm),
                  child: form,
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              accountSwitch,
            ],
          ),
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
    this.controller,
    this.validator,
    this.onChanged,
    this.helperText,
    this.textInputAction = TextInputAction.next,
    this.fieldKey,
    this.enabled = true,
  });
  final String label;
  final bool enabled;
  final bool isNewPassword;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final String? helperText;
  final TextInputAction textInputAction;
  final GlobalKey<FormFieldState<String>>? fieldKey;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;
  final _toggleFocus = FocusNode(skipTraversal: true, canRequestFocus: false);
  @override
  void dispose() {
    _toggleFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    key: widget.fieldKey,
    enabled: widget.enabled,
    controller: widget.controller,
    validator: widget.validator,
    onChanged: widget.onChanged,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    obscureText: _obscure,
    enableSuggestions: false,
    autocorrect: false,
    scrollPadding: const EdgeInsets.all(AppSpace.md),
    autofillHints: [
      widget.isNewPassword ? AutofillHints.newPassword : AutofillHints.password,
    ],
    textInputAction: widget.textInputAction,
    onFieldSubmitted: widget.textInputAction == TextInputAction.done
        ? (_) => FocusScope.of(context).unfocus()
        : null,
    decoration: InputDecoration(
      labelText: widget.label,
      hintText: widget.isNewPassword
          ? 'Choose a password'
          : 'Enter your password',
      helperText: widget.helperText,
      helperMaxLines: 12,
      errorMaxLines: 4,
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: IconButton(
        focusNode: _toggleFocus,
        constraints: const BoxConstraints(
          minWidth: AppSizes.touchTarget,
          minHeight: AppSizes.touchTarget,
        ),
        tooltip: '${_obscure ? 'Show' : 'Hide'} ${widget.label.toLowerCase()}',
        onPressed: widget.enabled
            ? () => setState(() => _obscure = !_obscure)
            : null,
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    ),
  );
}

class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(child: Divider(color: AppColors.outline)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
        child: Text(
          'OR',
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: AppColors.muted, letterSpacing: 1),
        ),
      ),
      const Expanded(child: Divider(color: AppColors.outline)),
    ],
  );
}

class GoogleAuthButton extends StatelessWidget {
  const GoogleAuthButton({super.key, required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => OutlinedButton(
    style: OutlinedButton.styleFrom(
      backgroundColor: AppColors.surface,
      disabledForegroundColor: AppColors.muted,
      side: const BorderSide(color: AppColors.outline),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.xs,
        vertical: AppSpace.sm,
      ),
    ),
    onPressed: onPressed,
    child: Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpace.xs,
      runSpacing: AppSpace.xs,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpace.xs),
          decoration: BoxDecoration(
            color: AppColors.blueTint,
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          child: const Text(
            'G',
            style: TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(label, textAlign: TextAlign.center),
      ],
    ),
  );
}

class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    this.onPressed,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    child: Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpace.xs,
      children: [
        Text(label),
        if (busy)
          const SizedBox(
            width: AppSpace.md,
            height: AppSpace.md,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              semanticsLabel: 'Authentication in progress',
              color: AppColors.blue,
            ),
          )
        else
          const Icon(Icons.arrow_forward_rounded),
      ],
    ),
  );
}

class AuthAccountSwitch extends StatelessWidget {
  const AuthAccountSwitch({
    super.key,
    required this.prompt,
    required this.label,
    required this.onPressed,
  });
  final String prompt;
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.blueTint,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
      side: const BorderSide(color: AppColors.outline),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.sm),
      child: Column(
        children: [
          Text(
            prompt,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpace.xs),
          TextButton(
            onPressed: onPressed,
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpace.xs,
              children: [
                Text(label),
                const Icon(Icons.arrow_forward_rounded, size: AppSpace.sm),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
