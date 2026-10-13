import 'package:flutter/material.dart';

import '../../../core/constants/design_tokens.dart';

class WelcomeHero extends StatelessWidget {
  const WelcomeHero({super.key});
  static const assetPath = 'assets/images/welcome/eeelibrary_welcome_hero.png';
  static const sourceWidth = 1448;
  static const sourceHeight = 1086;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppSizes.welcomeHeroMaxWidth),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final decodeWidth =
              (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context))
                  .ceil()
                  .clamp(1, sourceWidth);
          return AspectRatio(
            aspectRatio: sourceWidth / sourceHeight,
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
              cacheWidth: decodeWidth,
              excludeFromSemantics: true,
            ),
          );
        },
      ),
    ),
  );
}
