import '../entities/app_user.dart';

/// Abstraction over authentication (Firebase phone auth now).
abstract interface class AuthRepository {
  Stream<AppUser?> authStateChanges();

  AppUser? get currentUser;

  /// Starts phone verification. Fires [codeSent] with a verificationId when the
  /// SMS/test code is ready, [onError] on failure, and [onAutoVerified] if the
  /// platform auto-resolves the code (Android instant verification).
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId) codeSent,
    required void Function(String message) onError,
    void Function()? onAutoVerified,
  });

  /// Completes sign-in with the code the user entered.
  Future<void> signInWithSmsCode({
    required String verificationId,
    required String smsCode,
  });

  /// Development-only anonymous sign-in to bypass OTP.
  Future<void> signInAnonymously();

  Future<void> signOut();
}
