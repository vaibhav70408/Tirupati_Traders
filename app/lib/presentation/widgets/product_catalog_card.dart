import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/cart/cart_controller.dart';
import '../../domain/entities/product.dart';
import '../../presentation/utils/quantity_formatter.dart';
import '../../theme/app_colors.dart';
import 'product_image.dart';
import 'product_picker_sheet.dart';
import 'quantity_stepper.dart';

/// Catalog card shown on the customer home.
///
/// - For a parent product with multiple visible variants, tapping opens a
///   bottom sheet to pick the variant and quantity.
/// - For a parent with exactly one visible variant, that variant is rendered
///   directly (no sheet).
/// - For a parent with no variants, the parent itself is the sellable product.
/// - Variants themselves are never shown at the top level.
class ProductCatalogCard extends ConsumerWidget {
  final Product parent;
  final List<Product> variants;

  const ProductCatalogCard({
    super.key,
    required this.parent,
    required this.variants,
  });

  List<Product> get _visibleVariants =>
      variants.where((v) => v.isVisible).toList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = _visibleVariants;

    if (visible.isEmpty) {
      return _SingleVariantCard(
        product: parent,
        displayName: parent.name,
        displayEmoji: parent.emoji,
      );
    }

    if (visible.length == 1) {
      final only = visible.first;
      final variantName = only.name.trim();
      return _SingleVariantCard(
        product: only,
        displayName: variantName.isEmpty || variantName == parent.name
            ? parent.name
            : '${parent.name} · $variantName',
        displayEmoji: parent.emoji,
      );
    }

    return _MultiVariantCard(parent: parent, variants: visible);
  }
}

class _SingleVariantCard extends ConsumerWidget {
  final Product product;
  final String displayName;
  final String displayEmoji;

  const _SingleVariantCard({
    required this.product,
    required this.displayName,
    required this.displayEmoji,
  });

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
            _ImageBox(product: product, fallbackEmoji: displayEmoji),
            const SizedBox(height: 9),
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
          ],
        ),
      ),
    );
  }
}

class _MultiVariantCard extends StatelessWidget {
  final Product parent;
  final List<Product> variants;

  const _MultiVariantCard({required this.parent, required this.variants});

  String get _startingPrice {
    final prices = variants.where((v) => v.inStock).map((v) => v.price);
    if (prices.isEmpty) return '';
    final min = prices.reduce((a, b) => a < b ? a : b);
    return 'From ₹$min';
  }

  @override
  Widget build(BuildContext context) {
    final inStockCount = variants.where((v) => v.inStock).length;
    final starting = _startingPrice;

    return InkWell(
      onTap: () => _openPicker(context),
      borderRadius: BorderRadius.circular(16),
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
            _ImageBox(product: parent, fallbackEmoji: parent.emoji),
            const SizedBox(height: 9),
            Text(
              parent.name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              inStockCount == 0
                  ? 'Currently unavailable'
                  : starting.isEmpty
                  ? '$inStockCount options'
                  : '$starting · $inStockCount options',
              style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: _ViewOptionsButton(onTap: () => _openPicker(context)),
            ),
          ],
        ),
      ),
    );
  }

  void _openPicker(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: screenHeight * 0.65,
            minWidth: 320,
          ),
          child: ProductPickerSheet(parent: parent, variants: variants),
        ),
      ),
    );
  }
}

class _ImageBox extends StatelessWidget {
  final Product product;
  final String fallbackEmoji;

  const _ImageBox({required this.product, required this.fallbackEmoji});

  @override
  Widget build(BuildContext context) {
    return ProductCardImage(
      imagePath: product.imagePath,
      emoji: fallbackEmoji.isEmpty ? product.emoji : fallbackEmoji,
      previewTitle: product.name,
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

class _ViewOptionsButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ViewOptionsButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.greenLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.green),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'View Options',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.green,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.expand_more, size: 16, color: AppColors.green),
          ],
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
