import 'package:flutter/material.dart';

import '../../domain/entities/order.dart';
import '../../theme/app_colors.dart';
import 'track_order_screen.dart';

/// Confirmation shown after a successful checkout. The cart is already
/// cleared by the checkout controller before this screen is pushed.
class OrderPlacedScreen extends StatelessWidget {
  final Order order;

  const OrderPlacedScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.greenLight,
                  ),
                  alignment: Alignment.center,
                  child: const Text('✅', style: TextStyle(fontSize: 46)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Order Placed!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Order #${order.id} sent to Tirupati Traders. '
                "You'll be notified once it's approved & the final bill is ready."
                '\n\nAfter approval, you can also pay via UPI directly from the '
                'order screen for a hassle-free experience.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              _summaryCard(),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TrackOrderScreen(order: order),
                  ),
                ),
                child: const Text('Track Order'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.saffronDark,
                  side: const BorderSide(color: AppColors.saffron, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('Continue Shopping'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          _row('Items', '${order.itemCount}'),
          const Divider(height: 16, color: AppColors.line),
          _row('Delivery', order.deliveryMethod.label),
          const Divider(height: 16, color: AppColors.line),
          _row('Estimated', '₹${order.totalAmount}', bold: true),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: bold ? 15 : 12.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}
