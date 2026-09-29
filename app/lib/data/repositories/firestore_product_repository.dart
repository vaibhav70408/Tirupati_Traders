import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/sample_products.dart';
import '../mappers/product_mapper.dart';

/// Firestore-backed [ProductRepository]. Seeds the catalog from
/// [SampleProducts] on first run so the shop starts with stock.
class FirestoreProductRepository implements ProductRepository {
  final FirebaseFirestore _firestore;

  FirestoreProductRepository(this._firestore) {
    _ensureSeeded();
  }

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('products');

  Future<void> _ensureSeeded() async {
    final snapshot = await _col.limit(1).get();
    if (snapshot.docs.isNotEmpty) return;
    final batch = _firestore.batch();
    for (final product in SampleProducts.items) {
      batch.set(_col.doc(product.id), ProductMapper.toMap(product));
    }
    await batch.commit();
  }

  @override
  Stream<List<Product>> watchProducts() {
    return _col
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ProductMapper.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Future<void> addProduct(Product product) =>
      _col.doc(product.id).set(ProductMapper.toMap(product));

  @override
  Future<void> updateProduct(Product product) =>
      _col.doc(product.id).set(ProductMapper.toMap(product));

  @override
  Future<void> setInStock({required String productId, required bool inStock}) =>
      _col.doc(productId).update({'inStock': inStock});

  @override
  Future<void> deleteProduct(String productId) => _col.doc(productId).delete();
}
