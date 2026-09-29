import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Saffron pill with − / + controls and the current quantity label.
///
/// [quantityLabel] is the text shown between the buttons, e.g. "2" or "250 g".
class QuantityStepper extends StatelessWidget {
  final String quantityLabel;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const QuantityStepper({
    super.key,
    required this.quantityLabel,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.saffron,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tap(Icons.remove, onDecrement),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              quantityLabel,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          _tap(Icons.add, onIncrement),
        ],
      ),
    );
  }

  Widget _tap(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }
}
