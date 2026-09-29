import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/payment/payment_service.dart';
import '../../application/providers.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/order.dart';
import '../../presentation/utils/product_display_name.dart';
import '../../presentation/utils/quantity_formatter.dart';
import '../../theme/app_colors.dart';

class TrackOrderScreen extends ConsumerWidget {
  final Order order;

  const TrackOrderScreen({super.key, required this.order});

  /// Resolves the latest version of this order so admin changes appear live.
  Order _current(WidgetRef ref) {
    final orders = ref.watch(customerOrdersProvider).value ?? const [];
    for (final o in orders) {
      if (o.id == order.id) return o;
    }
    return order;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = _current(ref);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        title: Text('Order #${current.id}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (current.modifiedByAdmin) const _ChangedBanner(),
          if (current.modifiedByAdmin) const SizedBox(height: 14),
          if (current.status == OrderStatus.declined)
            const _DeclinedBanner()
          else
            _Timeline(currentStatus: current.status),
          const SizedBox(height: 16),
          _PaymentStatusCard(order: current),
          const SizedBox(height: 12),
          if (current.orderListImageUrls.isNotEmpty) ...[
            _ListImagesCard(order: current),
            const SizedBox(height: 12),
          ],
          _BillCard(order: current),
          if (current.handwrittenBillImageUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            _HandwrittenBillCard(order: current),
          ],
        ],
      ),
    );
  }
}

class _PaymentStatusCard extends ConsumerStatefulWidget {
  final Order order;
  const _PaymentStatusCard({required this.order});

  @override
  ConsumerState<_PaymentStatusCard> createState() => _PaymentStatusCardState();
}

class _PaymentStatusCardState extends ConsumerState<_PaymentStatusCard> {
  bool _isPaying = false;

  Future<void> _payViaUpi(BuildContext context) async {
    setState(() => _isPaying = true);
    try {
      final result = await ref
          .read(paymentServiceProvider)
          .pay(context, widget.order);

      if (!context.mounted) return;

      switch (result) {
        case PaymentSuccess():
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Payment of ₹${widget.order.totalAmount} successful',
              ),
            ),
          );
        case PaymentFailure():
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(result.message)));
        case PaymentCancelled():
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Payment cancelled.')));
      }
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final canPayNow = order.status == OrderStatus.approved && !order.isPaid;

    final paymentLabel = order.isPaid
        ? 'Paid'
        : canPayNow
        ? 'Unpaid · UPI available'
        : 'Cash / pay at pickup or on delivery';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: order.isPaid ? AppColors.greenLight : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                order.isPaid ? Icons.check_circle : Icons.payment_outlined,
                color: order.isPaid ? AppColors.green : AppColors.saffronDark,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Payment Status',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: order.isPaid ? AppColors.green : AppColors.ink,
                  ),
                ),
              ),
              Text(
                paymentLabel,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: order.isPaid ? AppColors.green : AppColors.ink,
                ),
              ),
            ],
          ),
          if (canPayNow) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.saffronDark,
                ),
                onPressed: _isPaying ? null : () => _payViaUpi(context),
                icon: _isPaying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.qr_code_2, size: 18),
                label: Text('Pay ₹${order.totalAmount} via UPI'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChangedBanner extends StatelessWidget {
  const _ChangedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Color(0xFFE65100), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Approved with changes — the shop adjusted your order after '
              'checking stock & weights. See details below.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFFE65100)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeclinedBanner extends StatelessWidget {
  const _DeclinedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF5BFBF)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cancel_outlined, color: Color(0xFFC62828), size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order Declined',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFC62828),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'The shop is unable to fulfil this order right now.',
                  style: TextStyle(fontSize: 12, color: Color(0xFFC62828)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  final Order order;
  const _BillCard({required this.order});

  CartItem? _currentFor(String productId) {
    for (final item in order.items) {
      if (item.product.id == productId) return item;
    }
    return null;
  }

  List<CartItem> _addedItems() {
    final originalIds = order.originalItems.map((i) => i.product.id).toSet();
    return order.items
        .where((i) => !originalIds.contains(i.product.id))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          for (final original in order.originalItems)
            _DiffRow(
              original: original,
              current: _currentFor(original.product.id),
            ),
          for (final added in _addedItems()) _AddedRow(item: added),
          const Divider(height: 18, color: AppColors.line),
          _totalRow(),
        ],
      ),
    );
  }

  Widget _totalRow() {
    final changedTotal =
        order.modifiedByAdmin && order.totalAmount != order.originalTotal;
    final isUnapprovedListOrder =
        order.isListOrder && order.status == OrderStatus.placed;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Total',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        Row(
          children: [
            if (changedTotal) ...[
              Text(
                '₹${order.originalTotal}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.muted,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (isUnapprovedListOrder)
              const Text(
                'Will be calculated by shop after approval',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              )
            else
              Text(
                '₹${order.totalAmount}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// A line item the admin added to the order during review.
class _AddedRow extends ConsumerWidget {
  final CartItem item;
  const _AddedRow({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider).value ?? const [];
    final productsById = {for (final p in products) p.id: p};
    final displayName = productDisplayName(item.product, productsById);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.greenLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'ADDED',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.green,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  '${formatQuantityCompact(item.quantity, item.product)} × ₹${item.unitPrice}${item.product.isLoose ? '/kg' : ''}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '₹${item.lineTotal}',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// One order line, showing the original struck through when the admin changed
/// the quantity/price, or marking it Unavailable when it was removed.
class _DiffRow extends ConsumerWidget {
  final CartItem original;
  final CartItem? current;

  const _DiffRow({required this.original, required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider).value ?? const [];
    final productsById = {for (final p in products) p.id: p};
    final displayName = productDisplayName(original.product, productsById);

    final removed = current == null;
    final changed =
        !removed &&
        (current!.quantity != original.quantity ||
            current!.unitPrice != original.unitPrice);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: removed ? AppColors.muted : AppColors.ink,
                    decoration: removed ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 1),
                _detail(removed, changed),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _trailing(removed, changed),
        ],
      ),
    );
  }

  Widget _detail(bool removed, bool changed) {
    if (removed) {
      return const Text(
        'Unavailable',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFFC62828),
        ),
      );
    }
    if (changed) {
      return Row(
        children: [
          Text(
            '${formatQuantityCompact(original.quantity, original.product)} × ₹${original.unitPrice}${original.product.isLoose ? '/kg' : ''}',
            style: const TextStyle(
              fontSize: 10.5,
              color: AppColors.muted,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const Text(
            '  →  ',
            style: TextStyle(fontSize: 10.5, color: AppColors.muted),
          ),
          Text(
            '${formatQuantityCompact(current!.quantity, current!.product)} × ₹${current!.unitPrice}${current!.product.isLoose ? '/kg' : ''}',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      );
    }
    return Text(
      '${formatQuantityCompact(original.quantity, original.product)} × ₹${original.unitPrice}${original.product.isLoose ? '/kg' : ''}',
      style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
    );
  }

  Widget _trailing(bool removed, bool changed) {
    if (removed) {
      return Text(
        '₹${original.lineTotal}',
        style: const TextStyle(
          fontSize: 12.5,
          color: AppColors.muted,
          decoration: TextDecoration.lineThrough,
        ),
      );
    }
    if (changed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '₹${original.lineTotal}',
            style: const TextStyle(
              fontSize: 10.5,
              color: AppColors.muted,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          Text(
            '₹${current!.lineTotal}',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ],
      );
    }
    return Text(
      '₹${original.lineTotal}',
      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
    );
  }
}

class _ListImagesCard extends StatelessWidget {
  final Order order;
  const _ListImagesCard({required this.order});

  void _showFullImage(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: Center(child: InteractiveViewer(child: Image.network(url))),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your uploaded list',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: order.orderListImageUrls.length,
            itemBuilder: (ctx, i) => GestureDetector(
              onTap: () => _showFullImage(context, order.orderListImageUrls[i]),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  order.orderListImageUrls[i],
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const Center(child: CircularProgressIndicator()),
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppColors.greenLight,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HandwrittenBillCard extends StatelessWidget {
  final Order order;
  const _HandwrittenBillCard({required this.order});

  void _showFullImage(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: Center(child: InteractiveViewer(child: Image.network(url))),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final urls = order.handwrittenBillImageUrls;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 18,
                color: AppColors.saffronDark,
              ),
              SizedBox(width: 8),
              Text(
                'Handwritten bill from shop',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: urls.length,
            itemBuilder: (ctx, i) => GestureDetector(
              onTap: () => _showFullImage(context, urls[i]),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 160,
                  color: AppColors.greenLight,
                  child: Image.network(
                    urls[i],
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const Center(child: CircularProgressIndicator()),
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: AppColors.greenLight,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'This is the shop\'s handwritten bill for your order.',
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  final OrderStatus currentStatus;

  const _Timeline({required this.currentStatus});

  /// Active order progression stages. Declined is handled separately.
  static const _stages = [
    OrderStatus.placed,
    OrderStatus.approved,
    OrderStatus.outForDelivery,
    OrderStatus.delivered,
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _stages.indexOf(currentStatus);
    return Column(
      children: [
        for (var i = 0; i < _stages.length; i++)
          _TimelineRow(
            label: _stages[i].label,
            done: i <= currentIndex,
            isLast: i == _stages.length - 1,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final String label;
  final bool done;
  final bool isLast;

  const _TimelineRow({
    required this.label,
    required this.done,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? AppColors.green : Colors.white,
                  border: Border.all(
                    color: done ? AppColors.green : AppColors.line,
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: done
                    ? const Icon(Icons.check, size: 15, color: Colors.white)
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: done ? AppColors.green : AppColors.line,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 3, bottom: 20),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: done ? AppColors.ink : AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
