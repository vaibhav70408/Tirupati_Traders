import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/payment_transaction.dart';

/// Maps a Firestore transaction document to a [PaymentTransaction].
class TransactionMapper {
  const TransactionMapper._();

  static PaymentTransaction fromMap(String id, Map<String, dynamic> m) =>
      PaymentTransaction(
        id: id,
        orderId: (m['orderId'] ?? '') as String,
        customerId: m['customerId'] as String?,
        customerName: (m['customerName'] ?? 'Customer') as String,
        customerPhone: m['customerPhone'] as String?,
        amountPaise: ((m['amount'] ?? 0) as num).toInt(),
        method: (m['method'] ?? 'upi') as String,
        status: (m['status'] ?? 'captured') as String,
        razorpayPaymentId: (m['razorpayPaymentId'] ?? id) as String,
        razorpayOrderId: (m['razorpayOrderId'] ?? '') as String,
        createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
}
