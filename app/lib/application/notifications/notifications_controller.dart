import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_notification.dart';

/// Holds in-app customer notifications for the session (newest first).
class NotificationsController extends Notifier<List<AppNotification>> {
  int _seq = 0;

  @override
  List<AppNotification> build() => const [];

  void push({
    required String orderId,
    required String title,
    required String body,
  }) {
    final notification = AppNotification(
      id: 'n${_seq++}',
      orderId: orderId,
      title: title,
      body: body,
      createdAt: DateTime.now(),
    );
    state = [notification, ...state];
  }

  void markAllRead() {
    state = [for (final n in state) n.copyWith(read: true)];
  }

  int get unreadCount => state.where((n) => !n.read).length;
}

final notificationsControllerProvider =
    NotifierProvider<NotificationsController, List<AppNotification>>(
      NotificationsController.new,
    );
