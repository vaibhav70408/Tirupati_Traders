import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/admin.dart';
import '../../domain/repositories/admin_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../auth/auth_controller.dart';
import '../providers.dart';
import 'admin_auth_state.dart';

/// Drives the admin phone-OTP login flow and verifies the signed-in user
/// is an active admin.
class AdminAuthController extends Notifier<AdminAuthState> {
  AuthRepository get _authRepo => ref.read(authRepositoryProvider);
  AdminRepository get _adminRepo => ref.read(adminRepositoryProvider);

  @override
  AdminAuthState build() {
    // Auto-reset this controller when the Firebase user signs out so the
    // admin login screen does not keep redirecting to the dashboard.
    ref.listen(authStateProvider, (previous, next) {
      final user = next.asData?.value;
      if (user == null && state.phase == AdminAuthPhase.authenticated) {
        reset();
      }
    });
    return const AdminAuthState();
  }

  /// Selects an admin from the dropdown and resets prior OTP state.
  void selectAdmin(String name, String phoneNumber) {
    state = state.copyWith(
      selectedName: name,
      selectedPhone: Admin.normalize(phoneNumber),
      phase: AdminAuthPhase.idle,
      verificationId: null,
      error: null,
    );
  }

  /// Sends an OTP to the selected admin's phone number.
  Future<void> sendOtp() async {
    final phone = state.selectedPhone;
    if (phone == null || phone.isEmpty) {
      state = state.copyWith(error: 'Please select an admin');
      return;
    }
    state = state.copyWith(phase: AdminAuthPhase.sendingCode, error: null);
    await _authRepo.verifyPhoneNumber(
      phoneNumber: phone,
      codeSent: (verificationId) {
        state = state.copyWith(
          phase: AdminAuthPhase.codeSent,
          verificationId: verificationId,
        );
      },
      onAutoVerified: () async {
        await _checkAdminAndComplete();
      },
      onError: (message) {
        state = state.copyWith(phase: AdminAuthPhase.idle, error: message);
      },
    );
  }

  /// Resends the OTP to the currently selected admin phone.
  Future<void> resendOtp() async {
    if (state.selectedPhone == null) return;
    state = state.copyWith(phase: AdminAuthPhase.sendingCode, error: null);
    await _authRepo.verifyPhoneNumber(
      phoneNumber: state.selectedPhone!,
      codeSent: (verificationId) {
        state = state.copyWith(
          phase: AdminAuthPhase.codeSent,
          verificationId: verificationId,
        );
      },
      onAutoVerified: () async {
        await _checkAdminAndComplete();
      },
      onError: (message) {
        state = state.copyWith(phase: AdminAuthPhase.idle, error: message);
      },
    );
  }

  /// Verifies the SMS code, signs the user in, and then checks admin status.
  Future<void> verifyOtp(String smsCode) async {
    final verificationId = state.verificationId;
    if (verificationId == null) return;
    state = state.copyWith(phase: AdminAuthPhase.verifying, error: null);
    try {
      await _authRepo.signInWithSmsCode(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      await _checkAdminAndComplete();
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        phase: AdminAuthPhase.codeSent,
        error: e.message ?? 'Invalid code',
      );
    }
  }

  Future<void> _checkAdminAndComplete() async {
    final firebaseUser = _authRepo.currentUser;
    if (firebaseUser == null) {
      state = state.copyWith(
        phase: AdminAuthPhase.idle,
        error: 'Sign-in failed. Please try again.',
      );
      return;
    }

    final phone = firebaseUser.phoneNumber ?? state.selectedPhone ?? '';
    final isAdmin = await _adminRepo.isActiveAdmin(phone);
    if (!isAdmin) {
      await _authRepo.signOut();
      state = state.copyWith(
        phase: AdminAuthPhase.denied,
        error: 'This number is not authorized as admin.',
        isAdmin: false,
      );
      return;
    }

    state = state.copyWith(phase: AdminAuthPhase.authenticated, isAdmin: true);
  }

  void reset() => state = const AdminAuthState();

  /// Development-only: bypass OTP and sign in as the first active admin.
  Future<void> devAdminLogin() async {
    state = state.copyWith(phase: AdminAuthPhase.verifying, error: null);
    try {
      await _authRepo.signInAnonymously();
      final admins = await _adminRepo.getActiveAdmins();
      if (admins.isEmpty) {
        state = state.copyWith(
          phase: AdminAuthPhase.idle,
          error: 'No active admins found for dev login.',
        );
        return;
      }
      final admin = admins.first;
      state = state.copyWith(
        phase: AdminAuthPhase.authenticated,
        isAdmin: true,
        selectedName: admin.name,
        selectedPhone: admin.phoneNumber,
      );
    } catch (e) {
      state = state.copyWith(
        phase: AdminAuthPhase.idle,
        error: 'Dev admin login failed: $e',
      );
    }
  }
}

final adminAuthControllerProvider =
    NotifierProvider<AdminAuthController, AdminAuthState>(
      AdminAuthController.new,
    );
