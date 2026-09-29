import 'dart:async';

import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/sample_products.dart';

/// In-memory [ProductRepository] seeded from [SampleProducts].
/// Holds mutable catalog state and emits updates so the customer catalog and
/// admin product screens stay in sync. Interchangeable with Firestore (LSP).
class InMemoryProductRepository implements ProductRepository {
  final List<Product> _products = [...SampleProducts.items];
  final StreamController<List<Product>> _controller =
      StreamController<List<Product>>.broadcast();

  @override
  Stream<List<Product>> watchProducts() async* {
    yield _snapshot();
    yield* _controller.stream;
  }

  @override
  Future<void> addProduct(Product product) async {
    _products.add(product);
    _controller.add(_snapshot());
  }

  @override
  Future<void> updateProduct(Product product) async {
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index == -1) return;
    _products[index] = product;
    _controller.add(_snapshot());
  }

  @override
  Future<void> setInStock({
    required String productId,
    required bool inStock,
  }) async {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index == -1) return;
    _products[index] = _products[index].copyWith(inStock: inStock);
    _controller.add(_snapshot());
  }

  @override
  Future<void> deleteProduct(String productId) async {
    _products.removeWhere((p) => p.id == productId);
    _controller.add(_snapshot());
  }

  List<Product> _snapshot() => List.unmodifiable(_products);
}
