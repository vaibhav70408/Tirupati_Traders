import '../entities/product.dart';

/// Abstraction over the product catalog source (in-memory now, Firestore later).
/// Presentation and application layers depend on this, never on a concrete impl.
abstract interface class ProductRepository {
  /// Emits the current catalog and every update (add/edit/stock change).
  Stream<List<Product>> watchProducts();

  Future<void> addProduct(Product product);

  Future<void> updateProduct(Product product);

  Future<void> setInStock({required String productId, required bool inStock});

  Future<void> deleteProduct(String productId);
}
