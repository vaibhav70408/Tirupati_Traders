import '../../domain/entities/product.dart';

/// Builds the customer/admin facing name for a product.
///
/// - For a standalone product, returns its own name.
/// - For a variant with no specific name, returns the parent name.
/// - For a variant with a specific name, returns "Parent · Variant".
String productDisplayName(Product product, Map<String, Product> productsById) {
  final parentId = product.parentProductId;
  if (parentId == null || parentId.isEmpty) return product.name;

  final parent = productsById[parentId];
  final parentName = parent?.name ?? product.name;
  final variantName = product.name.trim();
  if (variantName.isEmpty || variantName == parentName) return parentName;
  return '$parentName · $variantName';
}
