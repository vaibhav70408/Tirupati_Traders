import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth/auth_controller.dart';
import '../../application/auth/auth_state.dart';
import '../../theme/app_colors.dart';
import 'customer_home_screen.dart';
import 'customer_profile_completion_screen.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phoneNumber;

  const OtpScreen({super.key, required this.phoneNumber});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Navigate based on the post-OTP auth state.
    ref.listen(authControllerProvider, (previous, next) {
      if (next.signedIn && next.profileExists) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const CustomerHomeScreen()),
          (route) => route.isFirst,
        );
      } else if (next.signedIn && next.needsProfile) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerProfileCompletionScreen(
              phoneNumber: next.phoneNumber ?? widget.phoneNumber,
            ),
          ),
          (route) => route.isFirst,
        );
      } else if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.error!)));
      }
    });

    final auth = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        title: const Text('Verify Number'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Text.rich(
              TextSpan(
                text: 'Enter the 6-digit code sent to\n',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
                children: [
                  TextSpan(
                    text: widget.phoneNumber,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
              ),
              decoration: const InputDecoration(
                hintText: '● ● ● ● ● ●',
                counterText: '',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
              onPressed: auth.isBusy
                  ? null
                  : () => controller.verifyOtp(_code.text.trim()),
              child: auth.phase == AuthPhase.verifying
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Verify & Continue'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: auth.isBusy ? null : controller.resendOtp,
              child: const Text('Resend code'),
            ),
          ],
        ),
      ),
    );
  }
}
