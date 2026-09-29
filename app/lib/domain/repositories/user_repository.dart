import '../entities/app_user.dart';

/// Abstraction over customer profile persistence.
abstract interface class UserRepository {
  /// Fetches a user profile by Firebase [uid].
  Future<AppUser?> getUser(String uid);

  /// Looks up a user profile by [phoneNumber].
  Future<AppUser?> getUserByPhone(String phoneNumber);

  /// Persists or updates a user profile.
  Future<void> saveUser(AppUser user);

  /// Streams a user profile by Firebase [uid].
  Stream<AppUser?> watchUser(String uid);
}
