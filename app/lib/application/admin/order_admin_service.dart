import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/cart_item.dart';
import '../../domain/entities/order.dart';
import '../../domain/repositories/order_repository.dart';
import '../notifications/notifications_controller.dart';
import '../providers.dart';

/// Application-layer actions an admin performs on orders.
/// Keeps status transitions and change-detection out of the UI (SRP) and
/// depends on the [OrderRepository] abstraction (DIP).
class OrderAdminService {
  final OrderRepository _repository;
  final NotificationsController _notifications;

  const OrderAdminService(this._repository, this._notifications);

  /// Approves [order], persisting the admin-revised [revisedItems].
  /// If anything changed, notifies the customer with the new total.
  Future<void> approveWithRevision(
    Order order,
    List<CartItem> revisedItems,
  ) async {
    final modified = !listEquals(revisedItems, order.originalItems);
    await _repository.reviseAndApprove(
      orderId: order.id,
      items: revisedItems,
      modified: modified,
    );

    final newTotal = revisedItems.fold<int>(
      0,
      (sum, item) => sum + item.lineTotal,
    );

    final isListOrder = order.orderListImageUrls.isNotEmpty;
    final payNowText = newTotal > 0
        ? ' You can also pay ₹$newTotal via UPI now for a hassle-free experience.'
        : '';

    if (isListOrder) {
      _notifications.push(
        orderId: order.id,
        title: 'List order #${order.id} approved',
        body: newTotal > 0
            ? 'We received your list and prepared the bill. Total: ₹$newTotal.$payNowText'
            : 'We received your list and are preparing your order. We will share the final bill shortly.',
      );
      return;
    }

    if (modified) {
      _notifications.push(
        orderId: order.id,
        title: 'Order #${order.id} approved with changes',
        body:
            'The shop adjusted your order after checking stock & weights. '
            'Updated total: ₹$newTotal.$payNowText',
      );
    } else {
      _notifications.push(
        orderId: order.id,
        title: 'Order #${order.id} approved',
        body: 'Your order is confirmed. Total: ₹$newTotal.$payNowText',
      );
    }
  }

  Future<void> declineOrder(
    String orderId, {
    String reason = 'We are unable to fulfil this order right now.',
  }) async {
    await _repository.updateStatus(
      orderId: orderId,
      status: OrderStatus.declined,
    );
    _notifications.push(
      orderId: orderId,
      title: 'Order #$orderId declined',
      body: reason,
    );
  }

  Future<void> markOutForDelivery(String orderId) async {
    await _repository.updateStatus(
      orderId: orderId,
      status: OrderStatus.outForDelivery,
    );
    _notifications.push(
      orderId: orderId,
      title: 'Order #$orderId is out for delivery',
      body: 'Your order is on its way. It will reach you shortly.',
    );
  }

  Future<void> markDelivered(String orderId) async {
    await _repository.updateStatus(
      orderId: orderId,
      status: OrderStatus.delivered,
    );
    _notifications.push(
      orderId: orderId,
      title: 'Order #$orderId delivered',
      body: 'Your order has been delivered. Thank you for shopping with us!',
    );
  }

  /// Marks the order as paid and notifies the admin that payment was received.
  /// [paymentMethod] is passed when the customer pays via UPI; omitted when
  /// the admin confirms cash on delivery / pickup payment.
  Future<void> markPaid(String orderId, {PaymentMethod? paymentMethod}) async {
    await _repository.markPaid(orderId: orderId, paymentMethod: paymentMethod);
    _notifications.push(
      orderId: orderId,
      title: 'Payment received',
      body: 'Order #$orderId has been marked as paid.',
    );
  }
}

final orderAdminServiceProvider = Provider<OrderAdminService>(
  (ref) => OrderAdminService(
    ref.watch(orderRepositoryProvider),
    ref.read(notificationsControllerProvider.notifier),
  ),
);
