import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

import '../../domain/entities/cart_item.dart';
import '../../domain/entities/order.dart';
import 'product_mapper.dart';

/// Maps [CartItem] to/from Firestore map data. The product is embedded so the
/// order keeps its historical snapshot even if the catalog later changes.
class CartItemMapper {
  const CartItemMapper._();

  static Map<String, dynamic> toMap(CartItem item) => {
    'product': ProductMapper.toEmbeddedMap(item.product),
    'quantity': item.quantity,
    'unitPriceOverride': item.unitPriceOverride,
  };

  static CartItem fromMap(Map<String, dynamic> m) => CartItem(
    product: ProductMapper.fromEmbedded(
      Map<String, dynamic>.from(m['product'] as Map),
    ),
    quantity: ((m['quantity'] ?? 1) as num).toInt(),
    unitPriceOverride: (m['unitPriceOverride'] as num?)?.toInt(),
  );
}

/// Maps [Order] to/from Firestore document data.
class OrderMapper {
  const OrderMapper._();

  static Map<String, dynamic> toMap(Order o) => {
    'customerId': o.customerId,
    'customerName': o.customerName,
    'customerPhone': o.customerPhone,
    'customerAddress': o.customerAddress,
    'items': o.items.map(CartItemMapper.toMap).toList(),
    'originalItems': o.originalItems.map(CartItemMapper.toMap).toList(),
    'deliveryMethod': o.deliveryMethod.name,
    'paymentMethod': o.paymentMethod.name,
    'status': o.status.name,
    'modifiedByAdmin': o.modifiedByAdmin,
    'isPaid': o.isPaid,
    'totalAmount': o.totalAmount,
    'razorpayOrderId': o.razorpayOrderId,
    'razorpayPaymentId': o.razorpayPaymentId,
    'placedAt': Timestamp.fromDate(o.placedAt),
    'orderListImageUrls': o.orderListImageUrls,
    'handwrittenBillImageUrls': o.handwrittenBillImageUrls,
  };

  static Order fromMap(String id, Map<String, dynamic> m) => Order(
    id: id,
    customerId: m['customerId'] as String?,
    customerName: (m['customerName'] ?? '') as String,
    customerPhone: m['customerPhone'] as String?,
    customerAddress: m['customerAddress'] as String?,
    items: _items(m['items']),
    originalItems: _items(m['originalItems']),
    deliveryMethod: DeliveryMethod.values.byName(m['deliveryMethod'] as String),
    paymentMethod: PaymentMethod.values.byName(m['paymentMethod'] as String),
    status: OrderStatus.values.byName(m['status'] as String),
    modifiedByAdmin: (m['modifiedByAdmin'] ?? false) as bool,
    isPaid: (m['isPaid'] ?? false) as bool,
    razorpayOrderId: m['razorpayOrderId'] as String?,
    razorpayPaymentId: m['razorpayPaymentId'] as String?,
    placedAt: (m['placedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    orderListImageUrls: _stringList(m['orderListImageUrls']),
    handwrittenBillImageUrls: _stringList(m['handwrittenBillImageUrls']),
  );

  static List<CartItem> _items(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => CartItemMapper.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<String>().toList(growable: false);
  }
}
