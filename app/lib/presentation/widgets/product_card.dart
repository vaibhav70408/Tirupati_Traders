import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/cart/cart_controller.dart';
import '../../domain/entities/product.dart';
import '../../theme/app_colors.dart';
import '../utils/quantity_formatter.dart';
import 'product_image.dart';
import 'quantity_stepper.dart';

/// Catalog tile. Shows an ADD button until the product is in the cart,
/// then a [QuantityStepper]. Out-of-stock products are non-interactive.
///
/// Loose items display their price per kg and offer 250 g-step quantity chips.
class ProductCard extends ConsumerWidget {
  final Product product;

  const ProductCard({super.key, required this.product});

  String get _priceLabel =>
      product.isLoose ? '₹${product.price}/kg' : '₹${product.price}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantity = ref.watch(
      cartControllerProvider.select((cart) => cart.quantityOf(product.id)),
    );
    final controller = ref.read(cartControllerProvider.notifier);
    final outOfStock = !product.inStock;

    return Opacity(
      opacity: outOfStock ? 0.6 : 1,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 74,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: ProductImage(
                imagePath: product.imagePath,
                emoji: product.emoji,
                width: double.infinity,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              product.name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              product.unit,
              style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (outOfStock)
                  const _OutOfStockBadge()
                else ...[
                  Text(
                    _priceLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  if (quantity == 0)
                    _AddButton(onTap: () => controller.add(product))
                  else
                    QuantityStepper(
                      quantityLabel: formatQuantityCompact(quantity, product),
                      onIncrement: () => controller.increment(product.id),
                      onDecrement: () => controller.decrement(product.id),
                    ),
                ],
              ],
            ),
            if (quantity > 0 && product.isLoose) ...[
              const SizedBox(height: 8),
              _LooseChips(
                product: product,
                quantity: quantity,
                onSelect: (q) => controller.setQuantity(product, q),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LooseChips extends StatelessWidget {
  final Product product;
  final int quantity;
  final ValueChanged<int> onSelect;

  const _LooseChips({
    required this.product,
    required this.quantity,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final options = [1, 2, 3, 4, 6, 8, 10]; // steps of 250 g by default
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final steps in options)
          ChoiceChip(
            label: Text(
              formatQuantityCompact(steps, product),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: quantity == steps ? Colors.white : AppColors.ink,
              ),
            ),
            selected: quantity == steps,
            selectedColor: AppColors.saffron,
            backgroundColor: AppColors.greenLight,
            side: BorderSide.none,
            onSelected: (_) => onSelect(steps),
          ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.saffron,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'ADD',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _OutOfStockBadge extends StatelessWidget {
  const _OutOfStockBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'OUT OF STOCK',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: Color(0xFFC62828),
        ),
      ),
    );
  }
}
