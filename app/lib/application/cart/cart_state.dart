import 'package:flutter/foundation.dart';

import '../../domain/entities/cart_item.dart';

/// Immutable snapshot of the customer's cart.
@immutable
class CartState {
  final List<CartItem> items;

  const CartState({this.items = const []});

  int get distinctItemCount => items.length;

  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);

  int get totalAmount => items.fold(0, (sum, item) => sum + item.lineTotal);

  bool get isEmpty => items.isEmpty;

  int quantityOf(String productId) {
    for (final item in items) {
      if (item.product.id == productId) return item.quantity;
    }
    return 0;
  }

  CartState copyWith({List<CartItem>? items}) =>
      CartState(items: items ?? this.items);
}
