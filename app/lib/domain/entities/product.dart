import 'package:flutter/foundation.dart';

/// Immutable catalog product entity. Identity is defined by [id].
///
/// [price] is always per-kilogram for loose items ([isLoose] == true) and
/// per-unit for fixed items ([isLoose] == false).
///
/// [stepInGrams] is the increment each +/− tap adds for loose items.
/// [parentProductId] is non-null for variants; the parent product is the
/// display card, variants are shown in a bottom sheet.
/// [isVisible] lets the admin hide a variant without deleting it.
@immutable
class Product {
  final String id;
  final String name;
  final String unit;
  final String category;
  final int price;
  final String emoji;
  final bool inStock;
  final String? imagePath;
  final bool isLoose;
  final int stepInGrams;
  final String? parentProductId;
  final bool isVisible;

  const Product({
    required this.id,
    required this.name,
    required this.unit,
    required this.category,
    required this.price,
    required this.emoji,
    this.inStock = true,
    this.imagePath,
    this.isLoose = false,
    this.stepInGrams = 250,
    this.parentProductId,
    this.isVisible = true,
  });

  bool get isVariant => parentProductId != null && parentProductId!.isNotEmpty;

  Product copyWith({
    String? name,
    String? unit,
    String? category,
    int? price,
    String? emoji,
    bool? inStock,
    String? imagePath,
    bool? isLoose,
    int? stepInGrams,
    String? parentProductId,
    bool? isVisible,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      price: price ?? this.price,
      emoji: emoji ?? this.emoji,
      inStock: inStock ?? this.inStock,
      imagePath: imagePath ?? this.imagePath,
      isLoose: isLoose ?? this.isLoose,
      stepInGrams: stepInGrams ?? this.stepInGrams,
      parentProductId: parentProductId ?? this.parentProductId,
      isVisible: isVisible ?? this.isVisible,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Product && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
