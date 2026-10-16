import '../features/purchases/data/purchase_repository.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/routing/app_router.dart';
import '../core/routing/app_routes.dart';
import '../core/constants/design_tokens.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/auth_scope.dart';

class EEELibraryApp extends StatefulWidget {
  const EEELibraryApp({super.key, this.auth});
  final AuthController? auth;
  @override
  State<EEELibraryApp> createState() => _EEELibraryAppState();
}

class _EEELibraryAppState extends State<EEELibraryApp>
    with WidgetsBindingObserver {
  late final GoRouter _router;
  late final PurchaseRepository? _purchases = widget.auth == null
      ? null
      : PurchaseApi(widget.auth!);
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  bool _expiryAnnounced = false;
  @override
  void initState() {
    super.initState();
    _router = createAppRouter(auth: widget.auth, purchases: _purchases);
    WidgetsBinding.instance.addObserver(this);
    widget.auth?.addListener(_authChanged);
    widget.auth?.start();
  }

  void _authChanged() {
    final expired = widget.auth?.sessionExpired == true;
    if (expired == _expiryAnnounced) return;
    _expiryAnnounced = expired;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || expired != _expiryAnnounced) return;
      if (!expired) {
        _messenger.currentState?.hideCurrentSnackBar();
        return;
      }
      _messenger.currentState?.showSnackBar(
        SnackBar(
          content: Semantics(
            liveRegion: true,
            child: Row(
              children: [
                const ExcludeSemantics(
                  child: Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(width: AppSpace.xs),
                Expanded(child: Text(widget.auth!.message!)),
              ],
            ),
          ),
          action: SnackBarAction(
            label: 'Sign In',
            onPressed: () {
              _messenger.currentState?.hideCurrentSnackBar();
              _router.go(AppRoutes.login);
            },
          ),
        ),
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.auth != null) {
      unawaited(widget.auth!.refreshSession());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.auth?.removeListener(_authChanged);
    _router.dispose();
    _purchases?.close();
    widget.auth?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp.router(
      title: 'EEELibrary',
      scaffoldMessengerKey: _messenger,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    );
    return widget.auth == null
        ? app
        : AuthScope(controller: widget.auth!, child: app);
  }
}
