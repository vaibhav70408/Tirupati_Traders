import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth/auth_controller.dart';
import '../../application/auth/auth_state.dart';
import '../../theme/app_colors.dart';
import '../role_selection_screen.dart';
import 'customer_home_screen.dart';
import 'customer_login_screen.dart';
import 'customer_signup_screen.dart';

class CustomerAuthGatewayScreen extends ConsumerWidget {
  const CustomerAuthGatewayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      authControllerProvider.select(
        (s) =>
            s.phase == AuthPhase.sendingCode || s.phase == AuthPhase.verifying,
      ),
    );
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFBECE0), Color(0xFFF6F3EE), Color(0xFFE9F3EA)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const RoleSelectionScreen(),
                          ),
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const Spacer(),
                Center(child: _logo()),
                const SizedBox(height: 20),
                const Text(
                  'Tirupati Traders',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your neighbourhood kirana, now online',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                const SizedBox(height: 40),
                _actionCard(
                  context,
                  icon: Icons.person_add_alt_1,
                  title: 'Create Account',
                  subtitle: 'Sign up with name, phone & address',
                  color: AppColors.saffron,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomerSignupScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _actionCard(
                  context,
                  icon: Icons.login,
                  title: 'Login',
                  subtitle: 'Already have an account?',
                  color: AppColors.green,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomerLoginScreen(),
                    ),
                  ),
                ),
                const Spacer(),
                if (kDebugMode) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: isLoading
                        ? null
                        : () async {
                            await ref
                                .read(authControllerProvider.notifier)
                                .devLogin();
                            if (context.mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => const CustomerHomeScreen(),
                                ),
                                (_) => false,
                              );
                            }
                          },
                    icon: const Icon(Icons.bug_report),
                    label: const Text('Skip Login (Dev Only)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.muted,
                      side: const BorderSide(color: AppColors.line),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _logo() {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.saffron, AppColors.saffronDark],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Text(
        'TT',
        style: TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _actionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
