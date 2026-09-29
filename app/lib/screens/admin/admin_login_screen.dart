import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/admin/admin_auth_controller.dart';
import '../../application/admin/admin_auth_state.dart';
import '../../application/providers.dart';
import '../../theme/app_colors.dart';
import 'admin_dashboard_screen.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminAuthControllerProvider);
    final controller = ref.read(adminAuthControllerProvider.notifier);

    final theme = Theme.of(context);

    if (state.phase == AdminAuthPhase.authenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        title: const Text('Admin Login'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.ink, Color(0xFF3A3F47)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'TT',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Admin Panel',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tirupati Traders · Staff Login',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 28),
              _AdminDropdown(
                selected: state.selectedPhone,
                onSelected: (name, phone) {
                  controller.selectAdmin(name, phone);
                },
              ),
              const SizedBox(height: 24),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    state.error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              if (state.phase != AdminAuthPhase.codeSent &&
                  state.phase != AdminAuthPhase.verifying)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ink,
                  ),
                  onPressed: state.isBusy || state.selectedPhone == null
                      ? null
                      : controller.sendOtp,
                  child: state.phase == AdminAuthPhase.sendingCode
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send OTP'),
                ),
              if (state.phase == AdminAuthPhase.codeSent ||
                  state.phase == AdminAuthPhase.verifying) ...[
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(
                    labelText: '6-digit OTP',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ink,
                  ),
                  onPressed: state.isBusy
                      ? null
                      : () => controller.verifyOtp(_otpController.text.trim()),
                  child: state.phase == AdminAuthPhase.verifying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verify & Sign In'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: state.isBusy ? null : controller.resendOtp,
                  child: const Text('Resend OTP'),
                ),
              ],
              if (kDebugMode) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: state.isBusy
                      ? null
                      : () => controller.devAdminLogin(),
                  icon: const Icon(Icons.bug_report),
                  label: const Text('Skip Login (Dev Only)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.muted,
                    side: const BorderSide(color: AppColors.line),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Dropdown backed by the active admins list from Firestore.
class _AdminDropdown extends ConsumerWidget {
  final String? selected;
  final void Function(String name, String phone) onSelected;

  const _AdminDropdown({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminsAsync = ref.watch(activeAdminsProvider);

    return adminsAsync.when(
      data: (admins) {
        if (admins.isEmpty) {
          return const Text(
            'No authorized admins found.',
            textAlign: TextAlign.center,
          );
        }
        return DropdownButtonFormField<String>(
          key: selected == null ? null : ValueKey(selected),
          initialValue: selected,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Admin',
            border: OutlineInputBorder(),
          ),
          hint: const Text('Choose an admin'),
          items: admins.map((admin) {
            return DropdownMenuItem(
              value: admin.phoneNumber,
              child: Text(admin.name),
            );
          }).toList(),
          onChanged: (phone) {
            final selectedAdmin = admins.firstWhere(
              (a) => a.phoneNumber == phone,
            );
            onSelected(selectedAdmin.name, selectedAdmin.phoneNumber);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error loading admins: $e'),
    );
  }
}
