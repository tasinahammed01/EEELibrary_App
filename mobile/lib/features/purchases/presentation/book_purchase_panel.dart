import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/design_tokens.dart';
import '../../../core/routing/app_routes.dart';
import '../../auth/presentation/auth_scope.dart';
import '../../catalog/widgets/catalog_widgets.dart';
import '../data/purchase_repository.dart';
import '../domain/purchase_models.dart';
import 'purchase_controllers.dart';

class BookPurchasePanel extends StatefulWidget {
  const BookPurchasePanel({
    super.key,
    required this.slug,
    required this.free,
    this.repository,
  });
  final String slug;
  final bool free;
  final PurchaseRepository? repository;
  @override
  State<BookPurchasePanel> createState() => _BookPurchasePanelState();
}

class _BookPurchasePanelState extends State<BookPurchasePanel> {
  BookPurchaseController? _controller;
  String? _identity;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AuthScope.maybeOf(context);
    _bind();
  }

  @override
  void didUpdateWidget(covariant BookPurchasePanel old) {
    super.didUpdateWidget(old);
    if (old.slug != widget.slug || old.repository != widget.repository) {
      _controller?.dispose();
      _controller = null;
      _identity = null;
      _bind();
    }
  }

  void _bind() {
    final identity = widget.repository?.sessionKey;
    if (identity == _identity && _controller != null) return;
    _controller?.dispose();
    _identity = identity;
    _controller = identity == null
        ? null
        : BookPurchaseController(widget.repository!, widget.slug);
    if (_controller != null) unawaited(_controller!.load());
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _openOrder(String id) async {
    await context.push(AppRoutes.orderPath(id));
    if (mounted) await _controller?.load();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || widget.repository?.sessionKey != _identity) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CatalogNotice(message: 'Sign in to add books to your library.'),
          const SizedBox(height: AppSpace.sm),
          FilledButton(
            onPressed: () => context.push(AppRoutes.login),
            child: const Text('Sign in to get this book'),
          ),
        ],
      );
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.loading) return const CatalogLoading();
        final access = controller.access;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (controller.error != null)
              CatalogNotice(
                message: controller.error!.message,
                onRetry: controller.busy ? null : controller.load,
              ),
            if (controller.success != null)
              CatalogNotice(message: controller.success!),
            if (access?.owned == true) ...[
              const CatalogNotice(
                message: 'Owned. This book is in your library. Secure reading will be available in a later phase.',
              ),
              const SizedBox(height: AppSpace.sm),
              FilledButton(
                onPressed: () => context.go(AppRoutes.library),
                child: const Text('In Library'),
              ),
            ] else if (access?.order?.stage == OrderStage.submitted) ...[
              const CatalogNotice(
                message: 'Payment submitted. Pending admin review; access has not been granted yet.',
              ),
              const SizedBox(height: AppSpace.sm),
              OutlinedButton(
                onPressed: () => _openOrder(access!.order!.id),
                child: const Text('View order status'),
              ),
            ] else if (access?.order?.stage == OrderStage.completed)
              const CatalogNotice(
                message: 'Reading access is not available for this order. Contact support.',
              )
            else if (access?.order?.stage == OrderStage.pendingPayment) ...[
              if (access?.order?.paymentStatus == 'REJECTED')
                CatalogNotice(
                  message: access!.order!.rejectionReason ?? 'Payment was not approved. Review your payment and use a new reference.',
                ),
              const SizedBox(height: AppSpace.sm),
              FilledButton(
                onPressed: () => _openOrder(access!.order!.id),
                child: Text(
                  access?.order?.paymentStatus == 'REJECTED'
                      ? 'Review and resubmit'
                      : 'Continue order',
                ),
              ),
            ] else if (access != null && controller.error == null) ...[
              const SizedBox(height: AppSpace.sm),
              FilledButton(
                onPressed: controller.busy
                    ? null
                    : () async {
                        final order = await controller.acquire();
                        if (!mounted || order == null) return;
                        if (controller.access?.owned != true) {
                          await _openOrder(order.id);
                        }
                      },
                child: Text(
                  controller.busy
                      ? 'Please wait…'
                      : widget.free
                      ? 'Get free book'
                      : 'Buy book',
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
