import '../entities/admin.dart';

/// Abstraction over admin identity persistence.
abstract interface class AdminRepository {
  /// Returns all active admins, suitable for populating the login dropdown.
  Future<List<Admin>> getActiveAdmins();

  /// Checks whether [phoneNumber] belongs to an active admin.
  Future<bool> isActiveAdmin(String phoneNumber);
}
