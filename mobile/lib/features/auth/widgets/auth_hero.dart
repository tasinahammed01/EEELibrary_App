import 'package:flutter/material.dart';

import '../../../core/constants/design_tokens.dart';

enum AuthArtwork {
  login('assets/images/auth/eeelibrary_login_hero.jpg'),
  register('assets/images/auth/eeelibrary_register_hero.jpg');

  const AuthArtwork(this.assetPath);
  final String assetPath;
}

class AuthHero extends StatelessWidget {
  const AuthHero({super.key, required this.artwork});
  final AuthArtwork artwork;
  static const sourceWidth = 1448;
  static const sourceHeight = 1086;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppSizes.welcomeHeroMaxWidth),
      child: LayoutBuilder(
        builder: (context, constraints) => AspectRatio(
          aspectRatio: sourceWidth / sourceHeight,
          child: Image.asset(
            artwork.assetPath,
            fit: BoxFit.contain,
            cacheWidth:
                (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context))
                    .ceil()
                    .clamp(1, sourceWidth),
            excludeFromSemantics: true,
          ),
        ),
      ),
    ),
  );
}
