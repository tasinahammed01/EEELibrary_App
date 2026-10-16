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
import 'manual_payment_form.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key, required this.id, this.repository});
  final String id;
  final PurchaseRepository? repository;
  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  OrderController? _controller;
  String? _identity;
  bool _payment = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AuthScope.maybeOf(context);
    _bind();
  }

  @override
  void didUpdateWidget(covariant OrderScreen old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id || old.repository != widget.repository) {
      _controller?.dispose();
      _controller = null;
      _identity = null;
      _payment = false;
      _bind();
    }
  }

  void _bind() {
    final key = widget.repository?.sessionKey;
    if (key == _identity && _controller != null) return;
    _controller?.dispose();
    _identity = key;
    _controller = key == null
        ? null
        : OrderController(widget.repository!, widget.id);
    if (_controller != null) unawaited(_controller!.load());
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Order review'),
      leading: IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.orders);
          }
        },
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.contentWidth),
          child: _body(context),
        ),
      ),
    ),
  );
  Widget _body(BuildContext context) {
    final controller = _controller;
    if (controller == null || widget.repository?.sessionKey != _identity) {
      return Center(
        child: TextButton(
          onPressed: () => context.go(AppRoutes.login),
          child: const Text('Sign in to view your order'),
        ),
      );
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.loading) return const CatalogLoading();
        final order = controller.order;
        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.md),
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              if (controller.error != null && (!_payment || order == null)) ...[
                CatalogNotice(
                  message: controller.error!.message,
                  onRetry: controller.busy ? null : controller.load,
                ),
                const SizedBox(height: AppSpace.sm),
              ],
              if (order != null) ...[
                Text(
                  order.book.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  order.priceLabel,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpace.xs),
                const Text(
                  'This amount was fixed by EEELibrary when the order was created.',
                ),
                const SizedBox(height: AppSpace.md),
                if (controller.access?.owned == true) ...[
                  const CatalogNotice(
                    message: 'Owned. This book is in your library. Secure reading is coming in a later phase.',
                  ),
                  const SizedBox(height: AppSpace.sm),
                  FilledButton(
                    onPressed: () => context.go(AppRoutes.library),
                    child: const Text('Open My Library'),
                  ),
                ] else if (order.stage == OrderStage.submitted) ...[
                  CatalogNotice(
                    message: controller.submitted
                        ? 'Reference submitted successfully. Pending admin review. No reading access has been granted yet.'
                        : 'Pending admin review. Your payment must be verified before access is granted.',
                  ),
                  const SizedBox(height: AppSpace.sm),
                  OutlinedButton(
                    onPressed: controller.load,
                    child: const Text('Refresh status'),
                  ),
                ] else if (order.stage == OrderStage.cancelled)
                  const CatalogNotice(
                    message: 'This order is cancelled. Browse the catalog to start a new order.',
                  )
                else if (order.stage == OrderStage.completed)
                  const CatalogNotice(
                    message: 'This order is complete, but reading access is currently unavailable. Contact support.',
                  )
                else ...[
                  if (order.paymentStatus == 'REJECTED') ...[
                    CatalogNotice(
                      message: order.rejectionReason ?? 'Payment was not approved. Check the instructions and use a new transaction reference.',
                    ),
                    const SizedBox(height: AppSpace.sm),
                  ],
                  if (controller.options.isEmpty)
                    const CatalogNotice(
                      message: 'Manual payment is not configured right now. Please try again later.',
                    )
                  else if (!_payment)
                    FilledButton(
                      onPressed: controller.busy
                          ? null
                          : () => setState(() => _payment = true),
                      child: const Text('Continue to payment'),
                    )
                  else if (controller.error != null &&
                      controller.error!.status != 0)
                    CatalogNotice(
                      message: controller.error!.message,
                      onRetry: controller.load,
                    )
                  else
                    ManualPaymentForm(
                      options: controller.options,
                      busy: controller.busy,
                      onSubmit: controller.submit,
                      errorMessage: controller.error?.message,
                    ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, this.repository});
  final PurchaseRepository? repository;
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  OrdersController? _controller;
  String? _identity;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AuthScope.maybeOf(context);
    final key = widget.repository?.sessionKey;
    if (key == _identity && _controller != null) return;
    _controller?.dispose();
    _identity = key;
    _controller = key == null ? null : OrdersController(widget.repository!);
    if (_controller != null) unawaited(_controller!.load());
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('My orders'),
      leading: IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.library);
          }
        },
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.contentWidth),
          child: _body(context),
        ),
      ),
    ),
  );
  Widget _body(BuildContext context) {
    final controller = _controller;
    if (controller == null || widget.repository?.sessionKey != _identity) {
      return const CatalogNotice(message: 'Sign in to view your orders.');
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => RefreshIndicator(
        onRefresh: controller.load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(AppSpace.md),
              sliver: SliverList.list(
                children: [
                  if (controller.loading) const CatalogLoading(),
                  if (controller.error != null)
                    CatalogNotice(
                      message: controller.error!.message,
                      onRetry: controller.orders.isEmpty
                          ? controller.load
                          : controller.more,
                    ),
                  if (!controller.loading &&
                      controller.error == null &&
                      controller.orders.isEmpty)
                    const CatalogNotice(
                      message: 'You have no orders yet. Browse the catalog to get started.',
                    ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
              sliver: SliverList.builder(
                itemCount: controller.orders.length,
                itemBuilder: (context, index) {
                  final order = controller.orders[index];
                  return Card(
                    child: ListTile(
                      title: Text(order.book.title),
                      subtitle: Text(
                        '${order.priceLabel}\n${switch (order.stage) {
                          OrderStage.pendingPayment => order.paymentStatus == 'REJECTED' ? 'Payment rejected — new reference required' : 'Awaiting payment',
                          OrderStage.submitted => 'Pending review',
                          OrderStage.completed => 'Order complete',
                          OrderStage.cancelled => 'Cancelled',
                        }}',
                      ),
                      isThreeLine: true,
                      onTap: () async {
                        await context.push(AppRoutes.orderPath(order.id));
                        if (mounted) await controller.load();
                      },
                    ),
                  );
                },
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(AppSpace.md),
              sliver: SliverList.list(
                children: [
                  if (controller.loadingMore)
                    const CatalogLoading()
                  else if (controller.hasMore)
                    OutlinedButton(
                      onPressed: controller.more,
                      child: const Text('Load more'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
