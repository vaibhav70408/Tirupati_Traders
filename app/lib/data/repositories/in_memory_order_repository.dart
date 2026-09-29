import 'dart:async';

import '../../domain/entities/cart_item.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/order_repository.dart';

/// In-memory [OrderRepository]. Keeps placed orders for the session and
/// generates sequential ids (e.g. TT1043) mirroring the shop's numbering.
class InMemoryOrderRepository implements OrderRepository {
  final List<Order> _orders = [];
  final StreamController<List<Order>> _controller =
      StreamController<List<Order>>.broadcast();
  int _nextNumber = 1043;

  @override
  Future<Order> placeOrder({
    required List<CartItem> items,
    required DeliveryMethod deliveryMethod,
    required PaymentMethod paymentMethod,
    required String customerName,
    String? customerId,
    String? customerPhone,
    String? customerAddress,
  }) async {
    final snapshot = List<CartItem>.unmodifiable(items);
    final order = Order(
      id: 'TT${_nextNumber++}',
      customerId: customerId,
      customerName: customerName.isNotEmpty ? customerName : 'Customer',
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      items: snapshot,
      originalItems: snapshot,
      deliveryMethod: deliveryMethod,
      paymentMethod: paymentMethod,
      status: OrderStatus.placed,
      placedAt: DateTime.now(),
    );
    _orders.insert(0, order);
    _controller.add(_snapshot());
    return order;
  }

  @override
  Stream<List<Order>> watchOrders() async* {
    yield _snapshot();
    yield* _controller.stream;
  }

  @override
  Stream<List<Order>> watchCustomerOrders({
    required String customerId,
    String? customerPhone,
  }) async* {
    yield _ordersFor(customerId, customerPhone);
    yield* _controller.stream.map(
      (orders) => _ordersFor(customerId, customerPhone, initial: orders),
    );
  }

  List<Order> _ordersFor(
    String customerId,
    String? customerPhone, {
    List<Order>? initial,
  }) {
    final source = initial ?? _orders;
    return source.where((o) {
      if (o.customerId != null && o.customerId!.isNotEmpty) {
        return o.customerId == customerId;
      }
      if (customerPhone != null && customerPhone.isNotEmpty) {
        return o.customerPhone == customerPhone;
      }
      return false;
    }).toList();
  }

  @override
  Future<void> updateStatus({
    required String orderId,
    required OrderStatus status,
  }) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return;
    _orders[index] = _orders[index].copyWith(status: status);
    _controller.add(_snapshot());
  }

  @override
  Future<void> reviseAndApprove({
    required String orderId,
    required List<CartItem> items,
    required bool modified,
  }) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return;
    _orders[index] = _orders[index].copyWith(
      items: List.unmodifiable(items),
      status: OrderStatus.approved,
      modifiedByAdmin: modified,
    );
    _controller.add(_snapshot());
  }

  @override
  Future<void> markPaid({
    required String orderId,
    PaymentMethod? paymentMethod,
  }) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return;
    _orders[index] = _orders[index].copyWith(
      isPaid: true,
      paymentMethod: paymentMethod,
    );
    _controller.add(_snapshot());
  }

  @override
  Future<Order> placeListOrder({
    required List<String> imageUrls,
    required String customerName,
    String? customerId,
    String? customerPhone,
    String? customerAddress,
  }) async {
    final order = Order(
      id: 'TT${_nextNumber++}',
      customerId: customerId,
      customerName: customerName.isNotEmpty ? customerName : 'Customer',
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      items: const [],
      originalItems: const [],
      deliveryMethod: DeliveryMethod.homeDelivery,
      paymentMethod: PaymentMethod.cash,
      status: OrderStatus.placed,
      placedAt: DateTime.now(),
      orderListImageUrls: imageUrls,
    );
    _orders.insert(0, order);
    _controller.add(_snapshot());
    return order;
  }

  @override
  Future<void> setFinalBillAmount({
    required String orderId,
    required int amount,
  }) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return;
    final billProduct = Product(
      id: '__final_bill__',
      name: 'Final bill',
      unit: 'as per list',
      category: 'Other',
      price: amount,
      emoji: '🧾',
    );
    final item = CartItem(product: billProduct, quantity: 1);
    _orders[index] = _orders[index].copyWith(items: List.unmodifiable([item]));
    _controller.add(_snapshot());
  }

  @override
  Future<void> uploadHandwrittenBillImage({
    required String orderId,
    required String imageUrl,
  }) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return;
    final updated = [..._orders[index].handwrittenBillImageUrls, imageUrl];
    _orders[index] = _orders[index].copyWith(
      handwrittenBillImageUrls: List.unmodifiable(updated),
    );
    _controller.add(_snapshot());
  }

  List<Order> _snapshot() => List.unmodifiable(_orders);
}
