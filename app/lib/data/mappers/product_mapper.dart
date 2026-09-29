import '../../domain/entities/product.dart';

/// Maps [Product] to/from Firestore document data.
class ProductMapper {
  const ProductMapper._();

  static Map<String, dynamic> toMap(Product p) => {
    'name': p.name,
    'unit': p.unit,
    'category': p.category,
    'price': p.price,
    'emoji': p.emoji,
    'inStock': p.inStock,
    'imagePath': p.imagePath,
    'isLoose': p.isLoose,
    'stepInGrams': p.stepInGrams,
    'parentProductId': p.parentProductId,
    'isVisible': p.isVisible,
  };

  /// Product map including its id, used when embedding inside an order.
  static Map<String, dynamic> toEmbeddedMap(Product p) => {
    ...toMap(p),
    'id': p.id,
  };

  static Product fromMap(String id, Map<String, dynamic> m) => Product(
    id: id,
    name: (m['name'] ?? '') as String,
    unit: (m['unit'] ?? '') as String,
    category: (m['category'] ?? '') as String,
    price: ((m['price'] ?? 0) as num).toInt(),
    emoji: (m['emoji'] ?? '🛒') as String,
    inStock: (m['inStock'] ?? true) as bool,
    imagePath: m['imagePath'] as String?,
    isLoose: (m['isLoose'] ?? false) as bool,
    stepInGrams: ((m['stepInGrams'] ?? 250) as num).toInt(),
    parentProductId: m['parentProductId'] as String?,
    isVisible: (m['isVisible'] ?? true) as bool,
  );

  static Product fromEmbedded(Map<String, dynamic> m) =>
      fromMap((m['id'] ?? '') as String, m);
}
