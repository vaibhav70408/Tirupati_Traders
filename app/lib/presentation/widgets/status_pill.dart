import 'package:flutter/material.dart';

import '../../domain/entities/order.dart';
import '../../theme/app_colors.dart';

/// Coloured status badge for an [OrderStatus].
class StatusPill extends StatelessWidget {
  final OrderStatus status;

  const StatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colours(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  (Color, Color) _colours(OrderStatus status) {
    switch (status) {
      case OrderStatus.placed:
        return (const Color(0xFFFFF3E0), const Color(0xFFE65100));
      case OrderStatus.approved:
        return (AppColors.greenLight, AppColors.green);
      case OrderStatus.outForDelivery:
        return (const Color(0xFFE3F2FD), const Color(0xFF1565C0));
      case OrderStatus.delivered:
        return (AppColors.greenLight, AppColors.green);
      case OrderStatus.declined:
        return (const Color(0xFFFDECEC), const Color(0xFFC62828));
    }
  }
}
