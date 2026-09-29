import 'package:flutter/foundation.dart';

/// An authorized admin/staff member stored in Firestore.
@immutable
class Admin {
  final String phoneNumber;
  final String name;
  final bool isActive;

  const Admin({
    required this.phoneNumber,
    required this.name,
    this.isActive = true,
  });

  /// Normalizes a phone number by removing spaces/dashes.
  static String normalize(String phone) =>
      phone.replaceAll(RegExp(r'[\s-]'), '');

  Admin copyWith({String? phoneNumber, String? name, bool? isActive}) {
    return Admin(
      phoneNumber: phoneNumber ?? this.phoneNumber,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
    );
  }
}
