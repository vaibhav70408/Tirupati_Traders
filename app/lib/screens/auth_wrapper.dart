import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth/auth_controller.dart';
import '../application/providers.dart';
import 'admin/admin_dashboard_screen.dart';
import 'customer/customer_home_screen.dart';
import 'customer/customer_profile_completion_screen.dart';
import 'role_selection_screen.dart';

/// Entry wrapper that restores a signed-in session.
///
/// - If no Firebase user is signed in -> role selection.
/// - If signed in and the phone belongs to an active admin -> admin dashboard.
/// - If signed in and the customer profile exists -> customer home.
/// - If signed in but the profile is missing -> ask to complete it.
class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);
    final firebaseUser = authAsync.asData?.value;

    if (firebaseUser == null) {
      return const RoleSelectionScreen();
    }

    final adminStatusAsync = ref.watch(currentAdminStatusProvider);
    return adminStatusAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => _buildCustomerFlow(ref, firebaseUser),
      data: (isAdmin) {
        if (isAdmin) return const AdminDashboardScreen();
        return _buildCustomerFlow(ref, firebaseUser);
      },
    );
  }

  Widget _buildCustomerFlow(WidgetRef ref, dynamic firebaseUser) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    return profileAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const RoleSelectionScreen(),
      data: (profile) {
        if (profile != null && profile.hasProfile) {
          return const CustomerHomeScreen();
        }
        return CustomerProfileCompletionScreen(
          phoneNumber: firebaseUser.phoneNumber ?? '',
        );
      },
    );
  }
}
