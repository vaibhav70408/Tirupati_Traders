import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/entities/product.dart';
import '../../theme/app_colors.dart';

/// Shows a product's photo when available, otherwise its emoji.
class ProductThumb extends StatelessWidget {
  final Product product;
  final double size;
  final double radius;
  final double emojiSize;

  const ProductThumb({
    super.key,
    required this.product,
    this.size = 52,
    this.radius = 12,
    this.emojiSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    final path = product.imagePath;
    final isNetwork = path != null && path.startsWith('http');
    final isLocalFile = path != null && !isNetwork && File(path).existsSync();
    final hasPhoto = isNetwork || isLocalFile;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.greenLight,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: hasPhoto
          ? (isNetwork
                ? Image.network(
                    path,
                    fit: BoxFit.cover,
                    width: size,
                    height: size,
                    errorBuilder: (_, _, _) => _emojiFallback(),
                  )
                : Image.file(
                    File(path),
                    fit: BoxFit.cover,
                    width: size,
                    height: size,
                  ))
          : _emojiFallback(),
    );
  }

  Widget _emojiFallback() => Center(
    child: Text(product.emoji, style: TextStyle(fontSize: emojiSize)),
  );
}
