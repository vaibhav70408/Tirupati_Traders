import 'package:flutter/foundation.dart';

import 'product.dart';

/// A [Product] with a quantity, and an optional admin-adjusted [unitPriceOverride]
/// used for loose items priced after weighing.
@immutable
class CartItem {
  final Product product;
  final int quantity;
  final int? unitPriceOverride;

  const CartItem({
    required this.product,
    required this.quantity,
    this.unitPriceOverride,
  });

  int get unitPrice => unitPriceOverride ?? product.price;

  int get lineTotal {
    if (product.isLoose) {
      return (unitPrice * quantity * product.stepInGrams / 1000).round();
    }
    return unitPrice * quantity;
  }

  /// Actual weight/volume for display, e.g. 250 g or 1 kg.
  double get actualAmount => product.isLoose
      ? quantity * product.stepInGrams / 1000
      : quantity.toDouble();

  bool get isPriceAdjusted =>
      unitPriceOverride != null && unitPriceOverride != product.price;

  CartItem copyWith({int? quantity, int? unitPriceOverride}) => CartItem(
    product: product,
    quantity: quantity ?? this.quantity,
    unitPriceOverride: unitPriceOverride ?? this.unitPriceOverride,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CartItem &&
          other.product == product &&
          other.quantity == quantity &&
          other.unitPriceOverride == unitPriceOverride);

  @override
  int get hashCode => Object.hash(product, quantity, unitPriceOverride);
}
