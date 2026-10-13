import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:eeelibrary/core/routing/app_router.dart';
import 'package:eeelibrary/core/theme/app_theme.dart';
import 'package:eeelibrary/features/auth/presentation/auth_validators.dart';
import 'package:eeelibrary/features/auth/widgets/auth_hero.dart';
import 'package:eeelibrary/features/auth/widgets/auth_widgets.dart';

void main() {
  Finder field(String label) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label,
  );
  Future<GoRouter> start(WidgetTester tester, String path) async {
    final router = createAppRouter(initialLocation: path);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> fill(WidgetTester tester, String label, String value) async {
    await tester.ensureVisible(field(label));
    await tester.pumpAndSettle();
    await tester.enterText(field(label), value);
    await tester.pumpAndSettle();
  }

  test(
    'Field feedback handles blank names, trimmed emails and password mismatch',
    () {
      expect(AuthValidators.fullName('  '), isNotNull);
      expect(AuthValidators.fullName(' EEE Learner '), isNull);
      for (final value in [
        '',
        'abc',
        'a@',
        'a b@school.com',
        'a@b@school.com',
      ]) {
        expect(AuthValidators.email(value), isNotNull);
      }
      expect(AuthValidators.email(' learner@school.edu '), isNull);
      expect(AuthValidators.newPassword('short'), isNotNull);
      expect(AuthValidators.newPassword('        '), isNotNull);
      expect(AuthValidators.newPassword('Learn123'), isNull);
      expect(AuthValidators.confirmation('Learn124', 'Learn123'), isNotNull);
      expect(AuthValidators.confirmation('Learn123', 'Learn123'), isNull);
    },
  );
  testWidgets('Both production assets are registered and decode', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      expect(
        manifest.listAssets().where((p) => p.startsWith('design_refs/')),
        isEmpty,
      );
      for (final artwork in AuthArtwork.values) {
        expect(manifest.listAssets(), contains(artwork.assetPath));
        final data = await rootBundle.load(artwork.assetPath);
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        final frame = await codec.getNextFrame();
        expect(frame.image.width, AuthHero.sourceWidth);
        expect(frame.image.height, AuthHero.sourceHeight);
        frame.image.dispose();
        codec.dispose();
      }
    });
  });
  for (final entry in [
    ('/login', 'Welcome Back!', AuthArtwork.login),
    ('/register', 'Create Your Account', AuthArtwork.register),
  ]) {
    testWidgets(
      '${entry.$1} shows correct artwork and safely unavailable actions',
      (tester) async {
        await start(tester, entry.$1);
        expect(find.text('EEELibrary'), findsOneWidget);
        expect(find.text(entry.$2), findsOneWidget);
        expect(
          tester.widget<AuthHero>(find.byType(AuthHero)).artwork,
          entry.$3,
        );
        final image = tester.widget<Image>(find.byType(Image));
        expect(
          ((image.image as ResizeImage).imageProvider as AssetImage).assetName,
          entry.$3.assetPath,
        );
        expect(image.fit, BoxFit.contain);
        expect(image.excludeFromSemantics, isTrue);
        expect(field('Email Address'), findsOneWidget);
        expect(tester.widget<TextField>(field('Password')).obscureText, isTrue);
        expect(find.byType(GoogleAuthButton), findsOneWidget);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        expect(
          tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
          isNull,
        );
        if (entry.$1 == '/register') {
          expect(field('Full Name'), findsOneWidget);
          expect(
            tester.widget<TextField>(field('Confirm Password')).obscureText,
            isTrue,
          );
        } else {
          expect(find.text('Forgot Password?'), findsOneWidget);
          expect(find.text('Remember Me'), findsOneWidget);
        }
      },
    );
    testWidgets('${entry.$1} account switch and back retain existing routes', (
      tester,
    ) async {
      final router = await start(tester, entry.$1);
      final action = find.descendant(
        of: find.byType(AuthAccountSwitch),
        matching: find.byType(TextButton),
      );
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        entry.$1 == '/login' ? '/register' : '/login',
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/welcome',
      );
    });
  }
  testWidgets(
    'Remember Me resets when leaving login; recovery is only an availability notice',
    (tester) async {
      final router = await start(tester, '/login');
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
      await tester.ensureVisible(find.text('Forgot Password?'));
      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();
      expect(
        find.text('Password recovery will be available soon.'),
        findsOneWidget,
      );
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/login',
      );
      router.go('/welcome');
      await tester.pumpAndSettle();
      router.go('/login');
      await tester.pumpAndSettle();
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
    },
  );
  testWidgets(
    'Confirmation follows password edits; valid inputs never create an account',
    (tester) async {
      final router = await start(tester, '/register');
      await fill(tester, 'Full Name', 'EEE Learner');
      await fill(tester, 'Email Address', ' learner@example.com ');
      await fill(tester, 'Password', 'short');
      expect(find.text('Use at least 8 characters.'), findsOneWidget);
      await fill(tester, 'Password', 'Learning123');
      await fill(tester, 'Confirm Password', 'Different123');
      expect(find.text('Passwords do not match.'), findsOneWidget);
      await fill(tester, 'Confirm Password', 'Learning123');
      expect(find.text('Passwords do not match.'), findsNothing);
      await fill(tester, 'Password', 'Changed123');
      expect(find.text('Passwords do not match.'), findsOneWidget);
      await fill(tester, 'Confirm Password', 'Changed123');
      expect(find.text('Passwords do not match.'), findsNothing);
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/register',
      );
    },
  );
  testWidgets(
    'Login Next advances to password; Done releases focus without signing in',
    (tester) async {
      final router = await start(tester, '/login');
      await fill(tester, 'Email Address', 'learner@example.com');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: field('Password'),
                matching: find.byType(EditableText),
              ),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
      await fill(tester, 'Password', 'Learning123');
      await tester.ensureVisible(find.byTooltip('Show password'));
      await tester.tap(find.byTooltip('Show password'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field('Password')).controller!.text,
        'Learning123',
      );
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: field('Password'),
                matching: find.byType(EditableText),
              ),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: field('Password'),
                matching: find.byType(EditableText),
              ),
            )
            .focusNode
            .hasFocus,
        isFalse,
      );
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/login',
      );
    },
  );
}
