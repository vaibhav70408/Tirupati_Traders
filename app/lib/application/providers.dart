import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/firestore_admin_repository.dart';
import '../data/repositories/firestore_order_repository.dart';
import '../data/repositories/firestore_product_repository.dart';
import '../data/repositories/firestore_transaction_repository.dart';
import '../data/repositories/firestore_user_repository.dart';
import '../domain/entities/admin.dart';
import '../domain/entities/app_user.dart';
import '../domain/entities/order.dart';
import '../domain/entities/payment_transaction.dart';
import '../domain/entities/product.dart';
import '../domain/repositories/admin_repository.dart';
import '../domain/repositories/order_repository.dart';
import '../domain/repositories/product_repository.dart';
import '../domain/repositories/transaction_repository.dart';
import '../domain/repositories/user_repository.dart';
import 'admin/admin_auth_controller.dart';
import 'auth/auth_controller.dart';

/// Firestore instance for dependency injection (override in tests).
final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

/// Single injection point for the product repository.
/// Override this in tests or when switching data sources.
final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => FirestoreProductRepository(ref.watch(firestoreProvider)),
);

/// Single injection point for the order repository.
final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => FirestoreOrderRepository(ref.watch(firestoreProvider)),
);

/// Single injection point for the user profile repository.
final userRepositoryProvider = Provider<UserRepository>(
  (ref) => FirestoreUserRepository(ref.watch(firestoreProvider)),
);

/// Streams the signed-in customer's profile from Firestore.
/// Returns null when the user is signed out or has no profile yet.
final currentUserProfileProvider = StreamProvider<AppUser?>((ref) {
  final authUser = ref.watch(authStateProvider).asData?.value;
  if (authUser == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).watchUser(authUser.uid);
});

final productsProvider = StreamProvider<List<Product>>(
  (ref) => ref.watch(productRepositoryProvider).watchProducts(),
);

/// Category filter list derived from the live catalog, so a new product's
/// category appears automatically. 'All' is always first.
final categoriesProvider = Provider<List<String>>((ref) {
  final products = ref.watch(productsProvider).value ?? const [];
  final names = <String>{
    for (final p in products)
      if (!p.isVariant) p.category,
  }.toList()..sort();
  return ['All', ...names];
});

final ordersProvider = StreamProvider<List<Order>>(
  (ref) => ref.watch(orderRepositoryProvider).watchOrders(),
);

/// Streams only the orders that belong to the currently signed-in customer.
/// Falls back to the customer's phone number for orders placed before the
/// app stored Firebase UIDs on each order.
final customerOrdersProvider = StreamProvider<List<Order>>((ref) {
  final authUser = ref.watch(authStateProvider).asData?.value;
  if (authUser == null) return Stream.value(const []);
  return ref
      .watch(orderRepositoryProvider)
      .watchCustomerOrders(
        customerId: authUser.uid,
        customerPhone: authUser.phoneNumber,
      );
});

/// Single injection point for the payment transaction repository.
final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => FirestoreTransactionRepository(ref.watch(firestoreProvider)),
);

/// All recorded payment transactions (newest first) for the admin view.
final transactionsProvider = StreamProvider<List<PaymentTransaction>>(
  (ref) => ref.watch(transactionRepositoryProvider).watchAllTransactions(),
);

/// Payment transactions belonging to the signed-in customer (newest first).
final customerTransactionsProvider = StreamProvider<List<PaymentTransaction>>((
  ref,
) {
  final authUser = ref.watch(authStateProvider).asData?.value;
  if (authUser == null) return Stream.value(const []);
  return ref
      .watch(transactionRepositoryProvider)
      .watchCustomerTransactions(authUser.uid);
});

/// Single injection point for the admin identity repository.
final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => FirestoreAdminRepository(ref.watch(firestoreProvider)),
);

/// Fetches the list of active admins for the admin login dropdown.
final activeAdminsProvider = FutureProvider<List<Admin>>((ref) async {
  return ref.watch(adminRepositoryProvider).getActiveAdmins();
});

/// Checks whether the currently signed-in Firebase user is an active admin.
final currentAdminStatusProvider = FutureProvider<bool>((ref) async {
  final authUser = ref.watch(authStateProvider).asData?.value;
  if (authUser == null) return false;
  final phone = authUser.phoneNumber;
  if (phone == null || phone.isEmpty) return false;
  return ref.watch(adminRepositoryProvider).isActiveAdmin(phone);
});

/// Returns the active admin profile for the signed-in Firebase user.
final currentAdminProvider = FutureProvider<Admin?>((ref) async {
  final authUser = ref.watch(authStateProvider).asData?.value;
  if (authUser == null) return null;
  final phone = authUser.phoneNumber;
  if (phone == null || phone.isEmpty) return null;
  final normalized = Admin.normalize(phone);
  final admins = await ref.watch(adminRepositoryProvider).getActiveAdmins();
  return admins.cast<Admin?>().firstWhere(
    (a) => Admin.normalize(a?.phoneNumber ?? '') == normalized,
    orElse: () => null,
  );
});

/// Resolves the signed-in admin's name for display.
///
/// Prefers the name selected during the current admin auth session, then
/// falls back to the Firestore admin document.
final currentAdminNameProvider = Provider<String>((ref) {
  final authName = ref.watch(
    adminAuthControllerProvider.select((s) => s.selectedName),
  );
  if (authName != null && authName.isNotEmpty) return authName;
  return ref.watch(currentAdminProvider).value?.name ?? 'Admin';
});
