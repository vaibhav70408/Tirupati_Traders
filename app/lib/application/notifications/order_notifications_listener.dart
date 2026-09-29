import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/order.dart';
import '../providers.dart';
import 'notifications_controller.dart';

/// Watches live orders and pushes an in-app notification whenever an order
/// status changes to a customer-relevant milestone.
class OrderNotificationsListener {
  final NotificationsController _notifications;
  final Stream<List<Order>> _ordersStream;

  var _previousOrders = <String, Order>{};

  OrderNotificationsListener(this._notifications, this._ordersStream) {
    _ordersStream.listen(_onOrdersUpdated);
  }

  void _onOrdersUpdated(List<Order> orders) {
    final current = {for (final o in orders) o.id: o};

    for (final entry in current.entries) {
      final order = entry.value;
      final previous = _previousOrders[order.id];

      if (previous == null || previous.status == order.status) continue;

      _maybeNotify(order, previous.status);
    }

    _previousOrders = current;
  }

  void _maybeNotify(Order order, OrderStatus previousStatus) {
    switch (order.status) {
      case OrderStatus.approved:
        final body = order.modifiedByAdmin
            ? 'The shop adjusted your order after checking stock & weights. '
                  'Updated total: ₹${order.totalAmount}.'
            : 'Your order is confirmed. Total: ₹${order.totalAmount}.';
        _notifications.push(
          orderId: order.id,
          title: 'Order #${order.id} approved',
          body: body,
        );
      case OrderStatus.outForDelivery:
        _notifications.push(
          orderId: order.id,
          title: 'Order #${order.id} is out for delivery',
          body: 'Your order is on the way. It will reach you shortly.',
        );
      case OrderStatus.delivered:
        _notifications.push(
          orderId: order.id,
          title: 'Order #${order.id} delivered',
          body:
              'Your order has been delivered. Thank you for shopping with us!',
        );
      case OrderStatus.placed:
        break; // no-op: customer already knows they placed it.
      case OrderStatus.declined:
        break; // handled by the admin service declineOrder notification.
    }
  }
}

final customerOrderNotificationsListenerProvider = Provider<void>(
  (ref) => OrderNotificationsListener(
    ref.watch(notificationsControllerProvider.notifier),
    ref.watch(orderRepositoryProvider).watchOrders(),
  ),
);
