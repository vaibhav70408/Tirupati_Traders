import 'package:flutter/foundation.dart';

enum AdminAuthPhase {
  idle,
  loadingAdmins,
  sendingCode,
  codeSent,
  verifying,
  authenticated,
  denied,
}

/// State of the admin phone-OTP authorization flow.
@immutable
class AdminAuthState {
  final AdminAuthPhase phase;
  final String? verificationId;
  final String? selectedPhone;
  final String? selectedName;
  final String? error;
  final bool isAdmin;

  const AdminAuthState({
    this.phase = AdminAuthPhase.idle,
    this.verificationId,
    this.selectedPhone,
    this.selectedName,
    this.error,
    this.isAdmin = false,
  });

  bool get isBusy =>
      phase == AdminAuthPhase.loadingAdmins ||
      phase == AdminAuthPhase.sendingCode ||
      phase == AdminAuthPhase.verifying;

  AdminAuthState copyWith({
    AdminAuthPhase? phase,
    String? verificationId,
    String? selectedPhone,
    String? selectedName,
    String? error,
    bool? isAdmin,
  }) {
    return AdminAuthState(
      phase: phase ?? this.phase,
      verificationId: verificationId ?? this.verificationId,
      selectedPhone: selectedPhone ?? this.selectedPhone,
      selectedName: selectedName ?? this.selectedName,
      error: error,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }
}
