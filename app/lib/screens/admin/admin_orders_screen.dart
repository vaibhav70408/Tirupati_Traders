import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/entities/order.dart';
import '../../presentation/widgets/status_pill.dart';
import '../../theme/app_colors.dart';
import 'admin_order_review_screen.dart';

class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
  OrderStatus? _filter;

  List<Order> _apply(List<Order> orders) {
    if (_filter == null) return orders;
    return orders.where((o) => o.status == _filter).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load orders.\n$e')),
        data: (orders) {
          final filtered = _apply(orders);
          return Column(
            children: [
              _filters(),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'No orders here',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(14),
                        itemCount: filtered.length,
                        separatorBuilder: (_, i) => const SizedBox(height: 11),
                        itemBuilder: (_, i) =>
                            _AdminOrderCard(order: filtered[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filters() {
    final chips = <(String, OrderStatus?)>[
      ('All', null),
      ('Pending', OrderStatus.placed),
      ('Approved', OrderStatus.approved),
      ('Out for delivery', OrderStatus.outForDelivery),
      ('Delivered', OrderStatus.delivered),
      ('Declined', OrderStatus.declined),
    ];
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        itemCount: chips.length,
        separatorBuilder: (_, i) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (label, status) = chips[i];
          final on = _filter == status;
          return GestureDetector(
            onTap: () => setState(() => _filter = status),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? AppColors.saffron : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: on ? AppColors.saffron : AppColors.line,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: on ? Colors.white : AppColors.ink,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AdminOrderCard extends StatelessWidget {
  final Order order;
  const _AdminOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final payment = order.paymentMethod == PaymentMethod.upi ? 'UPI' : 'Cash';
    final delivery = order.deliveryMethod == DeliveryMethod.homeDelivery
        ? 'Home'
        : 'Pickup';
    final paidBadge = order.isPaid ? ' · Paid' : ' · Unpaid';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AdminOrderReviewScreen(order: order)),
      ),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '#${order.id} · ${order.customerName}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      if (order.isListOrder) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.greenLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'LIST',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.green,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₹${order.totalAmount} · $payment · $delivery$paidBadge',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            StatusPill(status: order.status),
          ],
        ),
      ),
    );
  }
}
