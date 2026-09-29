import 'package:flutter/foundation.dart';

import 'cart_item.dart';

enum DeliveryMethod {
  homeDelivery('Home Delivery', 'Today, 5–7 PM · Free above ₹500'),
  pickup('Pickup from Shop', 'Ready in 30 min');

  const DeliveryMethod(this.label, this.description);
  final String label;
  final String description;
}

enum PaymentMethod {
  upi('UPI (GPay / PhonePe / Paytm)'),
  cash('Cash on Delivery');

  const PaymentMethod(this.label);
  final String label;
}

enum OrderStatus {
  placed('Placed'),
  approved('Approved'),
  outForDelivery('Out for delivery'),
  delivered('Delivered'),
  declined('Declined');

  const OrderStatus(this.label);
  final String label;
}

/// A customer order captured at checkout. Immutable snapshot.
///
/// [items] is the current (possibly admin-revised) list; [originalItems] is the
/// list as the customer placed it, kept so the customer can see what changed.
/// [isPaid] is true once the final amount has been received (UPI or COD).
/// [orderListImageUrls] holds images uploaded by the customer as a shopping
/// list; [handwrittenBillImageUrls] are the bill images uploaded by the admin.
@immutable
class Order {
  final String id;
  final String? customerId;
  final String customerName;
  final String? customerPhone;
  final String? customerAddress;
  final List<CartItem> items;
  final List<CartItem> originalItems;
  final DeliveryMethod deliveryMethod;
  final PaymentMethod paymentMethod;
  final OrderStatus status;
  final bool modifiedByAdmin;
  final bool isPaid;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final DateTime placedAt;
  final List<String> orderListImageUrls;
  final List<String> handwrittenBillImageUrls;

  const Order({
    required this.id,
    this.customerId,
    required this.customerName,
    this.customerPhone,
    this.customerAddress,
    required this.items,
    required this.originalItems,
    required this.deliveryMethod,
    required this.paymentMethod,
    required this.status,
    required this.placedAt,
    this.modifiedByAdmin = false,
    this.isPaid = false,
    this.razorpayOrderId,
    this.razorpayPaymentId,
    this.orderListImageUrls = const [],
    this.handwrittenBillImageUrls = const [],
  });

  int get totalAmount => items.fold(0, (sum, item) => sum + item.lineTotal);

  int get originalTotal =>
      originalItems.fold(0, (sum, item) => sum + item.lineTotal);

  int get itemCount => items.length;

  bool get canMarkOutForDelivery => status == OrderStatus.approved;

  /// True when the order was created by uploading a photo list instead of
  /// adding items to the cart.
  bool get isListOrder => orderListImageUrls.isNotEmpty;

  Order copyWith({
    List<CartItem>? items,
    OrderStatus? status,
    bool? modifiedByAdmin,
    bool? isPaid,
    PaymentMethod? paymentMethod,
    String? razorpayOrderId,
    String? razorpayPaymentId,
    List<String>? orderListImageUrls,
    List<String>? handwrittenBillImageUrls,
  }) {
    return Order(
      id: id,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      items: items ?? this.items,
      originalItems: originalItems,
      deliveryMethod: deliveryMethod,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      placedAt: placedAt,
      modifiedByAdmin: modifiedByAdmin ?? this.modifiedByAdmin,
      isPaid: isPaid ?? this.isPaid,
      razorpayOrderId: razorpayOrderId ?? this.razorpayOrderId,
      razorpayPaymentId: razorpayPaymentId ?? this.razorpayPaymentId,
      orderListImageUrls: orderListImageUrls ?? this.orderListImageUrls,
      handwrittenBillImageUrls:
          handwrittenBillImageUrls ?? this.handwrittenBillImageUrls,
    );
  }
}
