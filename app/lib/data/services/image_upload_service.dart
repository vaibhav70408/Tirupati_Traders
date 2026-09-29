import 'dart:math';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../firebase_options.dart';

/// Uploads user-provided images to Firebase Storage and returns public
/// download URLs that can be persisted on an [Order].
class ImageUploadService {
  final FirebaseStorage _storage;

  const ImageUploadService(this._storage);

  /// Uploads one customer shopping-list image for [orderId].
  Future<String> uploadOrderListImage(String orderId, XFile file) async {
    final ref = _storage.ref().child(
      'order_lists/$orderId/${_safeFileName(file)}',
    );
    final bytes = await file.readAsBytes();
    final snapshot = await ref.putData(
      bytes,
      SettableMetadata(contentType: _contentType(file)),
    );
    return snapshot.ref.getDownloadURL();
  }

  /// Uploads the admin handwritten bill image for [orderId].
  Future<String> uploadHandwrittenBill(String orderId, XFile file) async {
    final ref = _storage.ref().child(
      'orders/$orderId/bill/${_safeFileName(file)}',
    );
    final bytes = await file.readAsBytes();
    final snapshot = await ref.putData(
      bytes,
      SettableMetadata(contentType: _contentType(file)),
    );
    return snapshot.ref.getDownloadURL();
  }

  /// Uploads a product photo for [productId] and returns its download URL so
  /// the image is visible on every device, not just the admin's phone.
  Future<String> uploadProductImage(String productId, XFile file) async {
    final ref = _storage.ref().child(
      'products/$productId/${_safeFileName(file)}',
    );
    final bytes = await file.readAsBytes();
    final snapshot = await ref.putData(
      bytes,
      SettableMetadata(contentType: _contentType(file)),
    );
    return snapshot.ref.getDownloadURL();
  }

  String _contentType(XFile file) {
    final lower = file.name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.bmp')) return 'image/bmp';
    return 'image/jpeg';
  }

  /// Builds a Firebase-safe file name with a timestamp and random suffix.
  /// Replaces empty or invalid [XFile.name] values with 'image.jpg'.
  String _safeFileName(XFile file) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    final original = file.path;

    String ext;
    String base;
    final lastDot = original.lastIndexOf('.');
    if (lastDot > 0) {
      ext = original.substring(lastDot);
      base = original.substring(0, lastDot);
    } else {
      ext = '.jpg';
      base = original.isNotEmpty ? original : 'image';
    }

    // Firebase Storage reference names cannot contain certain characters.
    final safeBase = base
        .replaceAll(RegExp(r'[#\$\[\]\/. ]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final safeExt = ext.replaceAll(RegExp(r'[^a-zA-Z0-9.]'), '');
    return '${timestamp}_${random}_$safeBase${safeExt.isNotEmpty ? safeExt : '.jpg'}';
  }
}

/// Provider for the default [FirebaseStorage] backed upload service.
/// Pins the instance to the project's configured bucket so download URLs
/// resolve against the same bucket the bytes were uploaded to.
final imageUploadServiceProvider = Provider<ImageUploadService>((ref) {
  final bucket = DefaultFirebaseOptions.currentPlatform.storageBucket;
  final storage = bucket != null
      ? FirebaseStorage.instanceFor(bucket: 'gs://$bucket')
      : FirebaseStorage.instance;
  return ImageUploadService(storage);
});
