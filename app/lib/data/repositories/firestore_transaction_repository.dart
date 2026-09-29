import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/payment_transaction.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../mappers/transaction_mapper.dart';

/// Firestore-backed [TransactionRepository] over the `transactions` collection.
class FirestoreTransactionRepository implements TransactionRepository {
  final FirebaseFirestore _firestore;

  FirestoreTransactionRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('transactions');

  @override
  Stream<List<PaymentTransaction>> watchAllTransactions() {
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TransactionMapper.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Stream<List<PaymentTransaction>> watchCustomerTransactions(
    String customerId,
  ) {
    // Filter by customer only and sort in memory so no composite index is
    // required.
    return _col
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => TransactionMapper.fromMap(doc.id, doc.data()))
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }
}
