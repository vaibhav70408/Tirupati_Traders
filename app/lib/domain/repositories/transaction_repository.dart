import '../entities/payment_transaction.dart';

/// Abstraction over payment transaction reads.
abstract interface class TransactionRepository {
  /// Emits every recorded transaction (newest first) for the admin view.
  Stream<List<PaymentTransaction>> watchAllTransactions();

  /// Emits only the transactions belonging to [customerId] (newest first).
  Stream<List<PaymentTransaction>> watchCustomerTransactions(String customerId);
}
