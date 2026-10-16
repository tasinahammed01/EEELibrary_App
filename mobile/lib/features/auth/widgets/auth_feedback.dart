import 'package:flutter/material.dart';

import '../../../core/constants/design_tokens.dart';
import '../domain/auth_models.dart';

/// Persistent, non-blocking form feedback; validation remains on its own field.
class AuthFeedback extends StatelessWidget {
  const AuthFeedback({
    super.key,
    this.message,
    this.tone = AuthFeedbackTone.error,
  });
  final String? message;
  final AuthFeedbackTone tone;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final (background, foreground, icon) = switch (tone) {
      AuthFeedbackTone.error => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        Icons.error_outline_rounded,
      ),
      AuthFeedbackTone.notice => (
        dark ? scheme.secondaryContainer : AppColors.goldTint,
        dark ? scheme.onSecondaryContainer : AppColors.navy,
        Icons.info_outline_rounded,
      ),
      AuthFeedbackTone.success => (
        dark ? scheme.primaryContainer : AppColors.blueTint,
        dark ? scheme.onPrimaryContainer : AppColors.navy,
        Icons.check_circle_outline_rounded,
      ),
    };
    return AnimatedSize(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : kThemeAnimationDuration,
      alignment: Alignment.topCenter,
      child: message == null || message!.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.sm),
              child: Semantics(
                container: true,
                liveRegion: true,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    border: Border.all(color: foreground.withValues(alpha: .2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            icon,
                            size: AppSpace.md,
                            color: foreground,
                          ),
                        ),
                        const SizedBox(width: AppSpace.xs),
                        Expanded(
                          child: Text(
                            message!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: foreground, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
