import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/admin/product_admin_service.dart';
import '../../application/providers.dart';
import '../../domain/entities/product.dart';
import '../../presentation/widgets/product_thumb.dart';
import '../../theme/app_colors.dart';
import 'admin_edit_product_screen.dart';

class AdminProductsScreen extends ConsumerWidget {
  const AdminProductsScreen({super.key});

  void _openEditor(BuildContext context, {Product? product}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminEditProductScreen(product: product),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Product product,
    int variantCount,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
          variantCount > 0
              ? '''"${product.name}" and its $variantCount variant${variantCount == 1 ? '' : 's'} will be permanently deleted.'''
              : '''"${product.name}" will be permanently deleted.''',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final service = ref.read(productAdminServiceProvider);
    final products = ref.read(productsProvider).value ?? const [];
    await service.delete(product.id);
    for (final variant in products.where(
      (p) => p.parentProductId == product.id,
    )) {
      await service.delete(variant.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(
        title: productsAsync.maybeWhen(
          data: (products) {
            final count = products.where((p) => !p.isVariant).length;
            return Text('Products ($count)');
          },
          orElse: () => const Text('Products'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openEditor(context),
          ),
        ],
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load products.\n$e')),
        data: (products) {
          final parents = products.where((p) => !p.isVariant).toList();
          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: parents.length + 1,
            separatorBuilder: (_, i) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              if (i == parents.length) return const _StockLegend();
              final p = parents[i];
              final variantCount = products
                  .where((x) => x.parentProductId == p.id)
                  .length;
              return _ProductRow(
                product: p,
                variantCount: variantCount,
                onTap: () => _openEditor(context, product: p),
                onToggle: (v) =>
                    ref.read(productAdminServiceProvider).setInStock(p.id, v),
                onDelete: () => _confirmDelete(context, ref, p, variantCount),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        backgroundColor: AppColors.saffron,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final Product product;
  final int variantCount;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  const _ProductRow({
    required this.product,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
    this.variantCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            ProductThumb(product: product, size: 48, emojiSize: 24),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    variantCount > 0
                        ? '$variantCount variants · ${product.category}'
                        : '${product.unit} · ₹${product.price} · ${product.category}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: product.inStock,
              activeThumbColor: AppColors.green,
              onChanged: onToggle,
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, color: AppColors.muted),
              onPressed: () => _showOptionsMenu(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: AppColors.ink),
              title: const Text('Edit product'),
              onTap: () {
                Navigator.of(ctx).pop();
                onTap();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Delete product',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StockLegend extends StatelessWidget {
  const _StockLegend();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 4),
      child: Text(
        'Green = In stock · Grey = Shown as out of stock to customers',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10.5, color: AppColors.muted),
      ),
    );
  }
}
