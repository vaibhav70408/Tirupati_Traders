import 'package:flutter/foundation.dart';

enum AuthPhase { idle, sendingCode, codeSent, verifying, authenticated }

enum AuthMode { none, signup, login }

/// State of the phone-OTP sign-in flow.
@immutable
class AuthState {
  final AuthPhase phase;
  final AuthMode mode;
  final String? verificationId;
  final String? phoneNumber;
  final String? name;
  final String? address;
  final String? error;
  final bool signedIn;
  final bool profileExists;

  const AuthState({
    this.phase = AuthPhase.idle,
    this.mode = AuthMode.none,
    this.verificationId,
    this.phoneNumber,
    this.name,
    this.address,
    this.error,
    this.signedIn = false,
    this.profileExists = false,
  });

  bool get isBusy =>
      phase == AuthPhase.sendingCode || phase == AuthPhase.verifying;

  bool get needsProfile => signedIn && !profileExists;

  AuthState copyWith({
    AuthPhase? phase,
    AuthMode? mode,
    String? verificationId,
    String? phoneNumber,
    String? name,
    String? address,
    String? error,
    bool? signedIn,
    bool? profileExists,
  }) {
    return AuthState(
      phase: phase ?? this.phase,
      mode: mode ?? this.mode,
      verificationId: verificationId ?? this.verificationId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      name: name ?? this.name,
      address: address ?? this.address,
      error: error,
      signedIn: signedIn ?? this.signedIn,
      profileExists: profileExists ?? this.profileExists,
    );
  }
}
