import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/firebase_auth_repository.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/user_repository.dart';
import '../providers.dart';
import 'auth_state.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(FirebaseAuth.instance),
);

/// Emits the currently signed-in Firebase user (or null).
final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// Drives the phone-OTP sign-in / sign-up flow.
class AuthController extends Notifier<AuthState> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);
  UserRepository get _userRepo => ref.read(userRepositoryProvider);

  @override
  AuthState build() => const AuthState();

  Future<void> startSignup({
    required String name,
    required String phoneNumber,
    required String address,
  }) async {
    state = AuthState(
      phase: AuthPhase.sendingCode,
      mode: AuthMode.signup,
      phoneNumber: phoneNumber,
      name: name,
      address: address,
    );
    await _sendOtp(phoneNumber);
  }

  Future<void> startLogin(String phoneNumber) async {
    state = AuthState(
      phase: AuthPhase.sendingCode,
      mode: AuthMode.login,
      phoneNumber: phoneNumber,
    );
    await _sendOtp(phoneNumber);
  }

  Future<void> _sendOtp(String phoneNumber) async {
    await _repo.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      codeSent: (verificationId) {
        state = state.copyWith(
          phase: AuthPhase.codeSent,
          verificationId: verificationId,
        );
      },
      onAutoVerified: () async {
        // Instant verification on Android: Firebase already signed the user in.
        await _onFirebaseSignedIn();
      },
      onError: (message) {
        state = state.copyWith(phase: AuthPhase.idle, error: message);
      },
    );
  }

  /// Resends the OTP using the current phone number and mode.
  Future<void> resendOtp() async {
    final phoneNumber = state.phoneNumber;
    if (phoneNumber == null || phoneNumber.isEmpty) return;
    state = state.copyWith(phase: AuthPhase.sendingCode);
    await _sendOtp(phoneNumber);
  }

  Future<void> verifyOtp(String smsCode) async {
    final verificationId = state.verificationId;
    if (verificationId == null) return;
    state = state.copyWith(phase: AuthPhase.verifying);
    try {
      await _repo.signInWithSmsCode(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      await _onFirebaseSignedIn();
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        phase: AuthPhase.codeSent,
        error: e.message ?? 'Invalid code',
      );
    }
  }

  Future<void> _onFirebaseSignedIn() async {
    final firebaseUser = _repo.currentUser;
    if (firebaseUser == null) {
      state = state.copyWith(
        phase: AuthPhase.idle,
        error: 'Sign-in failed. Please try again.',
      );
      return;
    }

    if (state.mode == AuthMode.signup) {
      final name = state.name;
      final address = state.address;
      if (name == null || name.trim().isEmpty || address == null) {
        state = state.copyWith(
          signedIn: true,
          profileExists: false,
          phase: AuthPhase.authenticated,
        );
        return;
      }
      await _saveProfile(
        uid: firebaseUser.uid,
        phoneNumber: firebaseUser.phoneNumber ?? state.phoneNumber ?? '',
        name: name,
        address: address,
      );
      state = state.copyWith(
        signedIn: true,
        profileExists: true,
        phase: AuthPhase.authenticated,
      );
      return;
    }

    // Login flow: check whether a profile already exists.
    final existing = await _userRepo.getUser(firebaseUser.uid);
    if (existing != null && existing.hasProfile) {
      state = state.copyWith(
        signedIn: true,
        profileExists: true,
        phase: AuthPhase.authenticated,
      );
      return;
    }

    // Also check by phone number in case the account was created on another
    // device and only indexed by phone.
    final byPhone = await _userRepo.getUserByPhone(
      firebaseUser.phoneNumber ?? state.phoneNumber ?? '',
    );
    if (byPhone != null && byPhone.hasProfile) {
      state = state.copyWith(
        signedIn: true,
        profileExists: true,
        phase: AuthPhase.authenticated,
      );
      return;
    }

    // Signed in but no profile -> ask the user to complete signup.
    state = state.copyWith(
      signedIn: true,
      profileExists: false,
      phase: AuthPhase.authenticated,
    );
  }

  /// Saves the customer profile and marks the flow complete.
  Future<void> saveProfile({
    required String name,
    required String address,
  }) async {
    final firebaseUser = _repo.currentUser;
    if (firebaseUser == null) {
      state = state.copyWith(error: 'Not signed in. Please try again.');
      return;
    }
    await _saveProfile(
      uid: firebaseUser.uid,
      phoneNumber: firebaseUser.phoneNumber ?? state.phoneNumber ?? '',
      name: name,
      address: address,
    );
    state = state.copyWith(
      name: name,
      address: address,
      signedIn: true,
      profileExists: true,
      phase: AuthPhase.authenticated,
    );
  }

  Future<void> _saveProfile({
    required String uid,
    required String phoneNumber,
    required String name,
    required String address,
  }) async {
    await _userRepo.saveUser(
      AppUser(
        uid: uid,
        phoneNumber: phoneNumber,
        name: name.trim(),
        address: address.trim(),
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Development-only: sign in anonymously and create a dummy profile so the
  /// customer flow can be tested without OTP.
  Future<void> devLogin() async {
    state = state.copyWith(phase: AuthPhase.sendingCode);
    await _repo.signInAnonymously();
    final firebaseUser = _repo.currentUser;
    if (firebaseUser == null) {
      state = state.copyWith(
        phase: AuthPhase.idle,
        error: 'Dev login failed. Please try again.',
      );
      return;
    }
    await _saveProfile(
      uid: firebaseUser.uid,
      phoneNumber: '0000000000',
      name: 'Dev Customer',
      address: 'Dev Address, Locality',
    );
    state = state.copyWith(
      signedIn: true,
      profileExists: true,
      phase: AuthPhase.authenticated,
    );
  }

  void reset() => state = const AuthState();

  Future<void> signOut() async {
    await _repo.signOut();
    reset();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
