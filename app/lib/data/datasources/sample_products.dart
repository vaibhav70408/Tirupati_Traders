import '../../domain/entities/product.dart';

/// Static seed catalog mirroring the design mockup.
/// Swapped for a Firestore data source in a later phase.
class SampleProducts {
  const SampleProducts._();

  static const List<String> categories = [
    'All',
    'Dal',
    'Rice',
    'Spices',
    'Oil',
  ];

  static const List<Product> items = [
    // Parent product
    Product(
      id: 'toor-dal',
      name: 'Toor Dal',
      unit: 'per kg',
      category: 'Dal',
      price: 145,
      emoji: '🫘',
      isLoose: true,
      stepInGrams: 250,
    ),
    // Parent product with variants (parent is a display shell)
    Product(
      id: 'basmati-rice',
      name: 'Basmati Rice',
      unit: '',
      category: 'Rice',
      price: 0,
      emoji: '🌾',
    ),
    Product(
      id: 'basmati-rice-loose',
      name: 'Basmati Rice',
      unit: 'loose',
      category: 'Rice',
      price: 110,
      emoji: '🌾',
      parentProductId: 'basmati-rice',
      isVisible: true,
      isLoose: true,
      stepInGrams: 250,
    ),
    Product(
      id: 'basmati-rice-5kg',
      name: 'Basmati Rice',
      unit: '5 kg bag',
      category: 'Rice',
      price: 520,
      emoji: '🌾',
      parentProductId: 'basmati-rice',
      isVisible: true,
    ),
    Product(
      id: 'rock-salt',
      name: 'Rock Salt',
      unit: '1 kg',
      category: 'Spices',
      price: 28,
      emoji: '🧂',
    ),
    Product(
      id: 'mustard-oil',
      name: 'Mustard Oil',
      unit: '1 L',
      category: 'Oil',
      price: 190,
      emoji: '🛢️',
      inStock: false,
    ),
  ];
}
