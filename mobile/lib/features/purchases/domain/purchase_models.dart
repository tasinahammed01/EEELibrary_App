import '../../catalog/domain/catalog_models.dart';

enum OrderStage { pendingPayment, submitted, completed, cancelled }

class PurchaseFailure implements Exception {
  const PurchaseFailure([this.status = 0]);
  final int status;
  String get message => switch (status) {
    400 => 'Check the payment method and reference, then try again.',
    401 => 'Your session expired. Please sign in again.',
    403 => 'This account cannot complete this action. Contact support.',
    404 => 'This order or resource is not available.',
    409 => 'The order or payment has changed. Refresh its status before trying again.',
    >= 500 => 'EEELibrary is temporarily unavailable. Please try again later.',
    _ =>
      "We couldn't connect to EEELibrary. Check your connection and try again.",
  };
}

Map<String, dynamic> object(Object? value) {
  if (value is! Map<String, dynamic>) throw const FormatException();
  return value;
}

String text(Map<String, dynamic> value, String key) {
  final result = value[key];
  if (result is! String || result.isEmpty) throw const FormatException();
  return result;
}

String moneyAmount(Map<String, dynamic> value, String key) {
  final result = text(value, key);
  final parsed = double.tryParse(result);
  if (parsed == null || !parsed.isFinite || parsed < 0) {
    throw const FormatException();
  }
  return result;
}

class PurchaseOrder {
  const PurchaseOrder({
    required this.id,
    required this.book,
    required this.amount,
    required this.currency,
    required this.stage,
    this.paymentStatus,
    this.rejectionReason,
  });
  final String id, amount, currency;
  final CatalogBook book;
  final OrderStage stage;
  final String? paymentStatus, rejectionReason;
  String get priceLabel => '$currency $amount';
  factory PurchaseOrder.fromJson(Object? value) {
    final json = object(value);
    final stage = switch (text(json, 'status')) {
      'PENDING_PAYMENT' => OrderStage.pendingPayment,
      'PAYMENT_SUBMITTED' => OrderStage.submitted,
      'COMPLETED' => OrderStage.completed,
      'CANCELLED' => OrderStage.cancelled,
      _ => throw const FormatException(),
    };
    final payments = json['payments'];
    if (payments is! List || payments.length > 1) throw const FormatException();
    final latest = payments.isEmpty ? null : object(payments.first);
    final paymentStatus = latest == null ? null : text(latest, 'status');
    if (paymentStatus != null &&
        !{'PENDING', 'APPROVED', 'REJECTED'}.contains(paymentStatus)) {
      throw const FormatException();
    }
    final reason = latest?['rejectionReason'];
    final safeReason = switch (reason) {
      'REFERENCE_NOT_FOUND' => 'The payment reference could not be verified. Check it and submit a new reference.',
      'AMOUNT_MISMATCH' => 'The payment amount did not match the order. Check the instructions before submitting a new reference.',
      'METHOD_MISMATCH' => 'The payment method did not match. Check the instructions and use a new reference.',
      _ => null,
    };
    return PurchaseOrder(
      id: text(json, 'id'),
      book: CatalogBook.fromJson(object(json['book'])),
      amount: moneyAmount(json, 'amount'),
      currency: text(json, 'currency'),
      stage: stage,
      paymentStatus: paymentStatus,
      rejectionReason: safeReason,
    );
  }
}

class BookAccess {
  const BookAccess({required this.owned, this.order});
  final bool owned;
  final PurchaseOrder? order;
  factory BookAccess.fromJson(Object? value) {
    final json = object(value);
    if (json['owned'] is! bool) throw const FormatException();
    return BookAccess(
      owned: json['owned'] as bool,
      order: json['order'] == null
          ? null
          : PurchaseOrder.fromJson(json['order']),
    );
  }
}

class ManualPaymentOption {
  const ManualPaymentOption({
    required this.method,
    required this.instructions,
    required this.development,
  });
  final String method, instructions;
  final bool development;
  factory ManualPaymentOption.fromJson(Object? value) {
    final json = object(value);
    final method = text(json, 'method');
    if (!{'BKASH', 'NAGAD'}.contains(method) || json['development'] is! bool) {
      throw const FormatException();
    }
    return ManualPaymentOption(
      method: method,
      instructions: text(json, 'instructions'),
      development: json['development'] as bool,
    );
  }
}

class OrderPage {
  const OrderPage(this.items, this.hasMore);
  final List<PurchaseOrder> items;
  final bool hasMore;
  factory OrderPage.fromJson(Object? value) {
    final json = object(value);
    final items = json['items'];
    if (items is! List || items.length > 40 || json['hasMore'] is! bool) {
      throw const FormatException();
    }
    return OrderPage(
      List.unmodifiable(items.map(PurchaseOrder.fromJson)),
      json['hasMore'] as bool,
    );
  }
}
