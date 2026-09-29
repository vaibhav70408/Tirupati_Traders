import '../../domain/entities/cart_item.dart';
import '../../domain/entities/product.dart';

/// Formats a product quantity for customer-facing UI.
///
/// Loose items are shown in grams / kilograms based on the total weight,
/// e.g. "250 g", "500 g", "1 kg". Fixed items show the unit count with the
/// product's [unit] label, e.g. "1 bottle", "2 packets".
String formatProductQuantity(
  int quantity,
  Product product, {
  bool showQuantity = true,
}) {
  if (product.isLoose) {
    if (!showQuantity) return 'kg';
    if (quantity <= 0) return '0';
    final totalGrams = quantity * product.stepInGrams;
    if (totalGrams >= 1000) {
      final kg = totalGrams / 1000;
      return '${_trimDecimal(kg)} kg';
    }
    return '$totalGrams g';
  }

  final unit = product.unit.isEmpty ? 'unit' : product.unit;
  if (!showQuantity) return unit;
  if (quantity <= 0) return '0';
  return '$quantity $unit';
}

/// Short version of [formatProductQuantity] for compact spaces like stepper
/// labels, e.g. "250 g" or "2".
String formatQuantityCompact(int quantity, Product product) {
  if (quantity <= 0) return '0';

  if (product.isLoose) {
    final totalGrams = quantity * product.stepInGrams;
    if (totalGrams >= 1000) {
      return '${_trimDecimal(totalGrams / 1000)} kg';
    }
    return '${totalGrams}g';
  }

  return '$quantity';
}

/// Formats a cart item's quantity and price summary, e.g.
/// "250 g × ₹50/kg" or "2 bottles × ₹30".
String formatCartItemSummary(CartItem item) {
  final qty = formatProductQuantity(item.quantity, item.product);
  final rate = '₹${item.unitPrice}/kg';
  return '$qty × $rate';
}

String _trimDecimal(double value) {
  final s = value.toStringAsFixed(2);
  if (s.endsWith('.00')) return s.substring(0, s.length - 3);
  if (s.endsWith('0')) return s.substring(0, s.length - 1);
  return s;
}
