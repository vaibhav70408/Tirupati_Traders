import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/cart_item.dart';
import '../../domain/entities/product.dart';
import 'cart_state.dart';

/// Owns cart mutations. Each method returns a new [CartState] (no in-place edits).
class CartController extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  void add(Product product) {
    addWithQuantity(product, 1);
  }

  /// Adds [extraQuantity] to an existing line, or creates a new line with
  /// that quantity. This is the behaviour tapped by the "Add" button.
  void addWithQuantity(Product product, int extraQuantity) {
    if (extraQuantity <= 0) return;
    final existing = _indexOf(product.id);
    if (existing == -1) {
      state = state.copyWith(
        items: [
          ...state.items,
          CartItem(product: product, quantity: extraQuantity),
        ],
      );
    } else {
      _updateQuantity(existing, state.items[existing].quantity + extraQuantity);
    }
  }

  void setQuantity(Product product, int quantity) {
    if (quantity <= 0) {
      remove(product.id);
      return;
    }
    final existing = _indexOf(product.id);
    if (existing == -1) {
      state = state.copyWith(
        items: [
          ...state.items,
          CartItem(product: product, quantity: quantity),
        ],
      );
    } else {
      _updateQuantity(existing, quantity);
    }
  }

  void increment(String productId) {
    final index = _indexOf(productId);
    if (index == -1) return;
    _updateQuantity(index, state.items[index].quantity + 1);
  }

  void decrement(String productId) {
    final index = _indexOf(productId);
    if (index == -1) return;
    final nextQuantity = state.items[index].quantity - 1;
    if (nextQuantity <= 0) {
      remove(productId);
    } else {
      _updateQuantity(index, nextQuantity);
    }
  }

  void remove(String productId) {
    state = state.copyWith(
      items: state.items.where((item) => item.product.id != productId).toList(),
    );
  }

  void clear() => state = const CartState();

  int _indexOf(String productId) =>
      state.items.indexWhere((item) => item.product.id == productId);

  void _updateQuantity(int index, int quantity) {
    final updated = [...state.items];
    updated[index] = updated[index].copyWith(quantity: quantity);
    state = state.copyWith(items: updated);
  }
}

final cartControllerProvider = NotifierProvider<CartController, CartState>(
  CartController.new,
);
