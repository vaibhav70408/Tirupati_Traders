import 'package:flutter/foundation.dart';

import '../../domain/entities/order.dart';

/// Selections made on the checkout screen, plus a submission flag.
@immutable
class CheckoutState {
  final DeliveryMethod deliveryMethod;
  final PaymentMethod paymentMethod;
  final bool isPlacing;

  const CheckoutState({
    this.deliveryMethod = DeliveryMethod.homeDelivery,
    this.paymentMethod = PaymentMethod.cash,
    this.isPlacing = false,
  });

  CheckoutState copyWith({
    DeliveryMethod? deliveryMethod,
    PaymentMethod? paymentMethod,
    bool? isPlacing,
  }) {
    return CheckoutState(
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isPlacing: isPlacing ?? this.isPlacing,
    );
  }
}
