import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

/// Renders a product image from a Firebase Storage URL or a local device file
/// path, falling back to [emoji] when no usable image exists.
///
/// Existing products store an `https` download URL (visible on every device),
/// while a freshly picked-but-not-yet-uploaded image is a local file path only
/// valid on the admin's device. This widget handles both.
class ProductImage extends StatelessWidget {
  final String? imagePath;
  final String emoji;
  final double emojiSize;
  final BoxFit fit;
  final double? width;
  final double? height;

  const ProductImage({
    super.key,
    required this.imagePath,
    required this.emoji,
    this.emojiSize = 34,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  /// True when [path] points to an image that can actually be displayed
  /// (a remote URL or an existing local file), as opposed to emoji-only.
  static bool hasViewablePhoto(String? path) {
    if (path == null || path.isEmpty) return false;
    if (path.startsWith('http')) return true;
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    final isNetwork = path != null && path.startsWith('http');

    if (isNetwork) {
      return Image.network(
        path,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, _, _) => _emoji(),
      );
    }
    if (path != null && path.isNotEmpty && _existsSync(path)) {
      return Image.file(File(path), fit: fit, width: width, height: height);
    }
    return _emoji();
  }

  bool _existsSync(String path) {
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  Widget _emoji() =>
      Center(child: Text(emoji, style: TextStyle(fontSize: emojiSize)));
}

/// Opens a full-screen, pinch-to-zoom preview of a product image. Does nothing
/// when the product has no real photo (emoji-only).
Future<void> showProductImagePreview(
  BuildContext context, {
  required String? imagePath,
  required String emoji,
  String? title,
}) {
  if (!ProductImage.hasViewablePhoto(imagePath)) return Future.value();
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => _ProductImagePreviewDialog(
      imagePath: imagePath,
      emoji: emoji,
      title: title,
    ),
  );
}

class _ProductImagePreviewDialog extends StatelessWidget {
  final String? imagePath;
  final String emoji;
  final String? title;

  const _ProductImagePreviewDialog({
    required this.imagePath,
    required this.emoji,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ProductImage(
                imagePath: imagePath,
                emoji: emoji,
                fit: BoxFit.contain,
                emojiSize: 96,
              ),
            ),
          ),
          if (title != null && title!.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
                child: Text(
                  title!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          Positioned(
            top: 0,
            right: 0,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A tappable product image used on catalog cards: a rounded, fixed-height
/// thumbnail that opens [showProductImagePreview] when it has a real photo,
/// with a small zoom hint in the corner.
class ProductCardImage extends StatelessWidget {
  final String? imagePath;
  final String emoji;
  final double height;
  final String? previewTitle;
  final Color background;

  const ProductCardImage({
    super.key,
    required this.imagePath,
    required this.emoji,
    this.height = 100,
    this.previewTitle,
    this.background = const Color(0xFFEAF3EA),
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = ProductImage.hasViewablePhoto(imagePath);
    return GestureDetector(
      onTap: hasPhoto
          ? () => showProductImagePreview(
              context,
              imagePath: imagePath,
              emoji: emoji,
              title: previewTitle,
            )
          : null,
      child: Container(
        height: height,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasPhoto)
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: ProductImage(
                  imagePath: imagePath,
                  emoji: emoji,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: height,
                ),
              ),
            ProductImage(
              imagePath: imagePath,
              emoji: emoji,
              fit: BoxFit.contain,
              emojiSize: height * 0.42,
              width: double.infinity,
              height: height,
            ),
            if (hasPhoto)
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.zoom_in,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
