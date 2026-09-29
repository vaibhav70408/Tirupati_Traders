import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/order.dart';
import '../auth/auth_controller.dart';
import '../cart/cart_controller.dart';
import '../providers.dart';
import 'checkout_state.dart';

/// Drives the checkout screen: method selection and order placement.
/// Clears the cart once an order is successfully placed.
class CheckoutController extends Notifier<CheckoutState> {
  @override
  CheckoutState build() => const CheckoutState();

  void selectDelivery(DeliveryMethod method) {
    state = state.copyWith(deliveryMethod: method);
  }

  void selectPayment(PaymentMethod method) =>
      state = state.copyWith(paymentMethod: method);

  Future<Order> placeOrder() async {
    final cart = ref.read(cartControllerProvider);
    final firebaseUser = ref.read(authRepositoryProvider).currentUser;
    final profile = ref.read(currentUserProfileProvider).asData?.value;
    final customerName =
        profile?.name ?? firebaseUser?.phoneNumber ?? 'Customer';
    final customerId = firebaseUser?.uid;
    final customerPhone = firebaseUser?.phoneNumber ?? profile?.phoneNumber;
    final customerAddress = profile?.address;

    state = state.copyWith(isPlacing: true);
    try {
      final order = await ref
          .read(orderRepositoryProvider)
          .placeOrder(
            items: cart.items,
            deliveryMethod: state.deliveryMethod,
            paymentMethod: state.paymentMethod,
            customerName: customerName,
            customerId: customerId,
            customerPhone: customerPhone,
            customerAddress: customerAddress,
          );
      // Home delivery defaults to COD at checkout; UPI is enabled after admin
      // approval. Pickup orders may be paid upfront via UPI.
      ref.read(cartControllerProvider.notifier).clear();
      return order;
    } finally {
      state = state.copyWith(isPlacing: false);
    }
  }
}

final checkoutControllerProvider =
    NotifierProvider<CheckoutController, CheckoutState>(CheckoutController.new);
