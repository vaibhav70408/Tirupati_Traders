import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/admin/order_admin_service.dart';
import '../../application/auth/auth_controller.dart';
import '../../application/notifications/admin_notifications_listener.dart';
import '../../application/notifications/notifications_controller.dart';
import '../../application/providers.dart';
import '../role_selection_screen.dart';
import '../../domain/entities/order.dart';
import '../../theme/app_colors.dart';
import 'admin_order_review_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_products_screen.dart';
import 'admin_transactions_screen.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _navIndex = 0;

  void _onNavSelected(int index) {
    switch (index) {
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminOrdersScreen()),
        );
        return;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminProductsScreen()),
        );
        return;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminTransactionsScreen()),
        );
        return;
      default:
        setState(() => _navIndex = index);
    }
  }

  @override
  void initState() {
    super.initState();
    // Start listening for newly placed orders so admins get instant alerts.
    ref.read(adminOrderNotificationsListenerProvider);
  }

  Future<void> _confirmLogout(BuildContext screenContext) async {
    final shouldLogout = await showDialog<bool>(
      context: screenContext,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will be logged out and returned to the role selection screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (shouldLogout != true || !mounted) return;
    await ref.read(authControllerProvider.notifier).signOut();
    if (!mounted) return;
    if (!screenContext.mounted) return;
    Navigator.of(screenContext).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersProvider);
    final orders = ordersAsync.value ?? const [];
    final adminName = ref.watch(currentAdminNameProvider);

    final notificationUnread = ref.watch(
      notificationsControllerProvider.select(
        (list) => list.where((n) => !n.read).length,
      ),
    );

    final pending = orders
        .where((o) => o.status == OrderStatus.placed)
        .toList();
    final toPack = orders
        .where((o) => o.status == OrderStatus.approved)
        .toList();
    final outForDelivery = orders
        .where((o) => o.status == OrderStatus.outForDelivery)
        .length;
    final totalSales = orders.fold<int>(0, (sum, o) => sum + o.totalAmount);
    final actionNeeded = pending.length + toPack.length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome back',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
            Text(
              adminName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _confirmLogout(context),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              onPressed: () {
                ref
                    .read(notificationsControllerProvider.notifier)
                    .markAllRead();
              },
              icon: Badge(
                isLabelVisible: notificationUnread > 0,
                label: Text('$notificationUnread'),
                child: const Icon(Icons.notifications_none),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 11,
            mainAxisSpacing: 11,
            childAspectRatio: 1.7,
            children: [
              _StatCard(
                value: '${pending.length}',
                label: 'Need Approval',
                color: const Color(0xFFE53935),
              ),
              _StatCard(
                value: '${toPack.length}',
                label: 'To Pack',
                color: AppColors.saffronDark,
              ),
              _StatCard(
                value: '$outForDelivery',
                label: 'Out for Delivery',
                color: const Color(0xFF1565C0),
              ),
              _StatCard(value: '₹$totalSales', label: "Today's Sales"),
            ],
          ),
          const SizedBox(height: 14),
          if (actionNeeded == 0)
            const _AllCaughtUp()
          else ...[
            if (pending.isNotEmpty) ...[
              _SectionHeader(
                title: 'Needs Approval',
                count: pending.length,
                color: const Color(0xFFE53935),
              ),
              for (final order in pending)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ActionOrderCard(order: order),
                ),
              const SizedBox(height: 6),
            ],
            if (toPack.isNotEmpty) ...[
              _SectionHeader(
                title: 'Ready to Pack',
                count: toPack.length,
                color: AppColors.saffronDark,
              ),
              for (final order in toPack)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ActionOrderCard(order: order),
                ),
            ],
          ],
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: _onNavSelected,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.greenLight,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            label: 'Payments',
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '($count)',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// A dashboard order card whose tag and primary action adapt to the order's
/// status: placed → Review, approved → Mark Out for Delivery.
class _ActionOrderCard extends ConsumerWidget {
  final Order order;
  const _ActionOrderCard({required this.order});

  bool get _isPending => order.status == OrderStatus.placed;

  Future<void> _dispatch(BuildContext context, WidgetRef ref) async {
    await ref.read(orderAdminServiceProvider).markOutForDelivery(order.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Order #${order.id} is out for delivery')),
    );
  }

  void _openDetails(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminOrderReviewScreen(order: order)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payment = order.paymentMethod == PaymentMethod.upi ? 'UPI' : 'Cash';
    final delivery = order.deliveryMethod == DeliveryMethod.homeDelivery
        ? 'Home delivery'
        : 'Pickup';

    final (tagLabel, tagColor) = _isPending
        ? ('NEW', const Color(0xFFE53935))
        : ('TO PACK', AppColors.saffronDark);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openDetails(context),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${order.id} · ${order.customerName}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        '${order.itemCount} items · ₹${order.totalAmount} · '
                        '$delivery · $payment · '
                        '${order.isPaid ? 'Paid' : 'Unpaid'}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: tagColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tagLabel,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: _isPending
                  ? ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                      onPressed: () => _openDetails(context),
                      icon: const Icon(Icons.fact_check_outlined, size: 18),
                      label: const Text('Review'),
                    )
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                      onPressed: () => _dispatch(context, ref),
                      icon: const Icon(Icons.local_shipping_outlined, size: 18),
                      label: const Text('Mark Out for Delivery'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllCaughtUp extends StatelessWidget {
  const _AllCaughtUp();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: const Column(
        children: [
          Icon(Icons.task_alt, size: 48, color: AppColors.green),
          SizedBox(height: 10),
          Text(
            'All caught up!',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'No orders waiting for approval or packing',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;
  const _StatCard({required this.value, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color ?? AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
