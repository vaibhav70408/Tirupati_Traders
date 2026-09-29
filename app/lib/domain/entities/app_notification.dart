import 'package:flutter/foundation.dart';

/// An in-app message shown to the customer (e.g. order approved with changes).
@immutable
class AppNotification {
  final String id;
  final String orderId;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;

  const AppNotification({
    required this.id,
    required this.orderId,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
  });

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    orderId: orderId,
    title: title,
    body: body,
    createdAt: createdAt,
    read: read ?? this.read,
  );
}
