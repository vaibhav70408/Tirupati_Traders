import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/cart/cart_controller.dart';
import '../../domain/entities/product.dart';
import '../../presentation/utils/quantity_formatter.dart';
import '../../theme/app_colors.dart';
import 'product_image.dart';
import 'quantity_stepper.dart';

/// Bottom sheet shown when a parent product has multiple visible variants.
/// Lets the customer pick a variant and quantity, then add to cart.
class ProductPickerSheet extends ConsumerWidget {
  final Product parent;
  final List<Product> variants;

  const ProductPickerSheet({
    super.key,
    required this.parent,
    required this.variants,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ProductPickerSheetBody(parent: parent, variants: variants);
  }
}

class _ProductPickerSheetBody extends ConsumerStatefulWidget {
  final Product parent;
  final List<Product> variants;

  const _ProductPickerSheetBody({required this.parent, required this.variants});

  @override
  ConsumerState<_ProductPickerSheetBody> createState() =>
      _ProductPickerSheetBodyState();
}

class _ProductPickerSheetBodyState
    extends ConsumerState<_ProductPickerSheetBody> {
  late Product _selected;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _selected = widget.variants.firstWhere(
      (v) => v.inStock,
      orElse: () => widget.variants.first,
    );
  }

  String get _priceLabel =>
      _selected.isLoose ? '₹${_selected.price}/kg' : '₹${_selected.price}';

  int get _lineTotal {
    if (_selected.isLoose) {
      return (_selected.price * _quantity * _selected.stepInGrams / 1000)
          .round();
    }
    return _selected.price * _quantity;
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(cartControllerProvider.notifier);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        top: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ProductCardImage(
            imagePath: _selected.imagePath,
            emoji: _selected.emoji.isEmpty
                ? widget.parent.emoji
                : _selected.emoji,
            height: 170,
            previewTitle: widget.parent.name,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.parent.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selected.unit,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _priceLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Choose variant',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final variant in widget.variants)
                ChoiceChip(
                  label: Text(
                    variant.name.trim().isNotEmpty
                        ? '${variant.name} · ${variant.unit}'
                        : variant.unit,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _selected.id == variant.id
                          ? Colors.white
                          : AppColors.ink,
                    ),
                  ),
                  selected: _selected.id == variant.id,
                  selectedColor: AppColors.saffron,
                  backgroundColor: AppColors.greenLight,
                  side: BorderSide.none,
                  onSelected: variant.inStock
                      ? (_) => setState(() {
                          _selected = variant;
                          _quantity = 1;
                        })
                      : null,
                ),
            ],
          ),
          if (_selected.isLoose) ...[
            const SizedBox(height: 18),
            const Text(
              'Quick quantity',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final steps in const [1, 2, 3, 4, 6, 8, 10])
                  ChoiceChip(
                    label: Text(
                      formatQuantityCompact(steps, _selected),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _quantity == steps
                            ? Colors.white
                            : AppColors.ink,
                      ),
                    ),
                    selected: _quantity == steps,
                    selectedColor: AppColors.green,
                    backgroundColor: AppColors.greenLight,
                    side: BorderSide.none,
                    onSelected: (_) => setState(() => _quantity = steps),
                  ),
              ],
            ),
          ],
          const Spacer(),
          Row(
            children: [
              QuantityStepper(
                quantityLabel: formatQuantityCompact(_quantity, _selected),
                onIncrement: () => setState(() => _quantity++),
                onDecrement: () {
                  if (_quantity > 1) setState(() => _quantity--);
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    controller.addWithQuantity(_selected, _quantity);
                    Navigator.pop(context);
                  },
                  child: Text('Add · ₹$_lineTotal'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
