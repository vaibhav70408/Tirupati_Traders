import 'package:flutter/foundation.dart';

/// A confirmed payment recorded when an order is marked paid. Immutable audit
/// record written by the backend after Razorpay reports a captured payment.
@immutable
class PaymentTransaction {
  final String id;
  final String orderId;
  final String? customerId;
  final String customerName;
  final String? customerPhone;

  /// Amount captured, in paise.
  final int amountPaise;
  final String method;
  final String status;
  final String razorpayPaymentId;
  final String razorpayOrderId;
  final DateTime createdAt;

  const PaymentTransaction({
    required this.id,
    required this.orderId,
    this.customerId,
    required this.customerName,
    this.customerPhone,
    required this.amountPaise,
    required this.method,
    required this.status,
    required this.razorpayPaymentId,
    required this.razorpayOrderId,
    required this.createdAt,
  });

  /// Amount captured, in whole rupees.
  int get amountRupees => (amountPaise / 100).round();
}
