import 'dart:io';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../application/auth/auth_controller.dart';
import '../../application/providers.dart';
import '../../data/services/image_upload_service.dart';
import '../../theme/app_colors.dart';
import 'orders_screen.dart';

/// Lets a customer place an order by capturing or selecting photos of their
/// handwritten or itemised shopping list.
class CustomerUploadListScreen extends ConsumerStatefulWidget {
  const CustomerUploadListScreen({super.key});

  @override
  ConsumerState<CustomerUploadListScreen> createState() =>
      _CustomerUploadListScreenState();
}

class _CustomerUploadListScreenState
    extends ConsumerState<CustomerUploadListScreen> {
  final _picker = ImagePicker();
  final List<XFile> _images = [];
  bool _isPlacing = false;

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        imageQuality: 80,
      );
      if (picked == null) return;
      setState(() => _images.add(picked));
    } else {
      final picked = await _picker.pickMultiImage(
        maxWidth: 1200,
        imageQuality: 80,
      );
      if (picked.isEmpty) return;
      setState(() => _images.addAll(picked));
    }
  }

  Future<void> _showSourcePicker() async {
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
    if (source == null) return;
    await _pickImage(source);
  }

  Future<void> _placeOrder() async {
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one list image')),
      );
      return;
    }

    setState(() => _isPlacing = true);
    try {
      final firebaseUser = ref.read(authRepositoryProvider).currentUser;
      final profile = ref.read(currentUserProfileProvider).asData?.value;
      final customerName =
          profile?.name ?? firebaseUser?.phoneNumber ?? 'Customer';
      final customerId = firebaseUser?.uid;
      final customerPhone = firebaseUser?.phoneNumber ?? profile?.phoneNumber;
      final customerAddress = profile?.address;

      final uploader = ref.read(imageUploadServiceProvider);
      final batchId =
          'batch_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
      final urls = await Future.wait(
        _images.map((file) => uploader.uploadOrderListImage(batchId, file)),
      );

      final order = await ref
          .read(orderRepositoryProvider)
          .placeListOrder(
            imageUrls: urls,
            customerName: customerName,
            customerId: customerId,
            customerPhone: customerPhone,
            customerAddress: customerAddress,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('List order #${order.id} placed successfully')),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OrdersScreen()),
        (_) => false,
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not upload images: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not place order: $e')));
    } finally {
      if (mounted) setState(() => _isPlacing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload List'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Snap or upload photos of your shopping list. '
            'The shop will prepare your order and send a final bill.',
            style: TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          _addImageButton(),
          const SizedBox(height: 16),
          if (_images.isNotEmpty) _imageGrid(),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: _submitBar(),
    );
  }

  Widget _addImageButton() {
    return InkWell(
      onTap: _isPlacing ? null : _showSourcePicker,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: AppColors.greenLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 40,
              color: _isPlacing ? AppColors.muted : AppColors.green,
            ),
            const SizedBox(height: 8),
            Text(
              'Add list photo',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _isPlacing ? AppColors.muted : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _images.length,
      itemBuilder: (context, index) {
        final file = _images[index];
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(File(file.path), fit: BoxFit.cover),
              Positioned(
                top: 4,
                right: 4,
                child: InkWell(
                  onTap: _isPlacing
                      ? null
                      : () => setState(() => _images.removeAt(index)),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _submitBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
          onPressed: _isPlacing || _images.isEmpty ? null : _placeOrder,
          child: _isPlacing
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'Place list order · ${_images.length} image${_images.length == 1 ? '' : 's'}',
                ),
        ),
      ),
    );
  }
}
