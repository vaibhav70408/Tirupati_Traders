import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth/auth_controller.dart';
import '../../application/cart/cart_controller.dart';
import '../../application/notifications/notifications_controller.dart';
import '../../application/notifications/order_notifications_listener.dart';
import '../../application/providers.dart';
import '../../domain/entities/product.dart';
import '../../presentation/widgets/product_catalog_card.dart';
import '../../theme/app_colors.dart';
import 'cart_screen.dart';
import 'customer_auth_gateway_screen.dart';
import 'customer_upload_list_screen.dart';
import 'notifications_screen.dart';
import 'orders_screen.dart';
import 'transactions_screen.dart';

class CustomerHomeScreen extends ConsumerStatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  ConsumerState<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  int _navIndex = 0;

  List<Product> _filter(List<Product> products) {
    final query = _searchQuery.trim().toLowerCase();
    return products
        .where((p) {
          if (p.isVariant) return false;
          final matchesCategory =
              _selectedCategory == 'All' || p.category == _selectedCategory;
          final matchesSearch =
              query.isEmpty ||
              p.name.toLowerCase().contains(query) ||
              p.category.toLowerCase().contains(query);
          return matchesCategory && matchesSearch;
        })
        .toList(growable: false);
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
  }

  void _onNavSelected(int index) {
    switch (index) {
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OrdersScreen()),
        );
        return;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TransactionsScreen()),
        );
        return;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CustomerUploadListScreen()),
        );
        return;
      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CartScreen()),
        );
        return;
      default:
        setState(() => _navIndex = index);
    }
  }

  Future<void> _confirmLogout(BuildContext screenContext) async {
    final shouldLogout = await showDialog<bool>(
      context: screenContext,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will be logged out and returned to the login screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (shouldLogout != true || !mounted) return;
    await ref.read(authControllerProvider.notifier).signOut();
    if (!mounted) return;
    if (!screenContext.mounted) return;
    Navigator.of(screenContext).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const CustomerAuthGatewayScreen()),
      (_) => false,
    );
  }

  @override
  void initState() {
    super.initState();
    // Start listening for order status changes that should surface as
    // in-app notifications for the customer.
    ref.read(customerOrderNotificationsListenerProvider);
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final cartQuantity = ref.watch(
      cartControllerProvider.select((c) => c.distinctItemCount),
    );
    final unread = ref.watch(
      notificationsControllerProvider.select(
        (list) => list.where((n) => !n.read).length,
      ),
    );
    final customerName = ref.watch(
      currentUserProfileProvider.select(
        (p) => p.asData?.value?.name ?? 'Customer',
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Deliver to · Home',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
            Text(
              'Namaste, $customerName 👋',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: () => _confirmLogout(context),
            icon: const Icon(Icons.logout),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: const Icon(Icons.notifications_none),
              ),
            ),
          ),
        ],
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load products.\n$e')),
        data: (products) => ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _SearchBar(onChanged: _onSearchChanged),
            const SizedBox(height: 12),
            const _PromoBanner(),
            const SizedBox(height: 12),
            _categories(),
            const SizedBox(height: 14),
            _productGrid(products),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: _onNavSelected,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.greenLight,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Orders',
          ),
          const NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            label: 'Payments',
          ),
          const NavigationDestination(
            icon: Icon(Icons.photo_camera_outlined),
            label: 'Upload',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: cartQuantity > 0,
              label: Text('$cartQuantity'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            label: 'Cart',
          ),
        ],
      ),
    );
  }

  Widget _categories() {
    final categories = ref.watch(categoriesProvider);
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, i) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = categories[i];
          final on = cat == _selectedCategory;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? AppColors.saffron : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: on ? AppColors.saffron : AppColors.line,
                ),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: on ? Colors.white : AppColors.ink,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _productGrid(List<Product> allProducts) {
    final parents = _filter(allProducts);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: parents.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 11,
        mainAxisSpacing: 11,
        childAspectRatio: 0.70,
      ),
      itemBuilder: (_, i) {
        final parent = parents[i];
        final variants = allProducts
            .where((p) => p.parentProductId == parent.id && p.isVisible)
            .toList();
        return ProductCatalogCard(parent: parent, variants: variants);
      },
    );
  }
}

class _SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: AppColors.muted, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              decoration: const InputDecoration(
                hintText: 'Search dal, rice, spices…',
                hintStyle: TextStyle(color: AppColors.muted, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.green, Color(0xFF43A047)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Ration Made Easy',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 3),
          Text(
            "Reorder last month's list in one tap",
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
