import 'package:flutter/foundation.dart';

/// The authenticated customer.
@immutable
class AppUser {
  final String uid;
  final String? phoneNumber;
  final String? name;
  final String? address;
  final DateTime? createdAt;

  const AppUser({
    required this.uid,
    this.phoneNumber,
    this.name,
    this.address,
    this.createdAt,
  });

  bool get hasProfile => name != null && name!.trim().isNotEmpty;

  AppUser copyWith({
    String? uid,
    String? phoneNumber,
    String? name,
    String? address,
    DateTime? createdAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      name: name ?? this.name,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
