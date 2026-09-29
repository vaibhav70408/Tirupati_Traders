import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/order.dart';
import '../providers.dart';
import 'notifications_controller.dart';

/// Watches live orders and pushes an in-app notification whenever a new order
/// is placed. This gives admins an instant alert even while they are on another
/// admin screen.
class AdminNotificationsListener {
  final NotificationsController _notifications;
  final Stream<List<Order>> _ordersStream;

  var _previousOrderIds = <String>{};

  AdminNotificationsListener(this._notifications, this._ordersStream) {
    _ordersStream.listen(_onOrdersUpdated);
  }

  void _onOrdersUpdated(List<Order> orders) {
    final currentIds = orders.map((o) => o.id).toSet();

    // Only notify for genuinely new orders; skip the initial load.
    if (_previousOrderIds.isNotEmpty) {
      for (final order in orders) {
        if (!_previousOrderIds.contains(order.id) &&
            order.status == OrderStatus.placed) {
          _notifications.push(
            orderId: order.id,
            title: 'New order #${order.id}',
            body:
                '₹${order.totalAmount} · ${order.deliveryMethod.label} · '
                '${order.paymentMethod.label}',
          );
        }
      }
    }

    _previousOrderIds = currentIds;
  }
}

final adminOrderNotificationsListenerProvider = Provider<void>(
  (ref) => AdminNotificationsListener(
    ref.watch(notificationsControllerProvider.notifier),
    ref.watch(orderRepositoryProvider).watchOrders(),
  ),
);
