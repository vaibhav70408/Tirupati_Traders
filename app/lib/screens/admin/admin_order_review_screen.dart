import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../application/admin/order_admin_service.dart';
import '../../application/providers.dart';
import '../../data/services/image_upload_service.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/product.dart';
import '../../presentation/utils/product_display_name.dart';
import '../../presentation/utils/quantity_formatter.dart';
import '../../presentation/widgets/status_pill.dart';
import '../../theme/app_colors.dart';

/// Admin review of a single order.
/// For a freshly placed order the admin can toggle availability, change
/// quantity, and edit price per item; the final bill recalculates live.
/// Later statuses are read-only with a status-advancing action.
class AdminOrderReviewScreen extends ConsumerStatefulWidget {
  final Order order;

  const AdminOrderReviewScreen({super.key, required this.order});

  @override
  ConsumerState<AdminOrderReviewScreen> createState() =>
      _AdminOrderReviewScreenState();
}

class _AdminOrderReviewScreenState
    extends ConsumerState<AdminOrderReviewScreen> {
  late final List<_LineDraft> _drafts;
  late final TextEditingController _manualBillController;

  bool get _isEditable => widget.order.status == OrderStatus.placed;

  bool get _isListOrder => widget.order.orderListImageUrls.isNotEmpty;

  int get _computedFinalBill =>
      _drafts.where((d) => d.included).fold(0, (sum, d) => sum + d.lineTotal);

  int get _finalBill {
    if (!_isListOrder) return _computedFinalBill;
    final entered = int.tryParse(_manualBillController.text) ?? 0;
    if (entered > 0) return entered;
    return _computedFinalBill;
  }

  int get _includedCount => _drafts.where((d) => d.included).length;

  bool get _canApprove =>
      _includedCount > 0 || widget.order.orderListImageUrls.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _drafts = widget.order.items
        .map(
          (item) => _LineDraft(
            item: item,
            controller: TextEditingController(text: '${item.unitPrice}'),
          ),
        )
        .toList();
    _manualBillController = TextEditingController(
      text: _isListOrder && widget.order.totalAmount > 0
          ? '${widget.order.totalAmount}'
          : '',
    );
  }

  @override
  void dispose() {
    for (final d in _drafts) {
      d.controller.dispose();
    }
    _manualBillController.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    final revised = <CartItem>[
      for (final d in _drafts.where((d) => d.included))
        CartItem(
          product: d.item.product,
          quantity: d.quantity,
          unitPriceOverride: d.unitPrice == d.item.product.price
              ? null
              : d.unitPrice,
        ),
    ];

    if (_isListOrder && _finalBill > 0 && revised.isEmpty) {
      await ref
          .read(orderRepositoryProvider)
          .setFinalBillAmount(orderId: widget.order.id, amount: _finalBill);
      // Fetch the current order after setting the bill amount so the
      // approval notification uses the updated total.
      final current =
          ref
              .read(ordersProvider)
              .value
              ?.firstWhere(
                (o) => o.id == widget.order.id,
                orElse: () => widget.order,
              ) ??
          widget.order;
      await ref
          .read(orderAdminServiceProvider)
          .approveWithRevision(current, current.items);
    } else {
      await ref
          .read(orderAdminServiceProvider)
          .approveWithRevision(widget.order, revised);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Order #${widget.order.id} approved')),
    );
  }

  Future<void> _advance() async {
    final admin = ref.read(orderAdminServiceProvider);
    final current =
        ref
            .watch(ordersProvider)
            .value
            ?.firstWhere(
              (o) => o.id == widget.order.id,
              orElse: () => widget.order,
            ) ??
        widget.order;

    final message = switch (current.status) {
      OrderStatus.approved => 'Order marked out for delivery',
      OrderStatus.outForDelivery => 'Order marked delivered',
      _ => '',
    };
    switch (current.status) {
      case OrderStatus.approved:
        await admin.markOutForDelivery(current.id);
      case OrderStatus.outForDelivery:
        await admin.markDelivered(current.id);
      default:
        return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    Navigator.pop(context);
  }

  Future<void> _decline() async {
    final reason = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline order?'),
        content: const Text(
          'The customer will be notified that this order cannot be fulfilled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('default'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (reason == null || !mounted) return;

    await ref.read(orderAdminServiceProvider).declineOrder(widget.order.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Order #${widget.order.id} declined')),
    );
    Navigator.pop(context);
  }

  void _showCustomerDetails(BuildContext context) {
    final phone = widget.order.customerPhone ?? 'Not available';
    final address = widget.order.customerAddress ?? 'Not available';

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Customer details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 16),
              _detailRow(Icons.person_outline, widget.order.customerName),
              const SizedBox(height: 12),
              _detailRow(Icons.phone_outlined, phone),
              const SizedBox(height: 12),
              _detailRow(Icons.location_on_outlined, address),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.muted),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: AppColors.ink),
          ),
        ),
      ],
    );
  }

  Future<void> _addItem() async {
    final products = ref.read(productsProvider).value ?? const <Product>[];
    final existingIds = _drafts.map((d) => d.item.product.id).toSet();
    final parents = products.where((p) => !p.isVariant).toList(growable: false);

    final picked = await showModalBottomSheet<_PickedAddItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          _AddItemPicker(parents: parents, existingIds: existingIds),
    );
    if (picked == null) return;

    setState(() {
      _drafts.add(
        _LineDraft(
          item: CartItem(product: picked.product, quantity: picked.quantity),
          controller: TextEditingController(text: '${picked.product.price}'),
          isAdded: true,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        title: Text('#${widget.order.id} · ${widget.order.customerName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Customer details',
            onPressed: () => _showCustomerDetails(context),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: StatusPill(status: widget.order.status)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Text(
            _isEditable
                ? widget.order.isListOrder
                      ? 'Customer uploaded a shopping list. Add items if needed, '
                            'then approve.'
                      : 'Untick items you cannot supply, adjust quantity or price '
                            'for loose items, then approve.'
                : 'Order details.',
            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          if (widget.order.orderListImageUrls.isNotEmpty) ...[
            _listImagesCard(),
            const SizedBox(height: 12),
          ],
          _itemsCard(),
          const SizedBox(height: 12),
          _billCard(),
          if (_current().handwrittenBillImageUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            _handwrittenBillCard(current: _current()),
          ],
          const SizedBox(height: 12),
          _uploadBillButton(
            order: _current(),
            onUpload: _uploadHandwrittenBill,
          ),
        ],
      ),
      bottomNavigationBar: _actionBar(),
    );
  }

  void _showFullImage(String url) {
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

  Widget _listImagesCard() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer shopping list',
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
            itemCount: widget.order.orderListImageUrls.length,
            itemBuilder: (ctx, i) => GestureDetector(
              onTap: () => _showFullImage(widget.order.orderListImageUrls[i]),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  widget.order.orderListImageUrls[i],
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

  Widget _handwrittenBillCard({required Order current}) {
    final urls = current.handwrittenBillImageUrls;
    return Container(
      padding: const EdgeInsets.all(13),
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
                'Handwritten bill',
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
              onTap: () => _showFullImage(urls[i]),
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
        ],
      ),
    );
  }

  Widget _uploadBillButton({
    required Order order,
    required VoidCallback onUpload,
  }) {
    final hasBill = order.handwrittenBillImageUrls.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasBill)
            Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  size: 18,
                  color: AppColors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  '${order.handwrittenBillImageUrls.length} bill image${order.handwrittenBillImageUrls.length == 1 ? '' : 's'} uploaded',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.green,
                  ),
                ),
              ],
            )
          else
            const Row(
              children: [
                Icon(
                  Icons.receipt_outlined,
                  size: 18,
                  color: AppColors.saffronDark,
                ),
                SizedBox(width: 8),
                Text(
                  'Upload handwritten bill',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.saffronDark,
              side: const BorderSide(color: AppColors.saffronDark),
            ),
            onPressed: onUpload,
            icon: const Icon(Icons.upload_outlined),
            label: Text(
              hasBill ? 'Add another bill image' : 'Upload bill image',
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _drafts.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.line),
            _isEditable
                ? _EditableRow(
                    draft: _drafts[i],
                    onChanged: () => setState(() {}),
                  )
                : _ReadOnlyRow(item: _drafts[i].item),
          ],
          if (_isEditable) ...[
            const Divider(height: 1, color: AppColors.line),
            InkWell(
              onTap: _addItem,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 18, color: AppColors.saffronDark),
                    SizedBox(width: 6),
                    Text(
                      'Add item',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.saffronDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _billCard() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          if (_isEditable)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Supplying items',
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                ),
                Text(
                  '$_includedCount of ${_drafts.length}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          if (_isEditable) const Divider(height: 16, color: AppColors.line),
          if (_isEditable && _isListOrder) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Enter final bill',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _manualBillController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixText: '₹',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 16, color: AppColors.line),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Final Bill',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              Text(
                '₹${_isEditable ? _finalBill : widget.order.totalAmount}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _markPaid() async {
    await ref.read(orderAdminServiceProvider).markPaid(widget.order.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Order #${widget.order.id} marked as paid')),
    );
  }

  Future<void> _uploadHandwrittenBill() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;

    await _uploadBillImage(picked);
  }

  Future<void> _uploadBillImage(XFile picked) async {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Uploading bill image…')));

    try {
      final url = await ref
          .read(imageUploadServiceProvider)
          .uploadHandwrittenBill(widget.order.id, picked);
      await ref
          .read(orderRepositoryProvider)
          .uploadHandwrittenBillImage(orderId: widget.order.id, imageUrl: url);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Handwritten bill uploaded')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Upload failed: ${e.message}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  /// Resolves the latest version of this order so uploaded images & payments
  /// appear without leaving the screen.
  Order _current() {
    final orders = ref.watch(ordersProvider).value ?? const [];
    for (final o in orders) {
      if (o.id == widget.order.id) return o;
    }
    return widget.order;
  }

  Widget? _actionBar() {
    final current = _current();
    final hasBill = current.handwrittenBillImageUrls.isNotEmpty;

    if (current.status == OrderStatus.placed) {
      final canApprove = _isListOrder
          ? _canApprove && _finalBill > 0
          : _canApprove;
      return _buildActionBar(
        primaryLabel: 'Approve & Send · ₹$_finalBill',
        primaryAction: _approve,
        primaryEnabled: canApprove,
        secondaryLabel: 'Decline Order',
        secondaryAction: _decline,
      );
    }

    if (current.status == OrderStatus.approved) {
      return _buildActionBar(
        primaryLabel: 'Mark Out for Delivery',
        primaryAction: _advance,
        primaryEnabled: true,
        secondaryLabel: current.isPaid
            ? 'Payment received'
            : 'Mark Payment Received',
        secondaryAction: current.isPaid ? null : _markPaid,
      );
    }

    if (current.status == OrderStatus.outForDelivery) {
      return _buildActionBar(
        primaryLabel: 'Mark Delivered',
        primaryAction: _advance,
        primaryEnabled: true,
        secondaryLabel: current.isPaid
            ? 'Payment received'
            : 'Mark Payment Received',
        secondaryAction: current.isPaid ? null : _markPaid,
      );
    }

    if (current.status == OrderStatus.delivered) {
      return _buildActionBar(
        primaryLabel: current.isPaid ? 'Delivered' : 'Mark Payment Received',
        primaryAction: current.isPaid ? () async {} : _markPaid,
        primaryEnabled: !current.isPaid,
        secondaryLabel: hasBill ? 'Bill uploaded' : 'Upload handwritten bill',
        secondaryAction: hasBill ? null : _uploadHandwrittenBill,
      );
    }

    return null;
  }

  Widget _buildActionBar({
    required String primaryLabel,
    required Future<void> Function() primaryAction,
    required bool primaryEnabled,
    required String? secondaryLabel,
    required Future<void> Function()? secondaryAction,
    String? tertiaryLabel,
    Future<void> Function()? tertiaryAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
              onPressed: primaryEnabled ? primaryAction : null,
              child: Text(primaryLabel),
            ),
            if (secondaryLabel != null) ...[
              const SizedBox(height: 8),
              secondaryAction != null
                  ? OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      onPressed: secondaryAction,
                      child: Text(secondaryLabel),
                    )
                  : OutlinedButton(
                      onPressed: null,
                      child: Text(secondaryLabel),
                    ),
            ],
            if (tertiaryLabel != null) ...[
              const SizedBox(height: 8),
              tertiaryAction != null
                  ? OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.saffronDark,
                        side: const BorderSide(color: AppColors.saffronDark),
                      ),
                      onPressed: tertiaryAction,
                      child: Text(tertiaryLabel),
                    )
                  : OutlinedButton(onPressed: null, child: Text(tertiaryLabel)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Mutable working copy of a line item during admin review.
class _LineDraft {
  final CartItem item;
  final TextEditingController controller;
  final bool isAdded;
  bool included = true;
  late int quantity = item.quantity;

  _LineDraft({
    required this.item,
    required this.controller,
    this.isAdded = false,
  });

  int get unitPrice => int.tryParse(controller.text) ?? item.unitPrice;

  int get lineTotal {
    final p = item.product;
    if (p.isLoose) {
      return (unitPrice * quantity * p.stepInGrams / 1000).round();
    }
    return unitPrice * quantity;
  }
}

class _EditableRow extends ConsumerWidget {
  final _LineDraft draft;
  final VoidCallback onChanged;

  const _EditableRow({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider).value ?? const [];
    final productsById = {for (final p in products) p.id: p};
    final displayName = productDisplayName(draft.item.product, productsById);

    final enabled = draft.included;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Checkbox(
              value: draft.included,
              activeColor: AppColors.green,
              onChanged: (v) {
                draft.included = v ?? true;
                onChanged();
              },
            ),
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
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      if (draft.isAdded) ...[
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
                    ],
                  ),
                  Text(
                    draft.item.product.isLoose
                        ? 'per kg · step ${draft.item.product.stepInGrams}g'
                        : 'per ${draft.item.product.unit}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _QtyButton(
                        icon: Icons.remove,
                        enabled: enabled && draft.quantity > 1,
                        onTap: () {
                          draft.quantity--;
                          onChanged();
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          formatQuantityCompact(
                            draft.quantity,
                            draft.item.product,
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _QtyButton(
                        icon: Icons.add,
                        enabled: enabled,
                        onTap: () {
                          draft.quantity++;
                          onChanged();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: 78,
                  child: TextField(
                    controller: draft.controller,
                    enabled: enabled,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    onChanged: (_) => onChanged(),
                    decoration: const InputDecoration(
                      prefixText: '₹',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '= ₹${draft.lineTotal}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _QtyButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 15, color: AppColors.ink),
      ),
    );
  }
}

class _ReadOnlyRow extends ConsumerWidget {
  final CartItem item;
  const _ReadOnlyRow({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider).value ?? const [];
    final productsById = {for (final p in products) p.id: p};
    final displayName = productDisplayName(item.product, productsById);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(item.product.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$displayName · ${item.product.unit}',
              style: const TextStyle(fontSize: 12.5, color: AppColors.ink),
            ),
          ),
          Text(
            '× ${formatQuantityCompact(item.quantity, item.product)}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(width: 12),
          Text(
            '₹${item.lineTotal}',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _PickedAddItem {
  final Product product;
  final int quantity;

  const _PickedAddItem({required this.product, required this.quantity});
}

/// Bottom sheet to pick a catalog product or variant to add to the order.
class _AddItemPicker extends StatefulWidget {
  final List<Product> parents;
  final Set<String> existingIds;

  const _AddItemPicker({required this.parents, required this.existingIds});

  @override
  State<_AddItemPicker> createState() => _AddItemPickerState();
}

class _AddItemPickerState extends State<_AddItemPicker> {
  String _query = '';

  List<Product> get _filtered {
    final q = _query.trim().toLowerCase();
    return widget.parents
        .where(
          (p) =>
              q.isEmpty ||
              p.name.toLowerCase().contains(q) ||
              p.category.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Add an item',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search products…',
                prefixIcon: const Icon(Icons.search, color: AppColors.muted),
                filled: true,
                fillColor: AppColors.greenLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filtered.length,
                itemBuilder: (_, i) => _ParentTile(
                  parent: _filtered[i],
                  existingIds: widget.existingIds,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParentTile extends ConsumerWidget {
  final Product parent;
  final Set<String> existingIds;

  const _ParentTile({required this.parent, required this.existingIds});

  List<Product> _variants(WidgetRef ref) {
    final products = ref.watch(productsProvider).value ?? const [];
    return products
        .where((p) => p.parentProductId == parent.id && p.isVisible)
        .toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variants = _variants(ref);

    if (variants.isEmpty) {
      return _AddTile(
        title: parent.name,
        subtitle: parent.isLoose
            ? '${parent.unit} · ₹${parent.price}/kg'
            : '${parent.unit} · ₹${parent.price}',
        emoji: parent.emoji,
        onTap: () => Navigator.pop(
          context,
          _PickedAddItem(product: parent, quantity: 1),
        ),
      );
    }

    if (variants.length == 1) {
      final only = variants.first;
      return _AddTile(
        title: parent.name,
        subtitle: only.name.trim().isEmpty
            ? '${only.unit} · ₹${only.price}'
            : '${only.name} · ${only.unit} · ₹${only.price}',
        emoji: parent.emoji,
        onTap: () =>
            Navigator.pop(context, _PickedAddItem(product: only, quantity: 1)),
      );
    }

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(left: 12),
      title: Text(
        parent.name,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
      leading: Text(parent.emoji, style: const TextStyle(fontSize: 24)),
      children: [
        for (final variant in variants)
          _AddTile(
            title: variant.name.trim().isEmpty
                ? variant.unit
                : '${variant.name} · ${variant.unit}',
            subtitle: variant.isLoose
                ? '₹${variant.price}/kg · step ${variant.stepInGrams}g'
                : '₹${variant.price}',
            emoji: variant.emoji.isEmpty ? parent.emoji : variant.emoji,
            onTap: () => Navigator.pop(
              context,
              _PickedAddItem(product: variant, quantity: 1),
            ),
          ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String emoji;
  final VoidCallback onTap;

  const _AddTile({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Text(emoji, style: const TextStyle(fontSize: 24)),
      title: Text(
        title,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.add, color: AppColors.saffronDark),
      onTap: onTap,
    );
  }
}
