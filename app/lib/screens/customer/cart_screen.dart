import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/cart/cart_controller.dart';
import '../../application/cart/cart_state.dart';
import '../../application/providers.dart';
import '../../domain/entities/cart_item.dart';
import '../../presentation/utils/product_display_name.dart';
import '../../presentation/utils/quantity_formatter.dart';
import '../../presentation/widgets/quantity_stepper.dart';
import '../../theme/app_colors.dart';
import 'checkout_screen.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        title: Text('My Cart (${cart.distinctItemCount})'),
      ),
      body: cart.isEmpty ? const _EmptyCart() : _CartBody(cart: cart),
      bottomNavigationBar: cart.isEmpty ? null : _CheckoutBar(cart: cart),
    );
  }
}

class _CartBody extends ConsumerWidget {
  final CartState cart;
  const _CartBody({required this.cart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(cartControllerProvider.notifier);
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        for (final item in cart.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: _CartRow(
              item: item,
              onIncrement: () => controller.increment(item.product.id),
              onDecrement: () => controller.decrement(item.product.id),
            ),
          ),
        const SizedBox(height: 4),
        _Summary(cart: cart),
      ],
    );
  }
}

class _CartRow extends ConsumerWidget {
  final CartItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _CartRow({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider).value ?? const [];
    final productsById = {for (final p in products) p.id: p};
    final displayName = productDisplayName(item.product, productsById);

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.greenLight,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              item.product.emoji,
              style: const TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '₹${item.unitPrice}/${formatProductQuantity(item.quantity, item.product, showQuantity: false)}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              QuantityStepper(
                quantityLabel: formatQuantityCompact(
                  item.quantity,
                  item.product,
                ),
                onIncrement: onIncrement,
                onDecrement: onDecrement,
              ),
              const SizedBox(height: 6),
              Text(
                '₹${item.lineTotal}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final CartState cart;
  const _Summary({required this.cart});

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
        children: [
          _row('Item total', '₹${cart.totalAmount}'),
          const _DashDivider(),
          _row('Delivery', 'Free', valueColor: AppColors.green),
          const _DashDivider(),
          _row('To pay*', '₹${cart.totalAmount}', bold: true),
          const SizedBox(height: 6),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '*Final price confirmed by shop after weighing loose items',
              style: TextStyle(fontSize: 10, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
  }) {
    final style = TextStyle(
      fontSize: bold ? 15 : 12.5,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      color: valueColor ?? AppColors.ink,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style.copyWith(fontWeight: FontWeight.w500)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _DashDivider extends StatelessWidget {
  const _DashDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: AppColors.line);
}

class _CheckoutBar extends StatelessWidget {
  final CartState cart;
  const _CheckoutBar({required this.cart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CheckoutScreen()),
            );
          },
          child: Text('Proceed to Checkout · ₹${cart.totalAmount}'),
        ),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 56, color: AppColors.muted),
          SizedBox(height: 12),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Add items from the catalog to get started',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
