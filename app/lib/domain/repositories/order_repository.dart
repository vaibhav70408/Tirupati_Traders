import '../entities/cart_item.dart';
import '../entities/order.dart';

/// Abstraction over order persistence (in-memory now, Firestore later).
abstract interface class OrderRepository {
  /// Persists a new order built from [items] and the chosen methods,
  /// returning the created [Order] with its generated id.
  Future<Order> placeOrder({
    required List<CartItem> items,
    required DeliveryMethod deliveryMethod,
    required PaymentMethod paymentMethod,
    required String customerName,
    String? customerId,
    String? customerPhone,
    String? customerAddress,
  });

  /// Emits the current list of orders (newest first) and every update.
  /// Stream-based so a Firestore snapshot listener can drop in later.
  Stream<List<Order>> watchOrders();

  /// Emits orders visible to the signed-in customer.
  /// [customerId] is the Firebase user UID; [customerPhone] is used as a
  /// fallback for orders placed before user scoping was added.
  Stream<List<Order>> watchCustomerOrders({
    required String customerId,
    String? customerPhone,
  });

  /// Updates the status of an existing order (admin action).
  Future<void> updateStatus({
    required String orderId,
    required OrderStatus status,
  });

  /// Replaces an order's items with the admin-revised [items] and marks it
  /// approved. [modified] records whether the admin actually changed anything.
  Future<void> reviseAndApprove({
    required String orderId,
    required List<CartItem> items,
    required bool modified,
  });

  /// Marks the order as paid. Optionally records the [paymentMethod] used.
  Future<void> markPaid({
    required String orderId,
    PaymentMethod? paymentMethod,
  });

  /// Places an order that was created from a customer-uploaded photo list.
  /// No cart items are supplied; the images serve as the order request.
  Future<Order> placeListOrder({
    required List<String> imageUrls,
    required String customerName,
    String? customerId,
    String? customerPhone,
    String? customerAddress,
  });

  /// Adds the URL of an admin-uploaded handwritten bill image to the order.
  Future<void> uploadHandwrittenBillImage({
    required String orderId,
    required String imageUrl,
  });

  /// Updates the admin-entered final bill amount for a list order.
  /// The [amount] is stored as a single-line-item order so totals show
  /// consistently on both admin and customer screens.
  Future<void> setFinalBillAmount({
    required String orderId,
    required int amount,
  });
}
