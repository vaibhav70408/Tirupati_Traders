import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../providers.dart';

/// Application-layer actions an admin performs on the catalog.
/// Generates ids for new products and delegates persistence to the
/// [ProductRepository] abstraction (DIP).
class ProductAdminService {
  final ProductRepository _repository;

  const ProductAdminService(this._repository);

  Future<void> add(Product product) => _repository.addProduct(product);

  Future<void> create({
    required String name,
    required String unit,
    required String category,
    required int price,
    required String emoji,
    required bool inStock,
    String? imagePath,
    bool isLoose = false,
    int stepInGrams = 250,
    String? parentProductId,
    bool isVisible = true,
  }) {
    final product = Product(
      id: 'p${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      unit: unit,
      category: category,
      price: price,
      emoji: emoji,
      inStock: inStock,
      imagePath: imagePath,
      isLoose: isLoose,
      stepInGrams: stepInGrams,
      parentProductId: parentProductId,
      isVisible: isVisible,
    );
    return _repository.addProduct(product);
  }

  Future<void> createVariant({
    required String parentProductId,
    required String unit,
    required int price,
    required bool inStock,
    bool isLoose = false,
    int stepInGrams = 250,
    bool isVisible = true,
  }) {
    return create(
      name: '',
      unit: unit,
      category: '',
      price: price,
      emoji: '',
      inStock: inStock,
      isLoose: isLoose,
      stepInGrams: stepInGrams,
      parentProductId: parentProductId,
      isVisible: isVisible,
    );
  }

  Future<void> update(Product product) => _repository.updateProduct(product);

  Future<void> setInStock(String productId, bool inStock) =>
      _repository.setInStock(productId: productId, inStock: inStock);

  Future<void> delete(String productId) => _repository.deleteProduct(productId);
}

final productAdminServiceProvider = Provider<ProductAdminService>(
  (ref) => ProductAdminService(ref.watch(productRepositoryProvider)),
);
