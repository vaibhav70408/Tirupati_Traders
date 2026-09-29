import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/cart/cart_controller.dart';
import '../../application/checkout/checkout_controller.dart';
import '../../domain/entities/order.dart';
import '../../presentation/widgets/selectable_option.dart';
import '../../theme/app_colors.dart';
import 'order_placed_screen.dart';

class CheckoutScreen extends ConsumerWidget {
  const CheckoutScreen({super.key});

  Future<void> _placeOrder(BuildContext context, WidgetRef ref) async {
    final order = await ref
        .read(checkoutControllerProvider.notifier)
        .placeOrder();
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => OrderPlacedScreen(order: order)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(
      cartControllerProvider.select((c) => c.totalAmount),
    );
    final checkout = ref.watch(checkoutControllerProvider);
    final controller = ref.read(checkoutControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        title: const Text('Checkout'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const _SectionLabel('Delivery Method'),
          const SizedBox(height: 10),
          for (final method in DeliveryMethod.values) ...[
            SelectableOption(
              title: method.label,
              subtitle: method.description,
              selected: checkout.deliveryMethod == method,
              onTap: () => controller.selectDelivery(method),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
          const _SectionLabel('Payment Method'),
          const SizedBox(height: 10),
          for (final method in PaymentMethod.values) ...[
            SelectableOption(
              title: method.label,
              selected: checkout.paymentMethod == method,
              enabled: method == PaymentMethod.cash,
              onTap: () => controller.selectPayment(method),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.greenLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.green, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'After '
                    'the shop approves your final bill, you can also choose to '
                    'pay via UPI for a hassle-free experience.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.ink,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
            onPressed: checkout.isPlacing
                ? null
                : () => _placeOrder(context, ref),
            child: checkout.isPlacing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text('Place Order · ₹$total'),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.muted,
        letterSpacing: 0.4,
      ),
    );
  }
}
